"""Conservative MaixCAM2 half of the R1 arm command link."""

import json
import hmac
import math
import time

from arm_protocol import HOME_TARGET, gripper_servo, write_target

WATCHDOG_S = 1.0
JOINT_SPEED_DPS = 60.0


class ControlAuthority:
    """Single authenticated WebSocket lease; an unset token denies every claim."""

    def __init__(self, expected_token):
        self.expected_token = (
            expected_token if isinstance(expected_token, str) and len(expected_token) >= 32 else None
        )
        self.owner = None

    def claim(self, client, token):
        if (self.expected_token is None or not isinstance(token, str) or
                not hmac.compare_digest(token, self.expected_token)):
            return False
        if self.owner is None:
            self.owner = client
        return self.owner is client

    def owns(self, client):
        return self.owner is client

    def release(self, client):
        if self.owner is client:
            self.owner = None


class ArmCommandLink:
    def __init__(self, uart=None, motion_enabled=False, clock=None):
        self.uart = uart
        self.motion_enabled = motion_enabled
        self.clock = clock or time.monotonic
        self.last_message_at = self.clock()
        self.pose_known = False
        self.joints = None
        self.target = None
        self.busy_until = None
        self.active_seq = None
        self.stopped = True
        self.drive_locked = True
        self.in_bin = False
        self.stale = False

    @staticmethod
    def _valid_seq(data):
        seq = data.get("seq")
        return seq if isinstance(seq, int) and not isinstance(seq, bool) and seq >= 0 else None

    def receive(self, raw, authorized=False):
        try:
            data = json.loads(raw)
        except (TypeError, ValueError):
            return []
        if not isinstance(data, dict) or not isinstance(data.get("cmd"), str):
            return []
        cmd = data["cmd"]
        seq = self._valid_seq(data)
        if cmd == "HEARTBEAT":
            if authorized and data == {"cmd": "HEARTBEAT"}:
                self.last_message_at = self.clock()
                self.stale = False
            return []

        if not authorized:
            return [self._error(seq, "unauthorized")] if seq is not None else []
        if cmd in ("STATUS", "STOP", "LOCK_DRIVE", "UNLOCK_DRIVE", "HOLD", "HOME", "DROP"):
            if seq is None or set(data) != {"cmd", "seq"}:
                return [self._error(seq, "bad_args")] if seq is not None else []
        elif cmd == "MOVE_TO_BIN":
            if (seq is None or set(data) != {"cmd", "seq", "bin"} or
                    data.get("bin") not in ("organik", "anorganik", "b3")):
                return [self._error(seq, "bad_args")] if seq is not None else []
        elif cmd == "PICK":
            if (seq is None or set(data) != {"cmd", "seq", "dist_cm", "lateral_cm"} or
                    not self._valid_optional_number(data.get("dist_cm")) or
                    not self._valid_optional_number(data.get("lateral_cm"))):
                return [self._error(seq, "bad_args")] if seq is not None else []
        elif cmd == "servo":
            if (set(data) not in ({"cmd", "part", "val"}, {"cmd", "part", "val", "seq"}) or
                    ("seq" in data and seq is None)):
                return [self._error(seq, "bad_args")] if seq is not None else []
            return self._servo(data, seq)
        elif cmd == "motor":
            if set(data) != {"cmd", "left", "right"} or not self.motor_allowed(data.get("left"), data.get("right")):
                return []
            return []
        elif cmd in ("ping", "start_stream", "stop_stream", "disconnect"):
            if set(data) != {"cmd"}:
                return []
            return []
        else:
            return [self._error(seq, "unknown_cmd")] if seq is not None else []

        if seq is None:
            return []
        if cmd == "STATUS":
            return [{"event": "ack", "seq": seq,
                     "ee_mm": None,
                     "at_home": None}]
        if cmd == "STOP":
            self.stopped = True
            self.drive_locked = True
            if self.busy_until is not None:
                self.pose_known = False
                self.joints = None
                self.target = None
            self.busy_until = None
            self.active_seq = None
            return [{"event": "ack", "seq": seq, "effect": "logical_only"}]
        if cmd == "LOCK_DRIVE":
            self.drive_locked = True
            return [{"event": "ack", "seq": seq, "effect": "logical_only"}]
        if cmd == "UNLOCK_DRIVE":
            self.stopped = False
            self.drive_locked = False
            return [{"event": "ack", "seq": seq, "effect": "logical_only"}]
        if cmd == "HOLD":
            if not self.pose_known or self.target is None:
                return [self._error(seq, "pose_unknown")]
            if self.busy_until is not None:
                self.stopped = True
                self.drive_locked = True
                self.pose_known = False
                self.joints = None
                self.target = None
                self.busy_until = None
                self.active_seq = None
                return [self._error(seq, "mcu_hold_required")]
            self.stopped = True
            self.busy_until = None
            self.active_seq = None
            return [{"event": "ack", "seq": seq, "effect": "logical_only"}]
        if cmd in ("HOME", "PICK", "MOVE_TO_BIN", "DROP"):
            if self.stopped:
                return [self._error(seq, "stopped")]
            if self.busy_until is not None:
                return [self._error(seq, "busy")]
            if not self.pose_known:
                return [self._error(seq, "pose_unknown")]
            if not self.motion_enabled or self.uart is None:
                return [self._error(seq, "motion_disabled")]
            if cmd == "HOME" and self.in_bin:
                return [self._error(seq, "waypoint_required")]
            if cmd == "HOME":
                if self.target[0] != HOME_TARGET[0]:
                    return [self._error(seq, "gripper_timing_unknown")]
                target = HOME_TARGET
                new_joints = (0, 0, 0, 0, 0)
            else:
                return [self._error(seq, "not_implemented")]
            try:
                write_target(self.uart, target)
            except (TypeError, ValueError, AttributeError):
                return [self._error(seq, "bad_args")]
            travel_s = max(abs(a - b) for a, b in zip(self.joints, new_joints)) / JOINT_SPEED_DPS
            self.pose_known = True
            self.joints = new_joints
            self.target = target
            self.busy_until = self.clock() + travel_s
            self.active_seq = seq
            replies = [{"event": "ack", "seq": seq}]
            if travel_s == 0:
                replies.extend(self.poll())
            return replies
        return [self._error(seq, "unknown_cmd")]

    @staticmethod
    def _valid_optional_number(value):
        if value is None:
            return True
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return False
        try:
            return math.isfinite(value)
        except OverflowError:
            return False

    def _servo(self, data, seq):
        part, value = data.get("part"), data.get("val")
        bounds = (0, 100) if part == "gripper" else (0, 180)
        if (part not in ("reach", "height", "gripper", "base") or
                isinstance(value, bool) or not isinstance(value, int) or
                not bounds[0] <= value <= bounds[1]):
            return [self._error(seq, "bad_args")] if seq is not None else []
        reason = ("pose_unknown" if not self.pose_known else
                  "stopped" if self.stopped else
                  "busy" if self.busy_until is not None else None)
        if reason is not None:
            return [self._error(seq, reason)] if seq is not None else []
        if not self.motion_enabled or self.uart is None:
            return [self._error(seq, "motion_disabled")] if seq is not None else []
        if part not in ("gripper", "base"):
            return [self._error(seq, "not_implemented")] if seq is not None else []
        target = list(self.target)
        joints = list(self.joints)
        if part == "gripper":
            target[0] = gripper_servo(value)
        else:
            target[5] = value
            joints[0] = value - 90
        try:
            write_target(self.uart, target)
        except (TypeError, ValueError, AttributeError):
            return [self._error(seq, "bad_args")] if seq is not None else []
        self.target = tuple(target)
        self.joints = tuple(joints)
        return [{"event": "ack", "seq": seq}] if seq is not None else []

    def poll(self):
        now = self.clock()
        if now - self.last_message_at >= WATCHDOG_S and not self.stale:
            self.stale = True
            self.stopped = True
            self.drive_locked = True
            self.pose_known = False
            self.joints = None
            self.target = None
            self.busy_until = None
            self.active_seq = None
        if self.busy_until is not None and now >= self.busy_until:
            seq = self.active_seq
            self.busy_until = None
            self.active_seq = None
            return [{"event": "motion_done", "seq": seq}]
        return []

    def disconnected(self):
        self.stopped = True
        self.drive_locked = True
        self.pose_known = False
        self.joints = None
        self.target = None
        self.busy_until = None
        self.active_seq = None
        self.stale = True

    def motor_allowed(self, left, right):
        if any(isinstance(value, bool) or not isinstance(value, int) or not -255 <= value <= 255
               for value in (left, right)):
            return False
        return (left == 0 and right == 0) or (
            not self.stopped and not self.drive_locked and not self.stale
        )

    @staticmethod
    def _error(seq, reason):
        return {"event": "error", "seq": seq, "reason": reason}

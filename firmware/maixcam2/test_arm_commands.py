import json
import unittest

from arm_commands import ArmCommandLink, WATCHDOG_S
from arm_protocol import HOME_TARGET, joint_target


class Clock:
    def __init__(self):
        self.value = 0.0

    def __call__(self):
        return self.value


class MockUART:
    def __init__(self):
        self.lines = []

    def write_str(self, line):
        self.lines.append(line)


def seed_trusted_pose(link, joints, target):
    link.joints = joints
    link.target = target
    link.pose_known = True


def send(link, cmd, seq=1, **args):
    return link.receive(json.dumps({"cmd": cmd, "seq": seq, **args}))


class ArmCommandTest(unittest.TestCase):
    def test_status_and_home_are_unknown_after_boot(self):
        link = ArmCommandLink(clock=Clock())
        self.assertEqual(send(link, "STATUS"), [
            {"event": "ack", "seq": 1, "ee_mm": None, "at_home": None}])
        send(link, "UNLOCK_DRIVE")
        self.assertEqual(send(link, "HOME"), [
            {"event": "error", "seq": 1, "reason": "pose_unknown"}])

    def test_home_ack_busy_and_estimated_motion_done_use_mock_uart(self):
        clock, uart = Clock(), MockUART()
        link = ArmCommandLink(uart, motion_enabled=True, clock=clock)
        seed_trusted_pose(link, (30, 0, 0, 0, 0), joint_target((30, 0, 0, 0, 0)))
        send(link, "UNLOCK_DRIVE")
        self.assertEqual(send(link, "HOME"), [{"event": "ack", "seq": 1}])
        self.assertEqual(uart.lines, ["10,90,90,180,90,90\n"])
        self.assertEqual(send(link, "HOME"), [
            {"event": "error", "seq": 1, "reason": "busy"}])
        clock.value = 0.51
        self.assertEqual(link.poll(), [{"event": "motion_done", "seq": 1}])

    def test_busy_home_from_bin_requires_unimplemented_waypoint(self):
        link = ArmCommandLink(MockUART(), motion_enabled=True, clock=Clock())
        seed_trusted_pose(link, (0, 0, 0, 0, 0), HOME_TARGET)
        link.in_bin = True
        send(link, "UNLOCK_DRIVE")
        self.assertEqual(send(link, "HOME"), [
            {"event": "error", "seq": 1, "reason": "waypoint_required"}])

    def test_stop_hold_disconnect_and_watchdog_fail_closed(self):
        clock = Clock()
        link = ArmCommandLink(clock=clock)
        self.assertEqual(send(link, "HOLD"), [
            {"event": "error", "seq": 1, "reason": "pose_unknown"}])
        self.assertEqual(send(link, "STOP"), [{"event": "ack", "seq": 1}])
        self.assertEqual(send(link, "HOME"), [
            {"event": "error", "seq": 1, "reason": "stopped"}])
        clock.value = WATCHDOG_S
        link.poll()
        self.assertTrue(link.stale)
        self.assertFalse(link.pose_known)
        link.receive('{"cmd":"HEARTBEAT"}')
        self.assertFalse(link.stale)
        self.assertTrue(link.stopped)  # app must send deliberate UNLOCK_DRIVE
        self.assertFalse(link.motor_allowed(1, 1))
        self.assertTrue(link.motor_allowed(0, 0))
        link.disconnected()
        self.assertFalse(link.pose_known)

    def test_drive_lock_and_motor_bounds(self):
        link = ArmCommandLink(clock=Clock())
        self.assertFalse(link.motor_allowed(1, 1))
        self.assertTrue(link.motor_allowed(0, 0))
        self.assertEqual(send(link, "UNLOCK_DRIVE"), [{"event": "ack", "seq": 1}])
        self.assertTrue(link.motor_allowed(255, -255))
        self.assertFalse(link.motor_allowed(256, 0))
        self.assertFalse(link.motor_allowed(True, 0))
        self.assertEqual(send(link, "LOCK_DRIVE"), [{"event": "ack", "seq": 1}])
        self.assertFalse(link.motor_allowed(1, 1))

    def test_bad_partial_and_unknown_messages_do_not_move_or_reply(self):
        uart = MockUART()
        link = ArmCommandLink(uart, motion_enabled=True, clock=Clock())
        self.assertEqual(link.receive("{"), [])
        self.assertEqual(link.receive('[]'), [])
        self.assertEqual(link.receive('{"cmd":"HOME"}'), [])
        self.assertEqual(send(link, "UNKNOWN"), [
            {"event": "error", "seq": 1, "reason": "unknown_cmd"}])
        self.assertEqual(uart.lines, [])

    def test_slider_bounds_are_validated_before_any_motion(self):
        link = ArmCommandLink(MockUART(), motion_enabled=True, clock=Clock())
        seed_trusted_pose(link, (0, 0, 0, 0, 0), HOME_TARGET)
        send(link, "UNLOCK_DRIVE")
        for part, value in (("reach", 181), ("height", -1), ("gripper", 101), ("unknown", 40)):
            self.assertEqual(send(link, "servo", part=part, val=value), [
                {"event": "error", "seq": 1, "reason": "bad_args"}])

    def test_gripper_mapping_stays_separate_and_reach_requires_ik(self):
        uart = MockUART()
        link = ArmCommandLink(uart, motion_enabled=True, clock=Clock())
        seed_trusted_pose(link, (0, 0, 0, 0, 0), HOME_TARGET)
        send(link, "UNLOCK_DRIVE")
        self.assertEqual(link.receive('{"cmd":"servo","part":"gripper","val":100}'), [])
        self.assertEqual(uart.lines, ["90,90,90,180,90,90\n"])
        self.assertEqual(link.receive('{"cmd":"servo","part":"reach","val":100}'), [])
        self.assertEqual(len(uart.lines), 1)

    def test_hold_acknowledges_without_claiming_mcu_hold(self):
        uart = MockUART()
        link = ArmCommandLink(uart, motion_enabled=True, clock=Clock())
        seed_trusted_pose(link, (0, 0, 0, 0, 0), HOME_TARGET)
        self.assertEqual(send(link, "HOLD"), [
            {"event": "ack", "seq": 1}, {"event": "motion_done", "seq": 1}])
        self.assertEqual(uart.lines, [])

    def test_hold_during_estimated_motion_marks_pose_unknown(self):
        clock, uart = Clock(), MockUART()
        link = ArmCommandLink(uart, motion_enabled=True, clock=clock)
        seed_trusted_pose(link, (10, 0, 0, 0, 0), joint_target((10, 0, 0, 0, 0)))
        link.busy_until, link.active_seq = 1.0, 4
        self.assertEqual(send(link, "HOLD", seq=5), [
            {"event": "error", "seq": 5, "reason": "mcu_hold_required"}])
        self.assertFalse(link.pose_known)
        self.assertEqual(uart.lines, [])


if __name__ == "__main__":
    unittest.main()

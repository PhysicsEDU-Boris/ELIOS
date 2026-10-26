"""MaixCAM2-side target formatting for the decision 0027 arm UART link."""

import math

JOINT_LIMITS = ((-90, 90), (-50, 50), (-180, 0), (-25, 90), (-90, 90))
HOME_TARGET = (10, 90, 90, 180, 90, 90)


def _valid_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return False
    try:
        return math.isfinite(value)
    except OverflowError:
        return isinstance(value, int)


def gripper_servo(width):
    if not _valid_number(width):
        raise ValueError("gripper width must be numeric")
    if not 0 <= width <= 100:
        raise ValueError("gripper width must be in 0..100")
    return round(10 + 0.8 * width)


def joint_target(joints, gripper_width=0):
    """Map sim joints [J1..J5] to the MaixCAM2 UART fields [D2,D3,D4,D5,D6,D8]."""
    if not isinstance(joints, (list, tuple)) or len(joints) != 5:
        raise ValueError("expected five joint angles")
    clamped = []
    for value, (low, high) in zip(joints, JOINT_LIMITS):
        if not _valid_number(value):
            raise ValueError("joint angles must be numeric")
        clamped.append(min(high, max(low, value)))
    j1, j2, j3, j4, j5 = clamped
    return (gripper_servo(gripper_width), round(90 + j5), round(90 - j4),
            round(180 + j3), round(90 - j2), round(90 + j1))


def encode_target(target):
    if not isinstance(target, (list, tuple)) or len(target) != 6 or any(
        isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= 180
        for value in target
    ):
        raise ValueError("expected six integer servo targets in 0..180")
    return ",".join(str(value) for value in target) + "\n"


def write_target(uart, target):
    """Write exactly one validated, newline-terminated ASCII target line."""
    uart.write_str(encode_target(target))

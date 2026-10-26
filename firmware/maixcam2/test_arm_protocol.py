import math
import unittest

from arm_protocol import HOME_TARGET, encode_target, gripper_servo, joint_target, write_target


class MockUART:
    def __init__(self):
        self.lines = []

    def write_str(self, line):
        self.lines.append(line)


class ArmProtocolTest(unittest.TestCase):
    def test_home_and_uart_field_order(self):
        self.assertEqual(joint_target((0, 0, 0, 0, 0)), HOME_TARGET)
        self.assertEqual(encode_target(HOME_TARGET), "10,90,90,180,90,90\n")
        uart = MockUART()
        write_target(uart, HOME_TARGET)
        self.assertEqual(uart.lines, ["10,90,90,180,90,90\n"])

    def test_joint_mapping_clamps_to_decision_limits(self):
        self.assertEqual(joint_target((91, -51, 1, -26, -91)), (10, 0, 115, 180, 140, 180))
        self.assertEqual(joint_target((-91, 51, -181, 91, 91)), (10, 180, 0, 0, 40, 0))

    def test_gripper_conversion_is_separate(self):
        self.assertEqual([gripper_servo(v) for v in (0, 50, 100)], [10, 50, 90])
        self.assertEqual(joint_target((0, 0, 0, 0, 0), 100)[0], 90)

    def test_malformed_and_out_of_range_targets_reject(self):
        for target in (None, (10, 90, 90), (10, 90, 90, 180, 90, 181),
                       (10, 90, 90, 180, 90, 90.0), (10, 90, 90, 180, 90, True)):
            with self.subTest(target=target), self.assertRaises(ValueError):
                encode_target(target)
        for joints in (None, (0, 0, 0, 0), (0, 0, 0, 0, math.nan), (0, 0, 0, 0, math.inf)):
            with self.subTest(joints=joints), self.assertRaises(ValueError):
                joint_target(joints)
        for width in (-1, 101, math.nan, True):
            with self.subTest(width=width), self.assertRaises(ValueError):
                gripper_servo(width)


if __name__ == "__main__":
    unittest.main()

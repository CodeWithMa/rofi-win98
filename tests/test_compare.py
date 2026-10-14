"""Regression tests for the normalized RGB RMSE metric."""
import math
import unittest

from PIL import Image

from compare import rmse


class RmseTests(unittest.TestCase):
    def test_identical_images(self):
        image = Image.new("RGB", (10, 10), (12, 34, 56))
        self.assertEqual(rmse(image, image.copy()), 0.0)

    def test_full_black_to_white_difference(self):
        black = Image.new("RGB", (10, 10))
        white = Image.new("RGB", (10, 10), "white")
        self.assertEqual(rmse(black, white), 1.0)

    def test_localized_difference(self):
        black = Image.new("RGB", (100, 100))
        changed = black.copy()
        changed.paste("white", (0, 0, 1, 100))
        self.assertAlmostEqual(rmse(black, changed), 0.1)

    def test_single_channel_difference(self):
        black = Image.new("RGB", (10, 10))
        red = Image.new("RGB", (10, 10), "red")
        self.assertAlmostEqual(rmse(black, red), 1 / math.sqrt(3))


if __name__ == "__main__":
    unittest.main()

import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_inputs", Path(__file__).parents[1] / "scripts/update-inputs.py"
)
update_inputs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(update_inputs)


class StableBranchTests(unittest.TestCase):
    def test_uses_latest_official_download_link(self):
        page = """
        https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso
        https://channels.nixos.org/nixos-26.05/latest-nixos-graphical-aarch64-linux.iso
        https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso
        nixos-99.11 is not a download link
        """
        self.assertEqual(update_inputs.stable_branch(page), "nixos-26.05")

    def test_fails_if_the_page_format_changes(self):
        with self.assertRaises(ValueError):
            update_inputs.stable_branch("No release links")


if __name__ == "__main__":
    unittest.main()

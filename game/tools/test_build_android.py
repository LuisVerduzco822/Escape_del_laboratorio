"""Check the ADB preservation guard without running Godot or ADB."""

from pathlib import Path
import contextlib
import io
import tempfile
import unittest
from unittest.mock import patch

from build_android import keeps_adb_running, main


class AdbPreservationTest(unittest.TestCase):
    def test_unsafe_settings_never_launch_godot(self):
        with patch("sys.argv", ["build_android.py", "--godot", "unused"]), \
                patch("build_android.keeps_adb_running", return_value=False), \
                patch("build_android.subprocess.run") as run, \
                contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                main()
            self.assertEqual(error.exception.code, 2)
            run.assert_not_called()

    def test_exports_require_explicit_shutdown_opt_out(self):
        with tempfile.TemporaryDirectory() as directory:
            settings = Path(directory) / "editor_settings-4.7.tres"
            self.assertFalse(keeps_adb_running(settings))
            for content, expected in [
                ('[resource]\n', False),
                ('[resource]\nexport/android/shutdown_adb_on_exit = true\n', False),
                ('[resource]\nexport/android/shutdown_adb_on_exit = false\n', True),
                ('; export/android/shutdown_adb_on_exit = false\n', False),
                ('export/android/shutdown_adb_on_exit = false\nexport/android/shutdown_adb_on_exit = true\n', False),
            ]:
                with self.subTest(content=content):
                    settings.write_text(content, encoding="utf-8")
                    self.assertEqual(keeps_adb_running(settings), expected)


if __name__ == "__main__":
    unittest.main()

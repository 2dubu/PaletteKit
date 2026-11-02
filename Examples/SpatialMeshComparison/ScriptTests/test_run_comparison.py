"""Exercise the real export script with fake Xcode/simulator commands."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "run-comparison.sh"


class ExportIsolationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.calls = self.root / "calls"
        self.container = self.root / "container"
        (self.container / "Documents").mkdir(parents=True)
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        PROBE_CALLS=str(self.calls), PROBE_CONTAINER=str(self.container),
                        TMPDIR=str(self.root))
        fake = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ["PROBE_CALLS"], "a") as f:
    f.write(name + " " + " ".join(sys.argv[1:]) + "\\n")
if name != "xcrun":
    sys.exit(0)
command = sys.argv[2]
container = Path(os.environ["PROBE_CONTAINER"])
if command == "get_app_container":
    print(container)
elif command == "launch":
    out = container / "Documents" / "SpatialComparison"
    out.mkdir()
    rows = [{"case": "01-synthetic"}]
    (out / "01-synthetic-comparison.png").write_bytes(b"synthetic")
    if (container / "Documents" / "input.jpg").exists():
        rows.append({"case": "05-user-image"})
        (out / "05-user-image-comparison.png").write_bytes(b"private")
    (out / "metrics.json").write_text(json.dumps({"rows": rows}))
elif command == "io":
    Path(sys.argv[-1]).write_bytes(b"screenshot")
'''
        for name in ["xcodegen", "xcodebuild", "xcrun"]:
            path = self.bin / name
            path.write_text(fake)
            path.chmod(0o755)

    def run_export(self, destination, image=None):
        args = ["/bin/bash", str(SCRIPT), "test-device", str(destination)]
        if image is not None:
            args.append(str(image))
        return subprocess.run(args, env=self.env, capture_output=True, text=True)

    def test_reusing_output_preserves_old_export_and_stops_before_tools(self):
        destination = self.root / "previous run"
        destination.mkdir()
        private = destination / "05-user-image-comparison.png"
        private.write_bytes(b"previous private result")
        result = self.run_export(destination)
        self.assertEqual(result.returncode, 2)
        self.assertIn("must be a new directory", result.stderr)
        self.assertEqual(private.read_bytes(), b"previous private result")
        self.assertFalse(self.calls.exists())
        self.assertEqual(list(destination.iterdir()), [private])

    def test_even_empty_existing_directory_is_rejected(self):
        destination = self.root / "empty"
        destination.mkdir()
        self.assertEqual(self.run_export(destination).returncode, 2)
        self.assertFalse(self.calls.exists())

    def test_fresh_synthetic_export_excludes_previous_user_image(self):
        image = self.root / "local input.jpg"
        image.write_bytes(b"test-only input")
        private_run = self.root / "private run"
        first = self.run_export(private_run, image)
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertTrue((private_run / "05-user-image-comparison.png").exists())
        synthetic_run = self.root / "synthetic run"
        second = self.run_export(synthetic_run)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertFalse((synthetic_run / "05-user-image-comparison.png").exists())
        self.assertFalse((self.container / "Documents" / "input.jpg").exists())
        rows = json.loads((synthetic_run / "metrics.json").read_text())["rows"]
        self.assertEqual(rows, [{"case": "01-synthetic"}])
        self.assertTrue((synthetic_run / "01-synthetic-comparison.png").exists())
        self.assertTrue((synthetic_run / "simulator-screen.png").exists())
        self.assertTrue((private_run / "05-user-image-comparison.png").exists())


if __name__ == "__main__":
    unittest.main()

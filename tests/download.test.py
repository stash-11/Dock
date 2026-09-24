#!/usr/bin/env python3
"""Offline regression tests for the streaming download boundary."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'scripts/omarchy-dock-icon').read_text()
FUNCTION = SOURCE[SOURCE.index('bounded_download() {'):SOURCE.index('extract_image_url() {')]


class DownloadTests(unittest.TestCase):
    def run_download(self, size, limit='2M', mode='ok', deadline=3):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            fake = work / 'curl'
            fake.write_text('''#!/usr/bin/env python3
import os, subprocess, sys, time
from pathlib import Path
args = sys.argv[1:]
assert args[args.index('--proto') + 1] == '=https'
assert args[args.index('--proto-redir') + 1] == '=https'
assert '--connect-timeout' in args and '--max-time' in args
assert '-o' not in args
if os.environ['MODE'] == 'stall':
    time.sleep(30)
if os.environ['MODE'] == 'overflow':
    child = subprocess.Popen([sys.executable, '-c',
        'import time; from pathlib import Path; time.sleep(1); Path("' + os.environ['MARKER'] + '").touch()'])
remaining = int(os.environ['SIZE'])
while remaining:
    chunk = b'x' * min(65536, remaining)
    count = os.write(1, chunk)
    remaining -= count
if os.environ['MODE'] == 'overflow':
    time.sleep(30)
if os.environ['MODE'] == 'error':
    sys.exit(22)
''')
            fake.chmod(0o755)
            destination = work / 'body'
            marker = work / 'survived'
            env = dict(os.environ, SIZE=str(size), MODE=mode, MARKER=str(marker))
            result = subprocess.run(
                ['bash', '-c', FUNCTION + '\ncurl_cmd="$1"; bounded_download "$2" "$3" "$4" https://example.test/icon',
                 'test', str(fake), str(destination), limit, str(deadline)],
                env=env, capture_output=True, timeout=5)
            if mode == 'ok' and size <= int(limit[:-1]) * 1024 * 1024:
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(destination.stat().st_size, size)
            else:
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(destination.exists(), 'partial response survived')
            if mode == 'overflow':
                import time
                time.sleep(1.2)
                self.assertFalse(marker.exists(), 'producer descendant survived')

    def test_set_rejects_overflow_before_image_parsing_and_cleans_files(self):
        for cap, url in ((2, 'https://macosicons.com/icon/test'),
                         (10, 'https://example.test/icon.png')):
            with self.subTest(cap=cap), tempfile.TemporaryDirectory() as directory:
                work = Path(directory)
                fake = work / 'curl'
                fake.write_text('#!/usr/bin/env python3\nimport os\n'
                                f'os.write(1, b"x" * ({cap} * 1024 * 1024 + 1))\n')
                fake.chmod(0o755)
                identify = work / 'identify'
                identify.write_text('#!/bin/sh\ntouch "$MARKER"\nexit 1\n')
                identify.chmod(0o755)
                temporary = work / 'tmp'
                temporary.mkdir()
                marker = work / 'parsed'
                result = subprocess.run(
                    [str(ROOT / 'scripts/omarchy-dock-icon'), 'set', 'test', url],
                    env=dict(os.environ, HOME=str(work / 'home'), TMPDIR=str(temporary),
                             CURL_CMD=str(fake), MARKER=str(marker),
                             PATH=str(work) + os.pathsep + os.environ['PATH']),
                    capture_output=True, timeout=5)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(b'size limit', result.stderr)
                self.assertFalse(marker.exists())
                self.assertEqual(list(temporary.iterdir()), [])
                self.assertEqual(list((work / 'home/.config/omarchy/icons').iterdir()), [])

    def test_small_complete_response(self):
        self.run_download(123)

    def test_exact_limits(self):
        for cap in (2, 10):
            with self.subTest(cap=cap):
                self.run_download(cap * 1024 * 1024, f'{cap}M')

    def test_overflow_without_declared_size_kills_producer_group(self):
        for cap in (2, 10):
            with self.subTest(cap=cap):
                self.run_download(cap * 1024 * 1024 + 1, f'{cap}M', 'overflow')

    def test_failed_transfer_removes_partial_body(self):
        self.run_download(123, mode='error')

    def test_deadline_removes_partial_body(self):
        self.run_download(0, mode='stall', deadline=1)


if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env bash
set -euo pipefail
node --test tests/*.test.js
bash tests/helper.test.sh
python3 tests/download.test.py

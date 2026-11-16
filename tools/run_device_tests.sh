#!/usr/bin/env bash
# Runs the on-device tests of ABQARI MATH and judges them by their own
# results. If every test passed but the runner exits non-zero afterwards
# (the emulator dying during teardown), the job passes with a visible warning
# instead of hiding the results behind an infrastructure failure.
set -uo pipefail
cd "$(dirname "$0")/../apps/abqari_math"

mkdir -p build
adb logcat -c || true
adb logcat -v time > build/device-logcat.txt 2>&1 &
logcat_pid=$!
trap 'kill "$logcat_pid" 2>/dev/null || true' EXIT

log="$(mktemp)"
flutter test integration_test/full_engine_test.dart --reporter expanded 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

if grep -q "Some tests failed" "$log" || grep -qE "\[E\]" "$log"; then
  echo "::error::A device test failed."
  exit 1
fi
if grep -q "All tests passed!" "$log"; then
  if [ "$status" -ne 0 ]; then
    echo "::warning::All device tests passed, but the test runner exited with $status during teardown."
  fi
  exit 0
fi
echo "::error::The device tests did not report a result (exit $status)."
exit "${status:-1}"

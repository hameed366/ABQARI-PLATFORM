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
# Each test in its own app launch, so one cannot leave the next in a bad state.
status=0
for name in "the embedded Python engine answers on the device" \
            "the solver screen hands off to the full engine and says so"; do
  flutter test integration_test/full_engine_test.dart --plain-name "$name" \
    --reporter expanded 2>&1 | tee -a "$log"
  code=${PIPESTATUS[0]}
  [ "$code" -ne 0 ] && status=$code
done
passed=$(grep -c "All tests passed!" "$log" || true)

show_device_log() {
  kill "$logcat_pid" 2>/dev/null || true
  echo "::group::Device log (crashes, kills, Python, Flutter errors)"
  grep -E "FATAL|AndroidRuntime|F DEBUG|signal [0-9]|lowmemorykiller|ActivityManager.*(Kill|kill|died|Process)|[Pp]ython|serious|E/flutter|I/flutter|abqari" \
    build/device-logcat.txt | tail -250 || true
  echo "::endgroup::"
}

if grep -q "Some tests failed" "$log" || grep -qE "\[E\]" "$log"; then
  show_device_log
  echo "::error::A device test failed."
  exit 1
fi
if [ "$passed" -eq 2 ]; then
  if [ "$status" -ne 0 ]; then
    echo "::warning::All device tests passed, but the test runner exited with $status during teardown."
  fi
  exit 0
fi
show_device_log
echo "::error::The device tests did not report a result (exit $status)."
exit "${status:-1}"

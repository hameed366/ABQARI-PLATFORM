#!/usr/bin/env bash
# Runs one on-device test of ABQARI MATH, by name, and judges it by its own
# result. If the test passed but the runner exits non-zero afterwards (the
# emulator dying during teardown), it passes with a visible warning.
#
#   tools/run_device_tests.sh "<test name>"
set -uo pipefail
cd "$(dirname "$0")/../apps/abqari_math"
name="${1:?usage: run_device_tests.sh <test name>}"

log="$(mktemp)"
flutter test integration_test/full_engine_test.dart --plain-name "$name" \
  --reporter expanded 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

if grep -q "Some tests failed" "$log" || grep -qE "\[E\]" "$log"; then
  echo "::error::Device test failed: $name"
  exit 1
fi
if grep -q "All tests passed!" "$log"; then
  if [ "$status" -ne 0 ]; then
    echo "::warning::Device test passed, but the runner exited with $status during teardown: $name"
  fi
  exit 0
fi
echo "::error::Device test reported no result (exit $status): $name"
exit "${status:-1}"

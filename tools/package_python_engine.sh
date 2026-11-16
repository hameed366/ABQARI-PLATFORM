#!/usr/bin/env bash
# Stage the full mathematics engine (backend/math_solver) and package it with
# the Python runtime for ABQARI MATH, before `flutter build`.
#
#   tools/package_python_engine.sh Android|iOS
#
# The same SERIOUS_PYTHON_* variables must also be set for the flutter build
# step; CI sets them at job level. Needs network access to install SymPy.
set -euo pipefail

platform="${1:?usage: package_python_engine.sh Android|iOS}"
repo="$(cd "$(dirname "$0")/.." && pwd)"
app="$repo/apps/abqari_math"
stage="$app/build-python/src"

rm -rf "$app/build-python"
mkdir -p "$stage"
cp "$app/python/main.py" "$stage/"
cp -R "$repo/backend/math_solver/abqari_solver" "$stage/"
find "$stage" -name "__pycache__" -type d -prune -exec rm -rf {} +

export SERIOUS_PYTHON_VERSION="${SERIOUS_PYTHON_VERSION:-3.12}"
export SERIOUS_PYTHON_SITE_PACKAGES="${SERIOUS_PYTHON_SITE_PACKAGES:-$app/build-python/site-packages}"
export SERIOUS_PYTHON_APP="${SERIOUS_PYTHON_APP:-$app/build-python/app}"

cd "$app"
dart run serious_python:main package build-python/src -p "$platform" \
  -r -r -r python/requirements.txt
echo "Packaged the Python engine for $platform."
du -sh "$SERIOUS_PYTHON_SITE_PACKAGES" "$SERIOUS_PYTHON_APP" 2>/dev/null || true

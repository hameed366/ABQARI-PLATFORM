"""Make the engine importable and decide whether SymPy-dependent tests may be skipped.

Locally SymPy may be absent: tests that need it are skipped (and say so).
In CI, ABQARI_REQUIRE_SYMPY=1 turns a missing SymPy into a hard error, so a
green run always means the engine tests really ran.
"""
import os
import sys
from pathlib import Path

ENGINE_ROOT = Path(__file__).resolve().parents[2] / "backend" / "math_solver"
if str(ENGINE_ROOT) not in sys.path:
    sys.path.insert(0, str(ENGINE_ROOT))

try:
    import sympy  # noqa: F401
except ImportError as error:  # pragma: no cover - depends on the environment
    if os.environ.get("ABQARI_REQUIRE_SYMPY") == "1":
        raise RuntimeError("SymPy is required in this environment but is not installed") from error

"""Entry point of the full mathematics engine embedded in ABQARI MATH.

The `abqari_solver` package is copied here from backend/math_solver at build
time (see tools/package_python_engine.sh); it is not committed twice.
"""
from abqari_solver.server import main

main()

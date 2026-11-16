"""The server's catalog seed must match the apps' learning catalog."""
from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("seedgen", ROOT / "tools" / "generate_catalog_seed.py")
seedgen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(seedgen)


def test_seed_is_up_to_date():
    expected = seedgen.render(seedgen.parse_catalog(seedgen.CATALOG.read_text(encoding="utf-8")))
    assert seedgen.SEED.read_text(encoding="utf-8") == expected, (
        "run: python3 tools/generate_catalog_seed.py"
    )


def test_every_path_has_a_domain_and_skill_slugs_are_unique_per_path():
    paths = seedgen.parse_catalog(seedgen.CATALOG.read_text(encoding="utf-8"))
    assert len(paths) >= 3
    for path in paths:
        slugs = [s["slug"] for s in path["skills"]]
        assert slugs and len(slugs) == len(set(slugs)), path["slug"]
    # Uploads are matched by (path, skill) alone, so path slugs must be unique too.
    assert len({p["slug"] for p in paths}) == len(paths)

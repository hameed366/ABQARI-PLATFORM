"""Repository hygiene: project rules that can be checked statically."""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
APPS = ["abqari_edu", "abqari_math"]

SECRET_PATTERNS = {
    "private key block": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    "JWT (e.g. Supabase key)": re.compile(r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\."),
    "provider API key": re.compile(r"\b(sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{30,})"),
    "AWS access key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "Supabase secret key": re.compile(r"\bsb_secret_[A-Za-z0-9_-]{10,}"),
}
FORBIDDEN_SUFFIXES = {".ipa", ".apk", ".aab", ".keystore", ".jks", ".p12", ".mobileprovision"}

# Product decision 6: no country / ministry / curriculum / textbook structure in
# shipped code. Docs may state the decision; code and schema may not model it.
CURRICULUM_TERMS = re.compile(
    r"curricul|country|ministry|textbook|semester|منهج|مناهج|وزارة|دولة|الدول|كتاب مدرسي",
    re.IGNORECASE,
)
CODE_SUFFIXES = {".dart", ".sql", ".py", ".yaml", ".yml", ".json", ".arb"}
CODE_ROOTS = ["apps", "packages", "backend", "admin"]


def tracked_files() -> list[Path]:
    out = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=REPO_ROOT, capture_output=True, text=True,
    )
    if out.returncode != 0:
        pytest.skip("not a git checkout")
    return [REPO_ROOT / line for line in out.stdout.splitlines() if (REPO_ROOT / line).is_file()]


def _strip_comments(path: Path, text: str) -> str:
    if path.suffix == ".sql":
        return re.sub(r"--[^\n]*", "", text)
    if path.suffix == ".dart":
        return re.sub(r"//[^\n]*", "", text)
    if path.suffix in {".py", ".yaml", ".yml"}:
        return re.sub(r"#[^\n]*", "", text)
    return text


def test_no_secrets_committed():
    hits = []
    for path in tracked_files():
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for label, pattern in SECRET_PATTERNS.items():
            if pattern.search(text):
                hits.append(f"{path.relative_to(REPO_ROOT)}: {label}")
    assert hits == []


def test_no_env_files_or_build_artifacts_committed():
    bad = [
        str(p.relative_to(REPO_ROOT))
        for p in tracked_files()
        if p.suffix.lower() in FORBIDDEN_SUFFIXES
        or (p.name.startswith(".env") and p.name != ".env.example")
    ]
    assert bad == []


def test_env_example_has_no_values():
    for line in (REPO_ROOT / ".env.example").read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            key, _, value = line.partition("=")
            assert value.strip() == "", f"{key} must be empty in .env.example"


def test_code_does_not_model_countries_or_curricula():
    hits = []
    for path in tracked_files():
        rel = path.relative_to(REPO_ROOT)
        if rel.parts[0] not in CODE_ROOTS or path.suffix not in CODE_SUFFIXES:
            continue
        text = _strip_comments(path, path.read_text(encoding="utf-8"))
        for match in CURRICULUM_TERMS.finditer(text):
            hits.append(f"{rel}: {match.group(0)!r}")
    assert hits == []


@pytest.mark.parametrize("app", APPS)
def test_app_has_manifest_and_entrypoint(app):
    root = REPO_ROOT / "apps" / app
    assert (root / "pubspec.yaml").is_file()
    assert (root / "lib" / "main.dart").is_file()
    assert re.search(rf"^name:\s*{app}\s*$", (root / "pubspec.yaml").read_text(), re.M)


def test_apps_do_not_depend_on_each_other():
    """Each app must build and ship on its own."""
    for app in APPS:
        other = next(a for a in APPS if a != app)
        for path in (REPO_ROOT / "apps" / app).rglob("*"):
            if path.is_file() and path.suffix in {".dart", ".yaml"}:
                assert other not in path.read_text(encoding="utf-8"), (
                    f"{path.relative_to(REPO_ROOT)} references {other}"
                )


@pytest.mark.parametrize("app", APPS)
def test_flutter_client_does_not_reference_privileged_credentials(app):
    for path in (REPO_ROOT / "apps" / app).rglob("*.dart"):
        text = path.read_text(encoding="utf-8").lower()
        for needle in ("service_role", "servicerole", "sb_secret_", "api_key =", "apikey ="):
            assert needle not in text, f"{path.relative_to(REPO_ROOT)} mentions {needle!r}"


@pytest.mark.parametrize(
    "doc",
    ["README.md", "docs/ARCHITECTURE.md", "docs/ROADMAP.md", "docs/DECISIONS.md",
     "docs/PHASE1_AUDIT.md", "backend/README.md"],
)
def test_required_docs_present(doc):
    assert (REPO_ROOT / doc).is_file()


# ── phase 2: each app is independently buildable ────────────────────────────

@pytest.mark.parametrize("app", APPS)
@pytest.mark.parametrize(
    "path",
    ["pubspec.lock", "test/widget_test.dart", "android/app/build.gradle.kts",
     "ios/Runner.xcodeproj/project.pbxproj"],
)
def test_app_has_everything_needed_to_build_alone(app, path):
    assert (REPO_ROOT / "apps" / app / path).is_file()


def _android_id(app: str) -> str:
    gradle = (REPO_ROOT / "apps" / app / "android/app/build.gradle.kts").read_text()
    return re.search(r'applicationId\s*=\s*"([^"]+)"', gradle).group(1)


def _ios_id(app: str) -> str:
    pbx = (REPO_ROOT / "apps" / app / "ios/Runner.xcodeproj/project.pbxproj").read_text()
    ids = set(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", pbx))
    return next(i for i in ids if not i.endswith("RunnerTests"))


def test_apps_have_distinct_store_identifiers():
    assert len({_android_id(a) for a in APPS}) == len(APPS)
    assert len({_ios_id(a) for a in APPS}) == len(APPS)


def test_ci_builds_every_app():
    ci = (REPO_ROOT / ".github/workflows/ci.yml").read_text()
    assert ci.count("app: [abqari_edu, abqari_math]") == 2  # android + ios matrices
    for command in ("flutter analyze", "flutter test", "flutter build apk", "flutter build ios"):
        assert command in ci

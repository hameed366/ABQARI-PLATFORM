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
    packages = sorted(p.name for p in (REPO_ROOT / "packages").iterdir() if p.is_dir())
    assert f"package: [{', '.join(packages)}]" in ci, "every shared package must be tested in CI"
    for command in ("dart format", "flutter analyze", "flutter test", "flutter build apk",
                    "flutter build ios"):
        assert command in ci


# ── phase 3: two languages, two directions ──────────────────────────────────

ARABIC = re.compile(r"[؀-ۿ]")


@pytest.mark.parametrize("app", APPS)
def test_app_uses_the_shared_localization_package(app):
    pubspec = (REPO_ROOT / "apps" / app / "pubspec.yaml").read_text()
    assert "abqari_localization:" in pubspec
    assert "path: ../../packages/localization" in pubspec


@pytest.mark.parametrize("app", APPS)
def test_user_visible_text_lives_only_in_l10n(app):
    """No Arabic literals in UI code: every string goes through lib/l10n/."""
    lib = REPO_ROOT / "apps" / app / "lib"
    offenders = [
        str(p.relative_to(REPO_ROOT))
        for p in lib.rglob("*.dart")
        if "l10n" not in p.relative_to(lib).parts
        and ARABIC.search(_strip_comments(p, p.read_text(encoding="utf-8")))
    ]
    assert offenders == []


@pytest.mark.parametrize("app", APPS)
def test_direction_is_never_hard_coded(app):
    """Direction must follow the locale; no forced RTL/LTR and no one-sided arrows."""
    for path in (REPO_ROOT / "apps" / app / "lib").rglob("*.dart"):
        text = _strip_comments(path, path.read_text(encoding="utf-8"))
        for needle in ("TextDirection.rtl", "TextDirection.ltr", "chevron_left", "chevron_right",
                       "arrow_back_ios", "arrow_forward_ios"):
            assert needle not in text, f"{path.relative_to(REPO_ROOT)} uses {needle}"


def test_shared_packages_know_nothing_about_either_app():
    for path in (REPO_ROOT / "packages").rglob("*"):
        if path.is_file() and path.suffix in {".dart", ".yaml"}:
            text = path.read_text(encoding="utf-8")
            for app in APPS:
                assert app not in text, f"{path.relative_to(REPO_ROOT)} references {app}"


# ── phase 4: one visual identity ────────────────────────────────────────────

@pytest.mark.parametrize("app", APPS)
def test_app_takes_its_look_from_the_shared_ui_package(app):
    pubspec = (REPO_ROOT / "apps" / app / "pubspec.yaml").read_text()
    assert "path: ../../packages/shared_ui" in pubspec
    for path in (REPO_ROOT / "apps" / app / "lib").rglob("*.dart"):
        text = _strip_comments(path, path.read_text(encoding="utf-8"))
        for needle in ("Color(0x", "Colors.", "ColorScheme.fromSeed", "ThemeData("):
            assert needle not in text, (
                f"{path.relative_to(REPO_ROOT)} defines its own look ({needle}); use abqari_ui"
            )


def test_ui_package_carries_no_user_visible_text():
    """abqari_ui stays language-neutral: apps pass every visible string in."""
    for path in (REPO_ROOT / "packages" / "shared_ui" / "lib").rglob("*.dart"):
        assert not ARABIC.search(path.read_text(encoding="utf-8")), path.name
    pubspec = (REPO_ROOT / "packages" / "shared_ui" / "pubspec.yaml").read_text()
    assert "abqari_localization" not in pubspec


# ── phase 5: user text is never executed ────────────────────────────────────

def test_math_engine_never_evaluates_user_text():
    """The engine must parse input itself: no eval/exec/sympify/parse_expr anywhere in it."""
    engine = REPO_ROOT / "backend" / "math_solver" / "abqari_solver"
    forbidden = re.compile(r"(?<![.\w])(eval|exec|sympify|parse_expr|compile|__import__)\s*\(")
    for path in engine.rglob("*.py"):
        text = _strip_comments(path, path.read_text(encoding="utf-8"))
        match = forbidden.search(text) or re.search(r"sp\.(sympify|parse_expr)\s*\(", text)
        assert match is None, f"{path.name} calls {match.group(1)}()"


def test_ci_requires_sympy_for_the_engine_tests():
    for workflow in ("ci.yml", "math-engine.yml"):
        text = (REPO_ROOT / ".github/workflows" / workflow).read_text()
        assert 'ABQARI_REQUIRE_SYMPY: "1"' in text, workflow
        assert "backend/math_solver/requirements.txt" in text, workflow


def test_no_invisible_direction_characters_in_source():
    """Bidi control characters can make code read differently from how it runs
    ("Trojan Source"). Source must spell them as escapes."""
    hidden = re.compile("[\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff]")
    offenders = []
    for path in tracked_files():
        if path.suffix not in {".dart", ".py", ".sql", ".yaml", ".yml", ".json", ".md"}:
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if hidden.search(line):
                offenders.append(f"{path.relative_to(REPO_ROOT)}:{number}")
    assert offenders == []


# ── phase 7: learning content ───────────────────────────────────────────────

def test_edu_takes_its_content_from_the_learning_package():
    pubspec = (REPO_ROOT / "apps" / "abqari_edu" / "pubspec.yaml").read_text()
    assert "path: ../../packages/learning_core" in pubspec

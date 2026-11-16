"""Turn what a person typed into one canonical ASCII form.

Pure Python, no third-party imports. Nothing here evaluates anything: the
output is only ever read by the hand-written parser in parser.py.

Handles: Arabic-Indic and Persian digits, Arabic variable letters (س ص ع ن),
Arabic function names (جا جتا ظا لو لط جذر), typographic operators (× ÷ − √ ² π …),
invisible direction marks, and a leading instruction word in Arabic or English
("حل", "بسّط", "solve", "derivative of" …).
"""
from __future__ import annotations

import re
from dataclasses import dataclass

from .errors import MathInputError

MAX_LENGTH = 500

TASKS = ("evaluate", "simplify", "expand", "factor", "solve", "differentiate", "integrate")

# Instruction words. Longest alternatives first within each task.
_COMMANDS: dict[str, tuple[str, ...]] = {
    "solve": ("حل المعادلة", "أوجد حل", "اوجد حل", "حل", "solve for", "solve"),
    "simplify": ("بسط", "اختصر", "simplify"),
    "expand": ("فك الأقواس", "فك الاقواس", "انشر", "فك", "expand"),
    "factor": ("حلل إلى عوامل", "حلل الى عوامل", "حلل", "factorise", "factorize", "factor"),
    "differentiate": (
        "أوجد مشتقة", "اوجد مشتقة", "مشتقة", "اشتق",
        "derivative of", "differentiate", "derivative",
    ),
    "integrate": (
        "أوجد تكامل", "اوجد تكامل", "تكامل", "كامل",
        "integral of", "integrate", "integral",
    ),
    "evaluate": ("احسب", "أوجد قيمة", "اوجد قيمة", "calculate", "evaluate", "compute"),
}

_TASHKEEL = re.compile(r"[ً-ْٰـ]")  # harakat, dagger alif, tatweel
_INVISIBLE = re.compile(r"[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]")

_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")

_SYMBOLS = {
    "×": "*", "·": "*", "∙": "*", "⋅": "*", "✕": "*",
    "÷": "/", "∕": "/",
    "−": "-", "–": "-", "—": "-", "﹣": "-", "－": "-",
    "＋": "+", "＝": "=",
    "٫": ".",
    "≤": "<=", "≥": ">=", "≠": "!=",
    "π": "pi",
    "（": "(", "）": ")", "[": "(", "]": ")", "{": "(", "}": ")",
    " ": " ", "\t": " ", "\n": " ", "\r": " ",
}

_SUPERSCRIPTS = str.maketrans("⁰¹²³⁴⁵⁶⁷⁸⁹", "0123456789")
_SUPERSCRIPT_RUN = re.compile(r"[⁰¹²³⁴⁵⁶⁷⁸⁹]+")

# Arabic names → canonical names. Longest first so جتا is not read as جا + ا.
_ARABIC_FUNCTIONS = (("جتا", "cos"), ("جذر", "sqrt"), ("جا", "sin"), ("ظا", "tan"),
                     ("لط", "ln"), ("لو", "log"))
_ARABIC_VARIABLES = {"س": "x", "ص": "y", "ع": "z", "ن": "n"}

_ARABIC_LETTER = re.compile(r"[؀-ۿ]")
_ALLOWED = re.compile(r"[0-9a-z+\-*/^().=<>! ]")
_SQRT_ATOM = re.compile(r"√\s*(\d+(?:\.\d+)?|[a-zA-Z؀-ۿ])")


@dataclass(frozen=True)
class Normalized:
    """`text` is canonical ASCII; `task` is the instruction word found, if any."""

    text: str
    task: str | None


def _extract_command(text: str) -> tuple[str | None, str]:
    lowered = text.lower()
    best: tuple[int, str] | None = None
    for task, words in _COMMANDS.items():
        for word in words:
            if lowered.startswith(word) and (best is None or len(word) > best[0]):
                rest = lowered[len(word):]
                # must end at a word boundary: "حل: …", "solve 2x=4", not "solver"
                if rest == "" or not (rest[0].isalpha() or _ARABIC_LETTER.match(rest[0])):
                    best = (len(word), task)
    if best is None:
        return None, text
    remainder = text[best[0]:].lstrip()
    if remainder.startswith(":"):
        remainder = remainder[1:]
    return best[1], remainder.strip()


def normalize(raw: str) -> Normalized:
    if not isinstance(raw, str):
        raise MathInputError("not_text")
    if len(raw) > MAX_LENGTH:
        raise MathInputError("too_long", detail=str(len(raw)))

    text = _INVISIBLE.sub("", raw)
    text = _TASHKEEL.sub("", text).strip()
    task, text = _extract_command(text)
    if not text:
        raise MathInputError("empty")

    text = text.translate(_DIGITS)
    text = _SUPERSCRIPT_RUN.sub(lambda m: "^(" + m.group(0).translate(_SUPERSCRIPTS) + ")", text)
    text = _SQRT_ATOM.sub(lambda m: f"sqrt({m.group(1)})", text)
    text = text.replace("√", "sqrt")
    for symbol, replacement in _SYMBOLS.items():
        text = text.replace(symbol, replacement)
    for arabic, latin in _ARABIC_FUNCTIONS:
        text = text.replace(arabic, latin)
    for arabic, latin in _ARABIC_VARIABLES.items():
        text = text.replace(arabic, latin)
    text = text.lower()
    text = re.sub(r" +", " ", text).strip()

    for position, char in enumerate(text):
        if not _ALLOWED.fullmatch(char):
            if char == ",":
                raise MathInputError("comma_not_supported", position=position)
            if _ARABIC_LETTER.match(char):
                raise MathInputError("unknown_word", position=position, detail=char)
            raise MathInputError("unknown_symbol", position=position, detail=char)
    if not text:
        raise MathInputError("empty")
    return Normalized(text=text, task=task)

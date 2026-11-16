import 'errors.dart';

/// Canonical ASCII form of what a person typed, plus the instruction word
/// ("حل", "solve", …) if one led the text.
class Normalized {
  const Normalized(this.text, this.task);
  final String text;
  final String? task;
}

const int maxInputLength = 500;

const List<String> knownTasks = [
  'evaluate',
  'simplify',
  'expand',
  'factor',
  'solve',
  'differentiate',
  'integrate',
];

const Map<String, List<String>> _commands = {
  'solve': ['حل المعادلة', 'أوجد حل', 'اوجد حل', 'حل', 'solve for', 'solve'],
  'simplify': ['بسط', 'اختصر', 'simplify'],
  'expand': ['فك الأقواس', 'فك الاقواس', 'انشر', 'فك', 'expand'],
  'factor': [
    'حلل إلى عوامل',
    'حلل الى عوامل',
    'حلل',
    'factorise',
    'factorize',
    'factor',
  ],
  'differentiate': [
    'أوجد مشتقة',
    'اوجد مشتقة',
    'مشتقة',
    'اشتق',
    'derivative of',
    'differentiate',
    'derivative',
  ],
  'integrate': [
    'أوجد تكامل',
    'اوجد تكامل',
    'تكامل',
    'كامل',
    'integral of',
    'integrate',
    'integral',
  ],
  'evaluate': [
    'احسب',
    'أوجد قيمة',
    'اوجد قيمة',
    'calculate',
    'evaluate',
    'compute',
  ],
};

final RegExp _tashkeel = RegExp('[ً-ْٰـ]');
final RegExp _invisible = RegExp('[​-‏‪-‮⁦-⁩﻿]');
final RegExp _letter = RegExp('[a-z؀-ۿ]');
final RegExp _arabicLetter = RegExp('[؀-ۿ]');
final RegExp _allowed = RegExp(r'^[0-9a-z+\-*/^().=<>! ]$');
final RegExp _superscriptRun = RegExp('[⁰¹²³⁴⁵⁶⁷⁸⁹]+');
final RegExp _sqrtAtom = RegExp('√\\s*(\\d+(?:\\.\\d+)?|[a-zA-Z؀-ۿ])');
final RegExp _spaces = RegExp(' +');

const String _superscripts = '⁰¹²³⁴⁵⁶⁷⁸⁹';

const Map<String, String> _symbols = {
  '×': '*',
  '·': '*',
  '∙': '*',
  '⋅': '*',
  '✕': '*',
  '÷': '/',
  '∕': '/',
  '−': '-',
  '–': '-',
  '—': '-',
  '﹣': '-',
  '－': '-',
  '＋': '+',
  '＝': '=',
  '٫': '.',
  '≤': '<=',
  '≥': '>=',
  '≠': '!=',
  'π': 'pi',
  '（': '(',
  '）': ')',
  '[': '(',
  ']': ')',
  '{': '(',
  '}': ')',
  ' ': ' ',
  '\t': ' ',
  '\n': ' ',
  '\r': ' ',
};

// Longest first so جتا is not read as جا + ا.
const List<(String, String)> _arabicFunctions = [
  ('جتا', 'cos'),
  ('جذر', 'sqrt'),
  ('جا', 'sin'),
  ('ظا', 'tan'),
  ('لط', 'ln'),
  ('لو', 'log'),
];

const Map<String, String> _arabicVariables = {
  'س': 'x',
  'ص': 'y',
  'ع': 'z',
  'ن': 'n',
};

String _westernDigits(String text) {
  final buffer = StringBuffer();
  for (final unit in text.codeUnits) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      buffer.writeCharCode(0x30 + unit - 0x0660);
    } else if (unit >= 0x06F0 && unit <= 0x06F9) {
      buffer.writeCharCode(0x30 + unit - 0x06F0);
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

(String?, String) _extractCommand(String text) {
  final lowered = text.toLowerCase();
  var bestLength = 0;
  String? bestTask;
  for (final entry in _commands.entries) {
    for (final word in entry.value) {
      if (word.length <= bestLength || !lowered.startsWith(word)) continue;
      final rest = lowered.substring(word.length);
      // must end at a word boundary: "solve 2x=4", not "solver"
      if (rest.isEmpty || !_letter.hasMatch(rest[0])) {
        bestLength = word.length;
        bestTask = entry.key;
      }
    }
  }
  if (bestTask == null) return (null, text);
  var remainder = text.substring(bestLength).trimLeft();
  if (remainder.startsWith(':')) remainder = remainder.substring(1);
  return (bestTask, remainder.trim());
}

/// Turns typed text into the one canonical form the parser reads.
///
/// Understands Arabic-Indic and Persian digits, the Arabic variable letters
/// س ص ع ن, the Arabic function names جا جتا ظا لو لط جذر, typographic
/// operators (× ÷ − √ ² π …) and invisible direction marks.
Normalized normalize(String raw) {
  if (raw.length > maxInputLength) {
    throw MathInputError('too_long', detail: '${raw.length}');
  }
  var text = raw.replaceAll(_invisible, '').replaceAll(_tashkeel, '').trim();
  final (task, remainder) = _extractCommand(text);
  text = remainder;
  if (text.isEmpty) throw const MathInputError('empty');

  text = _westernDigits(text);
  text = text.replaceAllMapped(_superscriptRun, (match) {
    final digits = match[0]!
        .split('')
        .map((char) => _superscripts.indexOf(char).toString())
        .join();
    return '^($digits)';
  });
  text = text.replaceAllMapped(_sqrtAtom, (match) => 'sqrt(${match[1]})');
  text = text.replaceAll('√', 'sqrt');
  _symbols.forEach((symbol, replacement) {
    text = text.replaceAll(symbol, replacement);
  });
  for (final (arabic, latin) in _arabicFunctions) {
    text = text.replaceAll(arabic, latin);
  }
  _arabicVariables.forEach((arabic, latin) {
    text = text.replaceAll(arabic, latin);
  });
  text = text.toLowerCase().replaceAll(_spaces, ' ').trim();

  for (var position = 0; position < text.length; position++) {
    final char = text[position];
    if (_allowed.hasMatch(char)) continue;
    if (char == ',') {
      throw MathInputError('comma_not_supported', position: position);
    }
    if (_arabicLetter.hasMatch(char)) {
      throw MathInputError('unknown_word', position: position, detail: char);
    }
    throw MathInputError('unknown_symbol', position: position, detail: char);
  }
  if (text.isEmpty) throw const MathInputError('empty');
  return Normalized(text, task);
}

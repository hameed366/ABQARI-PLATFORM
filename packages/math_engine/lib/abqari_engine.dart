/// On-device mathematics core for the ABQARI apps.
///
///     final result = solve('٢س + ٣ = ٧');
///
/// Pure Dart: no network, no plugins. Problems beyond its reach come back as
/// unsupported with the code [needsFullEngine], never as a guess.
library;

export 'src/engine.dart';
export 'src/errors.dart';
export 'src/exact.dart'
    show
        Surd,
        checkRealDomain,
        checkSize,
        constantSurd,
        exactRational,
        exactSurd;
export 'src/messages.dart';
export 'src/nodes.dart';
export 'src/normalize.dart' show Normalized, knownTasks, normalize;
export 'src/numeric.dart' show closeDoubles, numericDouble;
export 'src/parser.dart' show parse;
export 'src/polynomial.dart';
export 'src/rational.dart';
export 'src/verification.dart';

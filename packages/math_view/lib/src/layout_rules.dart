import 'package:abqari_engine/abqari_engine.dart';

/// Shared grouping rules, so the drawn form and the plain-text form always
/// agree on where parentheses go.
int precedence(Node node) => switch (node) {
      Add() || Sub() || PlusMinus() => 1,
      Mul() => 2,
      Neg() => 3,
      Pow() => 4,
      _ => 5,
    };

bool startsWithDigit(Node node) => switch (node) {
      Num() => true,
      Pow(:final left) || Mul(:final left) || Add(:final left) || Sub(:final left) =>
        startsWithDigit(left),
      _ => false,
    };

/// Right operand of + or − needs parentheses.
bool wrapAddRight(Node parent, Node right) =>
    right is Neg || (parent is Sub && precedence(right) == 1);

/// Operand of a product needs parentheses.
bool wrapMulOperand(Node operand) => precedence(operand) <= 1 || operand is Neg;

/// A product is written with an explicit × between its operands.
bool explicitTimes(Node right) => startsWithDigit(right);

/// Base of a power needs parentheses.
bool wrapPowerBase(Node base) =>
    !(base is Num || base is Var || base is Constant || base is Sym);

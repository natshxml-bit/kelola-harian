import 'package:flutter/material.dart';

const kSeed = Color(0xFF57758A);
const kAccent = Color(0xFFCC5C64);

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color card;
  final Color fill;
  final Color text;
  final Color textMuted;
  final Color income;
  final Color expense;
  final Color line;

  const AppColors({
    required this.bg,
    required this.card,
    required this.fill,
    required this.text,
    required this.textMuted,
    required this.income,
    required this.expense,
    required this.line,
  });

  static const light = AppColors(
    bg: Color(0xFFF3F5F6),
    card: Colors.white,
    fill: Colors.white,
    text: Color(0xFF2E3340),
    textMuted: Color(0xFF7A828E),
    income: Color(0xFF2E9E5B),
    expense: kAccent,
    line: Color(0xFFE3E7EA),
  );

  static const dark = AppColors(
    bg: Color(0xFF101418),
    card: Color(0xFF1B2128),
    fill: Color(0xFF232B34),
    text: Color(0xFFEDF0F4),
    textMuted: Color(0xFF9AA4B0),
    income: Color(0xFF5EDB8F),
    expense: Color(0xFFE0757D),
    line: Color(0xFF313A44),
  );

  AppColors copyWith({
    Color? bg,
    Color? card,
    Color? fill,
    Color? text,
    Color? textMuted,
    Color? income,
    Color? expense,
    Color? line,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      fill: fill ?? this.fill,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      line: line ?? this.line,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}

extension AppColorsCtx on BuildContext {
  AppColors get ap => Theme.of(this).extension<AppColors>()!;
  ColorScheme get cs => Theme.of(this).colorScheme;
}
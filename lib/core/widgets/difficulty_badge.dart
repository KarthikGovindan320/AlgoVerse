import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum Difficulty { easy, medium, hard }

class DifficultyBadge extends StatelessWidget {
  final Difficulty difficulty;
  final bool compact;

  const DifficultyBadge({
    super.key,
    required this.difficulty,
    this.compact = false,
  });

  factory DifficultyBadge.fromString(String value, {bool compact = false}) {
    final d = switch (value.toLowerCase()) {
      'easy' => Difficulty.easy,
      'medium' => Difficulty.medium,
      'hard' => Difficulty.hard,
      _ => Difficulty.medium,
    };
    return DifficultyBadge(difficulty: d, compact: compact);
  }

  Color get _color => switch (difficulty) {
        Difficulty.easy => AppColors.easy,
        Difficulty.medium => AppColors.medium,
        Difficulty.hard => AppColors.hard,
      };

  String get _label => switch (difficulty) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
      };

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        _label,
        style: AppTextStyles.label.copyWith(color: _color),
      ),
    );
  }
}

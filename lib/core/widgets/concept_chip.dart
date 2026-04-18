import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum ConceptChipState { unselected, selected, learnt, locked }

class ConceptChip extends StatelessWidget {
  final String label;
  final ConceptChipState state;
  final VoidCallback? onTap;
  final VoidCallback? onLearnTap;

  const ConceptChip({
    super.key,
    required this.label,
    this.state = ConceptChipState.unselected,
    this.onTap,
    this.onLearnTap,
  });

  Color get _bgColor => switch (state) {
        ConceptChipState.unselected => AppColors.surfaceRaised,
        ConceptChipState.selected => AppColors.primaryMuted,
        ConceptChipState.learnt => AppColors.primaryMuted,
        ConceptChipState.locked => AppColors.surface,
      };

  Color get _borderColor => switch (state) {
        ConceptChipState.unselected => AppColors.border,
        ConceptChipState.selected => AppColors.primary,
        ConceptChipState.learnt => AppColors.primary,
        ConceptChipState.locked => AppColors.borderSubtle,
      };

  Color get _textColor => switch (state) {
        ConceptChipState.unselected => AppColors.textSecondary,
        ConceptChipState.selected => AppColors.primary,
        ConceptChipState.learnt => AppColors.primary,
        ConceptChipState.locked => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state == ConceptChipState.locked)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.lock_outline, size: 12, color: AppColors.textMuted),
              ),
            if (state == ConceptChipState.selected || state == ConceptChipState.learnt)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check, size: 12, color: AppColors.primary),
              ),
            Text(
              label,
              style: AppTextStyles.label.copyWith(color: _textColor),
            ),
            if (state == ConceptChipState.learnt && onLearnTap != null)
              GestureDetector(
                onTap: onLearnTap,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.add_circle_outline, size: 14, color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

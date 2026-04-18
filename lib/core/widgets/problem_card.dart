import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'difficulty_badge.dart';
import 'concept_chip.dart';

class ProblemCard extends StatelessWidget {
  final int problemId;
  final String title;
  final String difficulty;
  final List<String> tags;
  final bool isSolved;
  final bool isBookmarked;
  final VoidCallback? onTap;
  final VoidCallback? onBookmarkTap;

  const ProblemCard({
    super.key,
    required this.problemId,
    required this.title,
    required this.difficulty,
    required this.tags,
    this.isSolved = false,
    this.isBookmarked = false,
    this.onTap,
    this.onBookmarkTap,
  });

  Color get _difficultyColor => switch (difficulty.toLowerCase()) {
        'easy' => AppColors.easy,
        'medium' => AppColors.medium,
        'hard' => AppColors.hard,
        _ => AppColors.medium,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left difficulty bar
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: _difficultyColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTextStyles.cardTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSolved)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: onBookmarkTap,
                            child: Icon(
                              isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                              color: isBookmarked ? AppColors.primary : AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          DifficultyBadge.fromString(difficulty),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: tags
                                    .take(3)
                                    .map((tag) => Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: ConceptChip(
                                            label: tag,
                                            state: ConceptChipState.unselected,
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

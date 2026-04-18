import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ProblemDetailScreen extends StatelessWidget {
  final String slug;
  final int initialTab;

  const ProblemDetailScreen({
    super.key,
    required this.slug,
    this.initialTab = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(slug, style: AppTextStyles.screenTitle),
        backgroundColor: AppColors.background,
      ),
      body: Center(
        child: Text('Problem Detail ($slug) — coming in Phase 3',
            style: AppTextStyles.bodySecondary),
      ),
    );
  }
}

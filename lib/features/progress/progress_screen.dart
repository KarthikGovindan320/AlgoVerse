import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Progress', style: AppTextStyles.screenTitle),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Text('Progress — coming in Phase 5', style: AppTextStyles.bodySecondary),
      ),
    );
  }
}

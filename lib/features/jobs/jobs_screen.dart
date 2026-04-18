import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class JobsScreen extends StatelessWidget {
  final String? jobId;
  const JobsScreen({super.key, this.jobId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Jobs', style: AppTextStyles.screenTitle),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Text('Jobs — coming in Phase 8', style: AppTextStyles.bodySecondary),
      ),
    );
  }
}

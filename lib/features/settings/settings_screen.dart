import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings', style: AppTextStyles.screenTitle),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Text('Settings — coming in Phase 6', style: AppTextStyles.bodySecondary),
      ),
    );
  }
}

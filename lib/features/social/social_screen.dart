import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SocialScreen extends StatelessWidget {
  final String? duelId;
  const SocialScreen({super.key, this.duelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Social', style: AppTextStyles.screenTitle),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Text('Social — coming in Phase 7', style: AppTextStyles.bodySecondary),
      ),
    );
  }
}

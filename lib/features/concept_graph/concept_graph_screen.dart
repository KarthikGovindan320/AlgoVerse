import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ConceptGraphScreen extends StatelessWidget {
  const ConceptGraphScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Concepts', style: AppTextStyles.screenTitle),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Text('Concept Graph — coming in Phase 6', style: AppTextStyles.bodySecondary),
      ),
    );
  }
}

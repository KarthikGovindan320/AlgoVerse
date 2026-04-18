import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chat History', style: AppTextStyles.screenTitle),
        backgroundColor: AppColors.background,
      ),
      body: const Center(
        child: Text('Chat History — coming in Phase 6', style: AppTextStyles.bodySecondary),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum OnboardingStep { login, leetcode, concepts }

class OnboardingScreen extends StatelessWidget {
  final OnboardingStep step;
  const OnboardingScreen({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                step == OnboardingStep.login
                    ? 'Login'
                    : step == OnboardingStep.leetcode
                        ? 'Link LeetCode'
                        : 'Select Concepts',
                style: AppTextStyles.screenTitle,
              ),
              const SizedBox(height: 8),
              Text('Onboarding — coming in Phase 2',
                  style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ),
    );
  }
}

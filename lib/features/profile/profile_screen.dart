import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  final String? username;
  const ProfileScreen({super.key, this.username});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(username != null ? '@$username' : 'My Profile',
            style: AppTextStyles.screenTitle),
        backgroundColor: AppColors.background,
      ),
      body: Center(
        child: Text('Profile — coming in Phase 5', style: AppTextStyles.bodySecondary),
      ),
    );
  }
}

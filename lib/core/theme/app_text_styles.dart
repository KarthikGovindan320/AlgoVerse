import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String _inter = 'Inter';
  static const String _jetBrainsMono = 'JetBrainsMono';

  static const TextStyle screenTitle = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 32 / 24,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 24 / 18,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 22 / 16,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 22 / 15,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 18 / 13,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 16 / 12,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w400,
    fontSize: 11,
    height: 14 / 11,
    color: AppColors.textSecondary,
  );

  static const TextStyle code = TextStyle(
    fontFamily: _jetBrainsMono,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 20 / 13,
    color: AppColors.textPrimary,
  );

  static const TextStyle codeInline = TextStyle(
    fontFamily: _jetBrainsMono,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 16 / 12,
    color: AppColors.textPrimary,
  );
}

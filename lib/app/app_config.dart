import 'package:flutter/material.dart';

abstract final class AppConfig {
  static const String title = 'Cannon Mile';
  static const String brandingAsset =
      'assets/branding/orange_hat_boy_logo.webp';

  static const double designWidth = 1920;
  static const double designHeight = 1080;

  static const Color backgroundColor = Color(0xFF0C0C0C);
  static const Color progressColor = Color(0xFFFF7A1A);
  static const Color primaryTextColor = Color(0xFFF5FAFC);

  static const Duration logoPopDuration = Duration(milliseconds: 420);
  static const Duration loadingDelay = Duration(milliseconds: 500);
  static const Duration progressSettleDuration = Duration(milliseconds: 120);
  static const Duration completedHoldDuration = Duration(milliseconds: 300);
  static const Duration loadingFadeDuration = Duration(milliseconds: 800);
}

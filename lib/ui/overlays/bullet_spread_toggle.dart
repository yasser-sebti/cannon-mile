import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../game/components/tank/tank_bullet_spread_level.dart';
import '../widgets/raised_pressable.dart';

const bulletSpreadToggleKey = Key('bullet_spread_toggle');

class BulletSpreadToggle extends StatelessWidget {
  const BulletSpreadToggle({
    required this.level,
    required this.onToggle,
    super.key,
  });

  final TankBulletSpreadLevel level;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = 'SPREAD: ${level.level}/5';
    final radius = BorderRadius.circular(12);

    return Semantics(
      button: true,
      label: label,
      child: RaisedPressable(
        key: bulletSpreadToggleKey,
        width: 190,
        height: 44,
        radius: radius,
        shadowOffset: 4,
        shadowColor: const Color(0xFF080A0D),
        onTap: onToggle,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF20242A),
            borderRadius: radius,
            border: Border.all(color: AppConfig.progressColor, width: 2),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: AppConfig.primaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

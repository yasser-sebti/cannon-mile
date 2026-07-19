import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../game/components/tank/tank_weapon_mode.dart';
import '../widgets/raised_pressable.dart';

const weaponModeToggleKey = Key('weapon_mode_toggle');

class WeaponModeToggle extends StatelessWidget {
  const WeaponModeToggle({
    required this.mode,
    required this.onToggle,
    super.key,
  });

  final TankWeaponMode mode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isLaser = mode == TankWeaponMode.laser;
    final label = isLaser ? 'WEAPON: LASER' : 'WEAPON: BULLETS';
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      label: label,
      child: RaisedPressable(
        key: weaponModeToggleKey,
        width: 190,
        height: 44,
        radius: radius,
        shadowOffset: 4,
        shadowColor: isLaser
            ? const Color(0xFF8A3300)
            : const Color(0xFF080A0D),
        onTap: onToggle,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isLaser ? AppConfig.progressColor : const Color(0xFF20242A),
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

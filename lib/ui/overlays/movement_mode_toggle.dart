import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../game/components/tank/tank_movement_mode.dart';
import '../widgets/raised_pressable.dart';

const movementModeToggleKey = Key('movement_mode_toggle');

class MovementModeToggle extends StatelessWidget {
  const MovementModeToggle({
    required this.mode,
    required this.onToggle,
    super.key,
  });

  final TankMovementMode mode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isContinuous = mode == TankMovementMode.continuous;
    final faceColor = isContinuous
        ? AppConfig.progressColor
        : const Color(0xFF20242A);
    final shadowColor = isContinuous
        ? const Color(0xFF8A3300)
        : const Color(0xFF080A0D);
    final label = isContinuous ? 'MODE: CONTINUOUS' : 'MODE: BOSS FIGHT';
    final radius = BorderRadius.circular(12);

    return Semantics(
      button: true,
      label: label,
      child: RaisedPressable(
        key: movementModeToggleKey,
        width: 190,
        height: 44,
        radius: radius,
        shadowOffset: 4,
        shadowColor: shadowColor,
        onTap: onToggle,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: faceColor,
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

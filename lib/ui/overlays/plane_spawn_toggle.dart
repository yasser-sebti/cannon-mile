import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../widgets/raised_pressable.dart';

const planeSpawnToggleKey = Key('plane_spawn_toggle');

class PlaneSpawnToggle extends StatelessWidget {
  const PlaneSpawnToggle({
    required this.isEnabled,
    required this.onToggle,
    super.key,
  });

  final bool isEnabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = 'PLANES: ${isEnabled ? 'ON' : 'OFF'}';
    final radius = BorderRadius.circular(12);

    return Semantics(
      button: true,
      label: label,
      child: RaisedPressable(
        key: planeSpawnToggleKey,
        width: 190,
        height: 44,
        radius: radius,
        shadowOffset: 4,
        shadowColor: const Color(0xFF080A0D),
        onTap: onToggle,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isEnabled
                ? AppConfig.progressColor
                : const Color(0xFF20242A),
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

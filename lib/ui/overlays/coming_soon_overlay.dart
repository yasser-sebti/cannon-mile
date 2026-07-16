import 'package:flutter/material.dart';

import '../../app/app_config.dart';

class ComingSoonOverlay extends StatelessWidget {
  const ComingSoonOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Semantics(
          label: 'Coming Soon',
          child: const ExcludeSemantics(
            child: Text(
              'Coming Soon',
              key: Key('coming_soon_text'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppConfig.primaryTextColor,
                fontSize: 84,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';

/// Purely presentational — navigation away from splash is driven by
/// RouteGuards.redirect once authControllerProvider resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppConstants.appName, style: context.appTextStyles.displayLarge),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

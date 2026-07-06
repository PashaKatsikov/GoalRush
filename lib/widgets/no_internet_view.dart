import 'package:flutter/material.dart';

import '../constants/assets.dart';
import 'primary_button.dart';

/// Full-bleed "No internet connection" state, reusing the provided art for
/// both orientations, with a retry action.
class NoInternetView extends StatelessWidget {
  const NoInternetView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final asset = isLandscape ? AppAssets.horizontalNoWifi : AppAssets.verticalNoWifi;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover),
        Positioned(
          left: 24,
          right: 24,
          bottom: 48 + MediaQuery.of(context).padding.bottom,
          child: PrimaryButton(label: 'TRY AGAIN', icon: Icons.refresh, onTap: onRetry),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class ImageBackground extends StatelessWidget {
  const ImageBackground({
    super.key,
    required this.asset,
    required this.child,
    this.lightOverlay = 0.82,
  });

  final String asset;
  final Widget child;
  final double lightOverlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover),
        ColoredBox(
          color: Color.fromRGBO(255, 255, 255, lightOverlay),
        ),
        child,
      ],
    );
  }
}

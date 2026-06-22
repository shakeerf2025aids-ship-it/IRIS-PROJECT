import 'package:flutter/material.dart';

class IrisLogo extends StatelessWidget {
  final double size;
  const IrisLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/new_logo.jpg',
        fit: BoxFit.contain,
      ),
    );
  }
}

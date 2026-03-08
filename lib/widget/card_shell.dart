
import 'package:flutter/material.dart';

class CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const CardShell({required this.child, this.padding = const EdgeInsets.all(16), super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}
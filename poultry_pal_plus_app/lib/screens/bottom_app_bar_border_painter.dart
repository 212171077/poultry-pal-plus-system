import 'package:flutter/cupertino.dart';

class BottomAppBarBorderPainter extends CustomPainter {
  final Color color;

  BottomAppBarBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Define the rectangle of the BottomAppBar
    final Rect barRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Rect buttonRect = Rect.fromCircle(center: Offset(size.width / 2, 0), radius: 30);

    // Use CircularNotchedRectangle to generate the path
    const CircularNotchedRectangle notch = CircularNotchedRectangle();
    final Path outerPath = notch.getOuterPath(barRect, buttonRect);

    canvas.drawPath(outerPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  final assetsDir = Directory('assets/brand');
  assetsDir.createSync(recursive: true);

  final icon = _createIcon(1024);
  img.encodePngFile('assets/brand/app_icon.png', icon);

  final splashLogo = _createIcon(512);
  img.encodePngFile('assets/brand/splash_logo.png', splashLogo);
}

img.Image _createIcon(int size) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  final scale = size / 1024.0;
  final primary = img.ColorRgba8(15, 118, 110, 255);
  final deep = img.ColorRgba8(11, 59, 56, 255);
  final mint = img.ColorRgba8(225, 241, 236, 255);
  final gold = img.ColorRgba8(233, 185, 73, 255);
  final white = img.ColorRgba8(255, 255, 255, 255);

  _roundedRect(
    canvas,
    96 * scale,
    96 * scale,
    832 * scale,
    832 * scale,
    190 * scale,
    primary,
  );
  _roundedRect(
    canvas,
    164 * scale,
    174 * scale,
    696 * scale,
    650 * scale,
    120 * scale,
    white,
  );
  _roundedRect(
    canvas,
    216 * scale,
    248 * scale,
    592 * scale,
    454 * scale,
    82 * scale,
    mint,
  );

  final centerX = size / 2;
  final dialCenterY = 468 * scale;
  _circle(canvas, centerX, dialCenterY, 150 * scale, white);
  _circle(
    canvas,
    centerX,
    dialCenterY,
    118 * scale,
    img.ColorRgba8(245, 249, 246, 255),
  );

  for (var i = 0; i < 13; i++) {
    final angle = math.pi + (math.pi * i / 12);
    final inner = 96 * scale;
    final outer = i == 6 ? 126 * scale : 114 * scale;
    final stroke = i == 6 ? 9 * scale : 6 * scale;
    _line(
      canvas,
      centerX + math.cos(angle) * inner,
      dialCenterY + math.sin(angle) * inner,
      centerX + math.cos(angle) * outer,
      dialCenterY + math.sin(angle) * outer,
      stroke,
      deep,
    );
  }

  final needleAngle = math.pi * 1.34;
  _line(
    canvas,
    centerX,
    dialCenterY,
    centerX + math.cos(needleAngle) * 94 * scale,
    dialCenterY + math.sin(needleAngle) * 94 * scale,
    12 * scale,
    gold,
  );
  _circle(canvas, centerX, dialCenterY, 18 * scale, deep);

  _roundedRect(
    canvas,
    292 * scale,
    654 * scale,
    440 * scale,
    88 * scale,
    44 * scale,
    deep,
  );
  _roundedRect(
    canvas,
    324 * scale,
    682 * scale,
    72 * scale,
    16 * scale,
    8 * scale,
    gold,
  );
  _roundedRect(
    canvas,
    420 * scale,
    682 * scale,
    72 * scale,
    16 * scale,
    8 * scale,
    white,
  );
  _roundedRect(
    canvas,
    516 * scale,
    682 * scale,
    72 * scale,
    16 * scale,
    8 * scale,
    white,
  );
  _roundedRect(
    canvas,
    612 * scale,
    682 * scale,
    72 * scale,
    16 * scale,
    8 * scale,
    white,
  );

  return canvas;
}

void _roundedRect(
  img.Image image,
  double x,
  double y,
  double width,
  double height,
  double radius,
  img.Color color,
) {
  final x0 = x.round();
  final y0 = y.round();
  final x1 = (x + width).round();
  final y1 = (y + height).round();
  final r = radius.round();

  img.fillRect(image, x1: x0 + r, y1: y0, x2: x1 - r, y2: y1, color: color);
  img.fillRect(image, x1: x0, y1: y0 + r, x2: x1, y2: y1 - r, color: color);
  _circle(image, (x0 + r).toDouble(), (y0 + r).toDouble(), r.toDouble(), color);
  _circle(image, (x1 - r).toDouble(), (y0 + r).toDouble(), r.toDouble(), color);
  _circle(image, (x0 + r).toDouble(), (y1 - r).toDouble(), r.toDouble(), color);
  _circle(image, (x1 - r).toDouble(), (y1 - r).toDouble(), r.toDouble(), color);
}

void _circle(
  img.Image image,
  double cx,
  double cy,
  double radius,
  img.Color color,
) {
  img.fillCircle(
    image,
    x: cx.round(),
    y: cy.round(),
    radius: radius.round(),
    color: color,
  );
}

void _line(
  img.Image image,
  double x1,
  double y1,
  double x2,
  double y2,
  double thickness,
  img.Color color,
) {
  img.drawLine(
    image,
    x1: x1.round(),
    y1: y1.round(),
    x2: x2.round(),
    y2: y2.round(),
    color: color,
    thickness: thickness.round().clamp(1, 1000),
  );
}

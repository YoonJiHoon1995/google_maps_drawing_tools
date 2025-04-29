import 'dart:ui';

extension ColorExtension on int {
  Color toColor() {
    return Color(this);
  }
}

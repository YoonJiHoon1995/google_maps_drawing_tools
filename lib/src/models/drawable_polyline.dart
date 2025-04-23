import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

class DrawablePolyline {
  final String id;
  final List<LatLng> points;
  final Color color;
  final int width;

  const DrawablePolyline({
    required this.id,
    required this.points,
    this.color = Colors.blue,
    this.width = 3,
  });

  DrawablePolyline copyWith({
    List<LatLng>? points,
    Color? color,
    int? width,
  }) {
    return DrawablePolyline(
      id: id,
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
    );
  }

  Polyline toGooglePolyline() {
    return Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color,
      width: width,
    );
  }
}

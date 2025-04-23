// drawing_circle.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DrawableCircle {
  final String id;
  final LatLng center;
  final double radius;
  final Color strokeColor;
  final Color fillColor;
  final int strokeWidth;
  final bool editable;

  DrawableCircle({
    required this.id,
    required this.center,
    required this.radius,
    this.strokeColor = Colors.blue,
    this.fillColor = Colors.transparent,
    this.strokeWidth = 2,
    this.editable = true,
  });

  Circle toCircle({Function(LatLng)? onTap}) {
    return Circle(
      circleId: CircleId(id),
      center: center,
      radius: radius,
      strokeColor: strokeColor,
      fillColor: fillColor,
      strokeWidth: strokeWidth,
      consumeTapEvents: onTap != null,
      onTap: onTap != null ? () => onTap(center) : null,
    );
  }

  DrawableCircle copyWith({
    LatLng? center,
    double? radius,
    Color? strokeColor,
    Color? fillColor,
    int? strokeWidth,
    bool? editable,
  }) {
    return DrawableCircle(
      id: id,
      center: center ?? this.center,
      radius: radius ?? this.radius,
      strokeColor: strokeColor ?? this.strokeColor,
      fillColor: fillColor ?? this.fillColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      editable: editable ?? this.editable,
    );
  }

  Map<String, dynamic> toGeoJson() {
    return {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [center.longitude, center.latitude],
      },
      "properties": {
        "radius": radius,
        "id": id,
      }
    };
  }
}

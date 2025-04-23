import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DrawableRectangle {
  final String id;
  final LatLngBounds bounds;
  final Color strokeColor;
  final Color fillColor;
  final int strokeWidth;
  final bool editable;
  final LatLng anchor;

  DrawableRectangle({
    required this.id,
    required this.bounds,
    required this.anchor,
    this.strokeColor = Colors.blue,
    this.fillColor = Colors.transparent,
    this.strokeWidth = 2,
    this.editable = true,
  });

  List<LatLng> get cornerPoints => [
    bounds.southwest,
    LatLng(bounds.southwest.latitude, bounds.northeast.longitude),
    bounds.northeast,
    LatLng(bounds.northeast.latitude, bounds.southwest.longitude),
  ];

  Polygon toPolygon() {
    return Polygon(
      polygonId: PolygonId(id),
      points: cornerPoints + [cornerPoints.first], // close the loop
      strokeColor: strokeColor,
      fillColor: fillColor,
      strokeWidth: strokeWidth,
    );
  }

  DrawableRectangle copyWith({
    LatLngBounds? bounds,
    Color? strokeColor,
    Color? fillColor,
    int? strokeWidth,
    bool? editable,
    LatLng? anchor,
  }) {
    return DrawableRectangle(
      id: id,
      bounds: bounds ?? this.bounds,
      strokeColor: strokeColor ?? this.strokeColor,
      fillColor: fillColor ?? this.fillColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      editable: editable ?? this.editable,
      anchor: anchor ?? this.anchor,
    );
  }
}

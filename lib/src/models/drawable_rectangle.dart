import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DrawableRectangle {
  final String id;
  final LatLngBounds bounds;
  final Color strokeColor;
  final Color fillColor;
  final int strokeWidth;
  final bool isSelected;
  final bool editable;
  final LatLng anchor;
  final int zIndex;
  final bool visible;
  final Map<String, dynamic>? metadata;

  DrawableRectangle({
    required this.id,
    required this.bounds,
    required this.anchor,
    this.strokeColor = Colors.blue,
    this.fillColor = Colors.transparent,
    this.strokeWidth = 2,
    this.isSelected = false,
    this.editable = true,
    this.zIndex = 0,
    this.visible = true,
    this.metadata,
  });

  List<LatLng> get cornerPoints => [
    bounds.southwest,
    LatLng(bounds.southwest.latitude, bounds.northeast.longitude),
    bounds.northeast,
    LatLng(bounds.northeast.latitude, bounds.southwest.longitude),
  ];

  Polygon toPolygon({
    void Function(LatLng position, String polygonId)? onTap,
  }) {
    return Polygon(
      polygonId: PolygonId(id),
      points: cornerPoints + [cornerPoints.first], // close the loop
      strokeColor: strokeColor,
      fillColor: fillColor,
      strokeWidth: strokeWidth,
      consumeTapEvents: onTap != null,
      zIndex: zIndex,
      visible: visible,
      onTap: onTap != null ? () => onTap(cornerPoints.first, id) : null,
    );
  }

  DrawableRectangle copyWith({
    LatLngBounds? bounds,
    Color? strokeColor,
    Color? fillColor,
    int? strokeWidth,
    bool? editable,
    LatLng? anchor,
    bool? isSelected,
    int? zIndex,
    bool? visible,
    Map<String, dynamic>? metadata,
  }) {
    return DrawableRectangle(
      id: id,
      bounds: bounds ?? this.bounds,
      strokeColor: strokeColor ?? this.strokeColor,
      fillColor: fillColor ?? this.fillColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isSelected: isSelected ?? this.isSelected,
      editable: editable ?? this.editable,
      anchor: anchor ?? this.anchor,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      metadata: metadata ?? this.metadata,
    );
  }

  bool contains(LatLng point) {
    return point.latitude >= bounds.southwest.latitude &&
        point.latitude <= bounds.northeast.latitude &&
        point.longitude >= bounds.southwest.longitude &&
        point.longitude <= bounds.northeast.longitude;
  }
}

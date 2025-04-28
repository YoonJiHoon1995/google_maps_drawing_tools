// drawing_circle.dart

import 'package:flutter/material.dart';
import 'package:google_maps_drawing_tools/src/utils/extensions.dart';
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
        "id": id,
        "radius": radius,
        "strokeColor": strokeColor.toARGB32(),
        "fillColor": fillColor.toARGB32(),
        "strokeWidth": strokeWidth,
        "editable": editable,
      }
    };
  }

  List<DrawableCircle> drawableCirclesFromGeoJson(Map<String, dynamic> geoJson) {
    if (geoJson['type'] != 'FeatureCollection') {
      throw ArgumentError('Invalid GeoJSON: Expected a FeatureCollection.');
    }

    final List features = geoJson['features'];

    return features.map<DrawableCircle>((feature) {
      final geometry = feature['geometry'];
      final properties = feature['properties'] ?? {};

      if (geometry['type'] != 'Point') {
        throw ArgumentError('Invalid Geometry: Expected Point for Circle.');
      }

      final List coordinates = geometry['coordinates'];

      return DrawableCircle(
        id: properties['id'] ?? UniqueKey().toString(),
        center: LatLng(coordinates[1], coordinates[0]),
        radius: (properties['radius'] as num).toDouble(),
        strokeColor: (properties['strokeColor'] as int?)?.toColor() ?? Colors.blue,
        fillColor: (properties['fillColor'] as int?)?.toColor() ?? Colors.transparent,
        strokeWidth: (properties['strokeWidth'] as int?) ?? 2,
        editable: (properties['editable'] as bool?) ?? true,
      );
    }).toList();
  }

  DrawableCircle drawableCircleFromGeoJsonFeature(Map<String, dynamic> feature) {
    if (feature['type'] != 'Feature' || feature['geometry']['type'] != 'Point') {
      throw ArgumentError('Invalid GeoJSON: Expected a single Point Feature.');
    }

    final geometry = feature['geometry'];
    final properties = feature['properties'] ?? {};

    final List coordinates = geometry['coordinates'];

    return DrawableCircle(
      id: properties['id'] ?? UniqueKey().toString(),
      center: LatLng(coordinates[1], coordinates[0]),
      radius: (properties['radius'] as num).toDouble(),
      strokeColor: (properties['strokeColor'] as int?)?.toColor() ?? Colors.blue,
      fillColor: (properties['fillColor'] as int?)?.toColor() ?? Colors.transparent,
      strokeWidth: (properties['strokeWidth'] as int?) ?? 2,
      editable: (properties['editable'] as bool?) ?? true,
    );
  }
}

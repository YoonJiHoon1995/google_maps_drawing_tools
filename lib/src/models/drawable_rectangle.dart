import 'package:flutter/material.dart';
import 'package:google_maps_drawing_tools/src/utils/extensions.dart';
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

  Map<String, dynamic> toGeoJson() {
    return {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          cornerPoints.map((p) => [p.longitude, p.latitude]).toList() +
              [
                [cornerPoints.first.longitude, cornerPoints.first.latitude]
              ] // Closing the loop
        ],
      },
      "properties": {
        "id": id,
        "strokeColor": strokeColor.toARGB32(),
        "fillColor": fillColor.toARGB32(),
        "strokeWidth": strokeWidth,
        "editable": editable,
        "zIndex": zIndex,
        "visible": visible,
        ...?metadata,
      }
    };
  }

  List<DrawableRectangle> drawableRectanglesFromGeoJson(Map<String, dynamic> geoJson) {
    if (geoJson['type'] != 'FeatureCollection') {
      throw ArgumentError('Invalid GeoJSON: Expected a FeatureCollection.');
    }

    final List features = geoJson['features'];

    return features.map<DrawableRectangle>((feature) {
      final geometry = feature['geometry'];
      final properties = feature['properties'] ?? {};

      if (geometry['type'] != 'Polygon') {
        throw ArgumentError('Invalid Geometry: Expected Polygon for Rectangle.');
      }

      final List coordinates = geometry['coordinates'][0];

      if (coordinates.length < 4) {
        throw ArgumentError('Invalid Polygon: A rectangle must have at least 4 points.');
      }

      final southwest = LatLng(coordinates[0][1], coordinates[0][0]);
      final northeast = LatLng(coordinates[2][1], coordinates[2][0]);

      return DrawableRectangle(
        id: properties['id'] ?? UniqueKey().toString(),
        bounds: LatLngBounds(southwest: southwest, northeast: northeast),
        anchor: southwest, // You can customize which point to use as anchor if needed
        strokeColor: (properties['strokeColor'] as int?)?.toColor() ?? Colors.blue,
        fillColor: (properties['fillColor'] as int?)?.toColor() ?? Colors.transparent,
        strokeWidth: (properties['strokeWidth'] as int?) ?? 2,
        editable: (properties['editable'] as bool?) ?? true,
        zIndex: (properties['zIndex'] as int?) ?? 0,
        visible: (properties['visible'] as bool?) ?? true,
        metadata: properties,
      );
    }).toList();
  }

  DrawableRectangle drawableRectangleFromGeoJsonFeature(Map<String, dynamic> feature) {
    if (feature['type'] != 'Feature' || feature['geometry']['type'] != 'Polygon') {
      throw ArgumentError('Invalid GeoJSON: Expected a single Polygon Feature.');
    }

    final geometry = feature['geometry'];
    final properties = feature['properties'] ?? {};

    final List coordinates = geometry['coordinates'][0];

    if (coordinates.length < 4) {
      throw ArgumentError('Invalid Polygon: A rectangle must have at least 4 points.');
    }

    final southwest = LatLng(coordinates[0][1], coordinates[0][0]);
    final northeast = LatLng(coordinates[2][1], coordinates[2][0]);

    return DrawableRectangle(
      id: properties['id'] ?? UniqueKey().toString(),
      bounds: LatLngBounds(southwest: southwest, northeast: northeast),
      anchor: southwest,
      strokeColor: (properties['strokeColor'] as int?)?.toColor() ?? Colors.blue,
      fillColor: (properties['fillColor'] as int?)?.toColor() ?? Colors.transparent,
      strokeWidth: (properties['strokeWidth'] as int?) ?? 2,
      editable: (properties['editable'] as bool?) ?? true,
      zIndex: (properties['zIndex'] as int?) ?? 0,
      visible: (properties['visible'] as bool?) ?? true,
      metadata: properties,
    );
  }
}

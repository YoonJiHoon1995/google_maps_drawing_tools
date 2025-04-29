import 'package:flutter/material.dart';
import 'package:google_maps_drawing_tools/src/utils/extensions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DrawablePolygon {
  final String id;
  final List<LatLng> points;
  final Color strokeColor;
  final Color fillColor;
  final int strokeWidth;
  final bool editable;
  final int zIndex;
  final bool visible;
  final Map<String, dynamic>? metadata;

  const DrawablePolygon({
    required this.id,
    required this.points,
    this.strokeColor = Colors.blue,
    this.fillColor = Colors.transparent,
    this.strokeWidth = 2,
    this.editable = true,
    this.zIndex = 1,
    this.visible = true,
    this.metadata,
  });

  Polygon toPolygon({
    void Function(LatLng position, String polygonId)? onTap,
  }) {
    return Polygon(
      polygonId: PolygonId(id),
      points: points,
      strokeColor: strokeColor,
      fillColor: fillColor,
      strokeWidth: strokeWidth,
      consumeTapEvents: onTap != null,
      zIndex: zIndex,
      visible: visible,
      onTap: onTap != null ? () => onTap(points.first, id) : null,
    );
  }

  DrawablePolygon copyWith({
    List<LatLng>? points,
    Color? strokeColor,
    Color? fillColor,
    int? strokeWidth,
    bool? editable,
    int? zIndex,
    bool? visible,
    Map<String, dynamic>? metadata,
  }) {
    return DrawablePolygon(
      id: id,
      points: points ?? this.points,
      strokeColor: strokeColor ?? this.strokeColor,
      fillColor: fillColor ?? this.fillColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      editable: editable ?? this.editable,
      zIndex: zIndex ?? this.zIndex,
      visible: visible ?? this.visible,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toGeoJson() {
    return {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          points.map((p) => [p.longitude, p.latitude]).toList()
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

  List<DrawablePolygon> drawablePolygonsFromGeoJson(
      Map<String, dynamic> geoJson) {
    if (geoJson['type'] != 'FeatureCollection' || geoJson['features'] == null) {
      throw ArgumentError('Invalid GeoJSON: Expected a FeatureCollection.');
    }

    final features = geoJson['features'] as List<dynamic>;

    return features
        .where((feature) => feature['geometry']['type'] == 'Polygon')
        .map<DrawablePolygon>((feature) {
      final geometry = feature['geometry'];
      final properties = feature['properties'] ?? {};

      final List coordinates = geometry['coordinates'][0];
      final points = coordinates
          .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
          .toList();

      return DrawablePolygon(
        id: properties['id'] ?? UniqueKey().toString(),
        points: points,
        strokeColor:
            (properties['strokeColor'] as int?)?.toColor() ?? Colors.blue,
        fillColor:
            (properties['fillColor'] as int?)?.toColor() ?? Colors.transparent,
        strokeWidth: (properties['strokeWidth'] as int?) ?? 2,
        editable: (properties['editable'] as bool?) ?? true,
        zIndex: (properties['zIndex'] as int?) ?? 1,
        visible: (properties['visible'] as bool?) ?? true,
        metadata: properties,
      );
    }).toList();
  }

  DrawablePolygon drawablePolygonFromGeoJsonFeature(
      Map<String, dynamic> feature) {
    if (feature['type'] != 'Feature' ||
        feature['geometry']['type'] != 'Polygon') {
      throw ArgumentError(
          'Invalid GeoJSON: Expected a single Polygon Feature.');
    }

    final geometry = feature['geometry'];
    final properties = feature['properties'] ?? {};

    final List coordinates = geometry['coordinates'][0];
    final points =
        coordinates.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();

    return DrawablePolygon(
      id: properties['id'] ?? UniqueKey().toString(),
      points: points,
      strokeColor:
          (properties['strokeColor'] as int?)?.toColor() ?? Colors.blue,
      fillColor:
          (properties['fillColor'] as int?)?.toColor() ?? Colors.transparent,
      strokeWidth: (properties['strokeWidth'] as int?) ?? 2,
      editable: (properties['editable'] as bool?) ?? true,
      zIndex: (properties['zIndex'] as int?) ?? 1,
      visible: (properties['visible'] as bool?) ?? true,
      metadata: properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawablePolygon &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

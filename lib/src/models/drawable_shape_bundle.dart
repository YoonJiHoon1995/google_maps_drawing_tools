import 'package:flutter/material.dart';
import 'package:google_maps_drawing_tools/google_maps_drawing_tools.dart';
import 'package:google_maps_drawing_tools/src/utils/extensions.dart';

class DrawableShapesBundle {
  final List<DrawablePolygon> polygons;
  final List<DrawableRectangle> rectangles;
  final List<DrawableCircle> circles;

  DrawableShapesBundle({
    required this.polygons,
    required this.rectangles,
    required this.circles,
  });
}

DrawableShapesBundle drawableShapesFromGeoJson(Map<String, dynamic> geoJson) {
  if (geoJson['type'] != 'FeatureCollection') {
    throw ArgumentError('Invalid GeoJSON: Expected a FeatureCollection.');
  }

  final List features = geoJson['features'];

  final List<DrawablePolygon> polygons = [];
  final List<DrawableRectangle> rectangles = [];
  final List<DrawableCircle> circles = [];

  for (final feature in features) {
    final geometry = feature['geometry'];
    final properties = feature['properties'] ?? {};

    final type = geometry['type'];

    if (type == 'Polygon') {
      final coordinates = geometry['coordinates'][0] as List;
      final points = coordinates.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();

      // Check if it looks like a rectangle
      if (_isRectangle(points)) {
        final bounds = LatLngBounds(
          southwest: LatLng(
            points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
            points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
          ),
          northeast: LatLng(
            points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
            points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
          ),
        );

        rectangles.add(DrawableRectangle(
          id: properties['id'] ?? UniqueKey().toString(),
          bounds: bounds,
          anchor: LatLng(
            (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
            (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
          ),
          strokeColor: (properties['strokeColor'] as int?)?.toColor() ?? Colors.blue,
          fillColor: (properties['fillColor'] as int?)?.toColor() ?? Colors.transparent,
          strokeWidth: (properties['strokeWidth'] as int?) ?? 2,
          editable: (properties['editable'] as bool?) ?? true,
          zIndex: (properties['zIndex'] as int?) ?? 0,
          visible: (properties['visible'] as bool?) ?? true,
          metadata: properties,
        ));
      } else {
        polygons.add(DrawablePolygon(
          id: properties['id'] ?? UniqueKey().toString(),
          points: points,
          strokeColor: (properties['strokeColor'] as int?)?.toColor() ?? Colors.blue,
          fillColor: (properties['fillColor'] as int?)?.toColor() ?? Colors.transparent,
          strokeWidth: (properties['strokeWidth'] as int?) ?? 2,
          editable: (properties['editable'] as bool?) ?? true,
          zIndex: (properties['zIndex'] as int?) ?? 1,
          visible: (properties['visible'] as bool?) ?? true,
          metadata: properties,
        ));
      }
    } else if (type == 'Point') {
      final coordinates = geometry['coordinates'];
      circles.add(DrawableCircle(
        id: properties['id'] ?? UniqueKey().toString(),
        center: LatLng(coordinates[1], coordinates[0]),
        radius: (properties['radius'] as num).toDouble(),
        strokeColor: (properties['strokeColor'] as int?)?.toColor() ?? Colors.blue,
        fillColor: (properties['fillColor'] as int?)?.toColor() ?? Colors.transparent,
        strokeWidth: (properties['strokeWidth'] as int?) ?? 2,
        editable: (properties['editable'] as bool?) ?? true,
      ));
    }
  }

  return DrawableShapesBundle(
    polygons: polygons,
    rectangles: rectangles,
    circles: circles,
  );
}

/// Helper: Checks if a list of points forms a rectangle (with 90-degree angle check)
bool _isRectangle(List<LatLng> points) {
  if (points.length != 4) return false; // Rectangle should have exactly 4 points

  // Check if the points form a closed shape
  if (!_areLatLngEqual(points[0], points[3])) {
    return false; // The first and last point should be the same to form a closed polygon
  }

  // Helper to calculate the vector (dx, dy) between two points
  LatLng vector(LatLng from, LatLng to) {
    return LatLng(to.latitude - from.latitude, to.longitude - from.longitude);
  }

  // Helper to calculate dot product of two vectors
  double dotProduct(LatLng v1, LatLng v2) {
    return v1.latitude * v2.latitude + v1.longitude * v2.longitude;
  }

  // Check if vectors are perpendicular (dot product == 0)
  bool isPerpendicular(LatLng v1, LatLng v2) {
    return dotProduct(v1, v2) == 0;
  }

  // Vectors for each side of the rectangle
  LatLng v1 = vector(points[0], points[1]);
  LatLng v2 = vector(points[1], points[2]);
  LatLng v3 = vector(points[2], points[3]);
  LatLng v4 = vector(points[3], points[0]);

  // Check if the dot products between adjacent vectors are close to zero (perpendicular)
  bool isPerpendicular1 = isPerpendicular(v1, v2);
  bool isPerpendicular2 = isPerpendicular(v2, v3);
  bool isPerpendicular3 = isPerpendicular(v3, v4);
  bool isPerpendicular4 = isPerpendicular(v4, v1);

  return isPerpendicular1 && isPerpendicular2 && isPerpendicular3 && isPerpendicular4;
}

/// Helper to compare two LatLng objects for equality
bool _areLatLngEqual(LatLng point1, LatLng point2) {
  return point1.latitude == point2.latitude && point1.longitude == point2.longitude;
}

/// Export function to convert lists of DrawablePolygon, DrawableRectangle, and DrawableCircle
/// into one GeoJSON object.
Map<String, dynamic> exportToGeoJson({
  required List<DrawablePolygon> polygons,
  required List<DrawableRectangle> rectangles,
  required List<DrawableCircle> circles,
}) {
  List<Map<String, dynamic>> features = [];

  // Add all polygons
  for (var polygon in polygons) {
    features.add(polygon.toGeoJson());
  }

  // Add all rectangles (converted to polygons)
  for (var rectangle in rectangles) {
    features.add(rectangle.toGeoJson());
  }

  // Add all circles (converted to points with radius)
  for (var circle in circles) {
    features.add(circle.toGeoJson());
  }

  return {
    "type": "FeatureCollection",
    "features": features,
  };
}

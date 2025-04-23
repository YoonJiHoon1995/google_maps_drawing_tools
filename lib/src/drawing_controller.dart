// File: lib/src/drawing_controller.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:collection/collection.dart';
import 'models/drawable_circle.dart';
import 'models/drawable_polygon.dart';
import 'models/drawable_polyline.dart';

enum DrawMode { none, polygon, polyline, circle, rectangle }

typedef OnPolygonDrawn = void Function(DrawablePolygon polygon);

class DrawingController extends ChangeNotifier {
  DrawingController({
    this.onPolygonDrawn,
    this.onPolygonSelected,
    this.onPolygonUpdated,
    this.onPolygonDeleted,
    BitmapDescriptor? firstPolygonMarker,
    BitmapDescriptor? customPolygonMarker,
    BitmapDescriptor? midpointPolygonMarker,
    BitmapDescriptor? circleCenterMarker,
    BitmapDescriptor? circleRadiusHandle,
  }) {
    // Set default custom icon if none is passed
    firstPolygonMarkerIcon = firstPolygonMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    customPolygonMarkerIcon = customPolygonMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    midpointPolygonMarkerIcon = midpointPolygonMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    circleCenterMarkerIcon = circleCenterMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    circleRadiusHandleIcon = circleRadiusHandle ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  /// Polygon Drawing Logic
  late BitmapDescriptor customPolygonMarkerIcon;
  late BitmapDescriptor firstPolygonMarkerIcon;
  late BitmapDescriptor midpointPolygonMarkerIcon;
  DrawMode _currentMode = DrawMode.none;
  final List<DrawablePolygon> _polygons = [];
  final List<DrawablePolyline> _polylines = [];
  DrawablePolyline? _activePolyline;
  DrawablePolygon? _activePolygon;
  DrawablePolygon? _selectedPolygon;
  GoogleMapController? googleMapController;

  /// Callback for when a polygon is drawn
  void Function(List<DrawablePolygon> allPolygons)? onPolygonDrawn;

  /// Called when a polygon is selected
  void Function(DrawablePolygon selected)? onPolygonSelected;

  /// Called when a polygon is updated (points or color)
  void Function(DrawablePolygon updated)? onPolygonUpdated;

  /// Called when a polygon is deleted
  void Function(String deletedPolygonId)? onPolygonDeleted;

  double currentZoom = 0;

  DrawMode get currentMode => _currentMode;
  List<DrawablePolygon> get polygons => List.unmodifiable(_polygons);
  DrawablePolygon? get selectedPolygon => _selectedPolygon;

  String? get activePolygonId => _activePolygon?.id;
  // Update this on map tap or move
  LatLng? currentCursorPosition;

  Color _currentDrawingColor = Colors.red;

  Color get currentDrawingColor => _currentDrawingColor;

  // Function to set a custom marker icon
  void setFirstPolygonCustomMarkerIcon(BitmapDescriptor icon) {
    firstPolygonMarkerIcon = icon;
    notifyListeners(); // This will trigger the UI update to use the new icon
  }

  void setMidpointPolygonCustomMarkerIcon(BitmapDescriptor icon) {
    midpointPolygonMarkerIcon = icon;
    notifyListeners(); // This will trigger the UI update to use the new icon
  }

  void setPolygonCustomMarkerIcon(BitmapDescriptor icon) {
    customPolygonMarkerIcon = icon;
    notifyListeners(); // This will trigger the UI update to use the new icon
  }

  void setColor(Color color) {
    _currentDrawingColor = color;
    notifyListeners();
  }

  void updateColor(String id, Color newColor) {
    if (currentMode == DrawMode.polygon) {
      final index = _polygons.indexWhere((p) => p.id == id);
      if (index == -1) return;

      final oldPolygon = _polygons[index];
      final updatedPolygon = oldPolygon.copyWith(strokeColor: newColor, fillColor: newColor.withValues(alpha: 0.2));

      _polygons[index] = updatedPolygon;

      if (_selectedPolygon?.id == id) {
        _selectedPolygon = updatedPolygon;
      }
      onPolygonUpdated?.call(updatedPolygon);
    } else if (currentMode == DrawMode.circle) {
      final index = _drawableCircles.indexWhere((c) => c.id == id);
      if (index == -1) return;

      final oldCircle = _drawableCircles[index];
      final updatedCircle = oldCircle.copyWith(strokeColor: newColor, fillColor: newColor.withOpacity(0.2));

      _drawableCircles[index] = updatedCircle;

      if (_selectedCircleId == id) {
        _selectedCircleId = updatedCircle.id;
      }
      onCircleUpdated?.call(updatedCircle);
    }

    notifyListeners();
  }

  void setDrawMode(DrawMode mode) {
    finishPolygon();
    _currentMode = mode;
    _activePolygon = null;
    _selectedPolygon = null;
    notifyListeners();
  }

  double _calculateDistanceMeters(LatLng p1, LatLng p2) {
    const earthRadius = 6371000; // Radius of Earth in meters
    final lat1 = p1.latitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    final dLat = (p2.latitude - p1.latitude) * pi / 180;
    final dLng = (p2.longitude - p1.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Utility to detect proximity
  bool isNear(LatLng p1, LatLng p2, {double thresholdInMeters = 15}) {
    final distance = Geolocator.distanceBetween(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
    return distance < thresholdInMeters;
  }

  bool isSameMarkerTap(LatLng tap, LatLng marker, {double thresholdMeters = 10.0}) {
    return _calculateDistanceMeters(tap, marker) < thresholdMeters;
  }

  void addPolygonPoint(LatLng point) {
    if (_currentMode != DrawMode.polygon) return;

    if (_activePolygon == null) {
      // First tap, start new polygon
      _activePolygon = DrawablePolygon(id: UniqueKey().toString(), points: [point], strokeColor: Colors.transparent);
      _selectedPolygon = _activePolygon;
      _polygons.add(_activePolygon!);

      _activePolyline = DrawablePolyline(id: _activePolygon!.id, points: [point], color: currentDrawingColor);
      _polylines.add(_activePolyline!);
    } else {
      final firstPoint = _activePolygon!.points.first;

      // Instead of distance-based snapping, check if user tapped on the first point
      final tappedFirstMarker = isSameMarkerTap(point, firstPoint);

      if (tappedFirstMarker && _activePolygon!.points.length > 2) {
        // Close polygon if tapped on first point
        _activePolygon = _activePolygon!.copyWith(points: [..._activePolygon!.points, firstPoint]);
        finishPolygon();
        return;
      }

      final updatedPoints = [..._activePolygon!.points, point];

      _activePolygon = _activePolygon!.copyWith(points: updatedPoints);
      _activePolyline = _activePolyline!.copyWith(points: updatedPoints);

      final polygonIndex = _polygons.indexWhere((p) => p.id == _activePolygon!.id);
      if (polygonIndex != -1) _polygons[polygonIndex] = _activePolygon!;

      final polylineIndex = _polylines.indexWhere((p) => p.id == _activePolyline!.id);
      if (polylineIndex != -1) _polylines[polylineIndex] = _activePolyline!;

      _selectedPolygon = _activePolygon;
    }

    notifyListeners();
  }

  void handleFirstMarkerTap() {
    if (_currentMode == DrawMode.polygon && _activePolygon != null && _activePolygon!.points.length > 2) {
      finishPolygon();
    }
  }

  double _snapThresholdForZoom(double zoom) {
    // At zoom 0, snap threshold ~300 meters
    // At zoom 21, snap threshold ~0.15 meters
    const baseThreshold = 300.0; // Starting threshold at zoom 0
    final scaleFactor = pow(2, zoom); // 2^zoom scaling factor

    // Dynamically scale the threshold for higher zoom levels, but avoid too small thresholds
    final threshold = baseThreshold / scaleFactor;

    // Prevent threshold from being too small at high zoom levels
    // Cap the threshold between 1 meter and 300 meters for reasonable behavior
    return threshold < 1.0
        ? 1.0
        : threshold > 300.0
        ? 300.0
        : threshold;
  }

  bool isNearPoint(LatLng p1, LatLng p2, double zoom) {
    final threshold = _snapThresholdForZoom(zoom);
    debugPrint("Threshold: $threshold");
    debugPrint("Distance between points: ${_calculateDistanceMeters(p1, p2)}");

    return _calculateDistanceMeters(p1, p2) < threshold;
  }

  void finishPolygon() async {
    if (_activePolygon != null && _activePolygon!.points.length >= 3) {
      final points = _activePolygon!.points;
      final finalizedPolygon = _activePolygon!.copyWith(points: points, strokeColor: currentDrawingColor, fillColor: currentDrawingColor.withValues(alpha: 0.2));
      final index = _polygons.indexWhere((p) => p.id == _activePolygon!.id);
      if (index != -1) _polygons[index] = finalizedPolygon;

      _activePolygon = null;
      _selectedPolygon = finalizedPolygon;

      // Finalize the polyline
      _polylines.removeWhere((p) => p.id == _activePolyline?.id);
      _activePolyline = null;
    }

    // Notify the host app about the drawn polygon(s)
    onPolygonDrawn?.call(_polygons);
    notifyListeners();
  }

  void updatePolygonPoint(String polygonId, int pointIndex, LatLng newPoint) {
    final index = _polygons.indexWhere((p) => p.id == polygonId);
    if (index == -1) return;

    final oldPolygon = _polygons[index];
    final updatedPoints = [...oldPolygon.points];

    if (pointIndex < 0 || pointIndex >= updatedPoints.length) return;

    updatedPoints[pointIndex] = newPoint;

    final updatedPolygon = oldPolygon.copyWith(points: updatedPoints);
    _polygons[index] = updatedPolygon;

    // Update the polyline as well
    final polylineIndex = _polylines.indexWhere((p) => p.id == polygonId);
    if (polylineIndex != -1) {
      _polylines[polylineIndex] = _polylines[polylineIndex].copyWith(points: updatedPoints);
    }

    // Update selected polygon if matched
    if (_selectedPolygon?.id == polygonId) {
      _selectedPolygon = updatedPolygon;
    }

    if (_activePolygon?.id == polygonId) {
      _activePolygon = updatedPolygon;
      final activePolylineIndex = _polylines.indexWhere((p) => p.id == polygonId);
      if (activePolylineIndex != -1) {
        _activePolyline = _polylines[activePolylineIndex];
      }
    }
    notifyListeners();
    onPolygonUpdated?.call(updatedPolygon);
  }

  LatLng midpoint(LatLng p1, LatLng p2) {
    return LatLng((p1.latitude + p2.latitude) / 2, (p1.longitude + p2.longitude) / 2);
  }

  void _updatePolygon(String polygonId, List<LatLng> newPoints) {
    final index = _polygons.indexWhere((p) => p.id == polygonId);
    if (index == -1) return;

    final oldPolygon = _polygons[index];
    final updatedPolygon = oldPolygon.copyWith(points: newPoints);

    _polygons[index] = updatedPolygon;

    // If the selected polygon is being updated, we need to update it as well.
    if (_selectedPolygon?.id == polygonId) {
      _selectedPolygon = updatedPolygon;
    }

    notifyListeners();
  }

  void updateMidpointPosition(String polygonId, int index, LatLng newPosition) {
    final polygon = _selectedPolygon;
    if (polygon == null) return;

    final points = List<LatLng>.from(polygon.points);
    final prevIndex = (index == 0) ? points.length - 1 : index - 1;
    final nextIndex = (index == points.length - 1) ? 0 : index + 1;

    // Current midpoint between prev and next
    final currentMidpoint = LatLng((points[prevIndex].latitude + points[nextIndex].latitude) / 2, (points[prevIndex].longitude + points[nextIndex].longitude) / 2);

    // Calculate delta from current midpoint to new position
    final latDelta = newPosition.latitude - currentMidpoint.latitude;
    final lngDelta = newPosition.longitude - currentMidpoint.longitude;

    // Move both prev and next points slightly toward the new midpoint
    final newPrevPoint = LatLng(points[prevIndex].latitude + latDelta / 2, points[prevIndex].longitude + lngDelta / 2);

    final newNextPoint = LatLng(points[nextIndex].latitude + latDelta / 2, points[nextIndex].longitude + lngDelta / 2);

    points[prevIndex] = newPrevPoint;
    points[nextIndex] = newNextPoint;

    _updatePolygon(polygonId, points);
  }

  void insertMidpointAsVertex(String polygonId, int insertIndex, LatLng newPoint) {
    final index = _polygons.indexWhere((p) => p.id == polygonId);
    if (index == -1) return;

    final polygon = _polygons[index];
    final points = List<LatLng>.from(polygon.points);

    // Insert new point at the correct index
    points.insert(insertIndex, newPoint);

    _updatePolygon(polygonId, points);
  }

  void selectPolygon(String polygonId) {
    if (_selectedPolygon?.id == polygonId) {
      _selectedPolygon = null; // Deselect
    } else {
      _selectedPolygon = _polygons.firstWhereOrNull((p) => p.id == polygonId);
      if (_selectedPolygon != null) {
        onPolygonSelected?.call(_selectedPolygon!);
      }
    }
    notifyListeners();
  }

  Set<Polyline> get mapPolylines {
    return _polylines.map((dp) => dp.toGooglePolyline()).toSet();
  }

  void deselectPolygon() {
    _selectedPolygon = null;
    notifyListeners();
  }

  Set<Polygon> get mapPolygons {
    return _polygons.map((polygon) {
      return Polygon(
        polygonId: PolygonId(polygon.id),
        points: polygon.points,
        fillColor: polygon.fillColor.withOpacity(0.3),
        strokeColor: polygon.strokeColor,
        strokeWidth: polygon.strokeWidth,
        consumeTapEvents: true,
        onTap: () => selectPolygon(polygon.id),
      );
    }).toSet();
  }

  void clearAll() {
    _polygons.clear();
    _activePolygon = null;
    _selectedPolygon = null;
    notifyListeners();
  }

  void deleteSelectedPolygon() {
    if (_selectedPolygon != null) {
      _polygons.removeWhere((p) => p.id == _selectedPolygon!.id);
      _selectedPolygon = null;
      notifyListeners();
      onPolygonDeleted?.call(_selectedPolygon!.id);
    }
  }

  /// Circle Drawing Logic

  /// Callback for when a circle is drawn
  void Function(List<DrawableCircle> allCircles)? onCircleDrawn;

  /// Called when a circle is selected
  void Function(DrawableCircle selected)? onCircleSelected;

  /// Called when a circle is updated (center or radius or color)
  void Function(DrawableCircle updated)? onCircleUpdated;

  /// Called when a circle is deleted
  void Function(String deletedCircleId)? onCircleDeleted;

  late BitmapDescriptor circleCenterMarkerIcon;
  late BitmapDescriptor circleRadiusHandleIcon;

  final List<DrawableCircle> _drawableCircles = [];
  String? _selectedCircleId;
  DrawableCircle? _selectedCircle;

  DrawableCircle? get selectedCircle => _drawableCircles.firstWhereOrNull((c) => c.id == _selectedCircleId);

  void setCircleCenterMarkerIcon(BitmapDescriptor icon) {
    circleCenterMarkerIcon = icon;
    notifyListeners();
  }

  void setCircleRadiusHandleIcon(BitmapDescriptor icon) {
    circleRadiusHandleIcon = icon;
    notifyListeners();
  }

  void selectCircle(String id) {
    _selectedCircleId = id;
    notifyListeners();
    _selectedCircle = _drawableCircles.firstWhereOrNull((p) => p.id == id);
    if (_selectedCircle != null) {
      onCircleSelected?.call(_selectedCircle!);
    }
  }

  Set<Circle> get mapCircles => _drawableCircles.map((e) => e.toCircle(onTap: (pos) => selectCircle(e.id))).toSet();

  void addCircle(LatLng center, double zoom) {
    final id = 'circle_${DateTime.now().millisecondsSinceEpoch}';
    final radius = _initialRadiusFromZoom(zoom);

    final newCircle = DrawableCircle(id: id, center: center, radius: radius, strokeColor: _currentDrawingColor, fillColor: _currentDrawingColor.withValues(alpha: 0.2));
    _drawableCircles.add(newCircle);
    selectCircle(id);
    onCircleDrawn?.call(_drawableCircles);
    notifyListeners();
  }

  double _initialRadiusFromZoom(double zoom) {
    // Approximate radius in meters based on zoom (tweak as needed)
    // Lower zoom → larger radius, higher zoom → smaller radius
    const zoomToRadius = {10: 2000.0, 11: 1500.0, 12: 1000.0, 13: 750.0, 14: 500.0, 15: 250.0, 16: 150.0, 17: 100.0, 18: 75.0, 19: 50.0, 20: 25.0};

    for (final entry in zoomToRadius.entries.toList().reversed) {
      if (zoom >= entry.key) return entry.value;
    }
    return 2000.0; // fallback
  }

  void deselectCircle() {
    _selectedCircleId = null;
    notifyListeners();
  }

  void updateCircleCenter(String id, LatLng newCenter) {
    final index = _drawableCircles.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final updated = _drawableCircles[index].copyWith(center: newCenter);
    _drawableCircles[index] = updated;
    googleMapController?.showMarkerInfoWindow(MarkerId('${id}_radius_handle'));
    notifyListeners();
    onCircleUpdated?.call(updated);
  }

  void updateCircleRadius(String id, LatLng handlePosition) {
    final index = _drawableCircles.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final circle = _drawableCircles[index];
    final newRadius = _calculateDistanceMeters(circle.center, handlePosition);
    final updated = circle.copyWith(radius: newRadius);

    _drawableCircles[index] = updated;
    googleMapController?.showMarkerInfoWindow(MarkerId('${circle.id}_radius_handle'));
    notifyListeners();
    onCircleUpdated?.call(updated);
  }

  double _degreesToRadians(double deg) => deg * (pi / 180);

  /// Place handle due east of center at current radius
  LatLng computeRadiusHandle(LatLng center, double radiusMeters) {
    const double earthRadius = 6371000; // in meters
    final dLat = 0.0;
    final dLng = (radiusMeters / earthRadius) * (180 / pi) / cos(center.latitude * pi / 180);
    return LatLng(center.latitude + dLat, center.longitude + dLng);
  }

  void deleteSelectedCircle() {
    if (_selectedCircleId != null) {
      final deletedId = _selectedCircleId;
      _drawableCircles.removeWhere((c) => c.id == deletedId);
      _selectedCircleId = null;
      notifyListeners();
      if (deletedId != null) {
        onCircleDeleted?.call(deletedId);
      }
    }
  }
}

// File: lib/src/drawing_controller.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:collection/collection.dart';
import 'models/drawable_polygon.dart';
import 'models/drawable_polyline.dart';

enum DrawMode { none, polygon, polyline, circle, rectangle }

typedef OnPolygonDrawn = void Function(DrawablePolygon polygon);

class DrawingController extends ChangeNotifier {

  DrawingController({this.onPolygonDrawn, this.onPolygonSelected, this.onPolygonUpdated, this.onPolygonDeleted, BitmapDescriptor? firstPolygonMarker, BitmapDescriptor? customPolygonMarker, BitmapDescriptor? midpointPolygonMarker,}) {
    // Set default custom icon if none is passed
    firstPolygonMarkerIcon = firstPolygonMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    customPolygonMarkerIcon = customPolygonMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    midpointPolygonMarkerIcon = midpointPolygonMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
  }

  late BitmapDescriptor customPolygonMarkerIcon;
  late BitmapDescriptor firstPolygonMarkerIcon;
  late BitmapDescriptor midpointPolygonMarkerIcon;
  DrawMode _currentMode = DrawMode.none;
  final List<DrawablePolygon> _polygons = [];
  final List<DrawablePolyline> _polylines = [];
  DrawablePolyline? _activePolyline;
  DrawablePolygon? _activePolygon;
  DrawablePolygon? _selectedPolygon;

  /// Callback for when a polygon is drawn
  void Function(List<DrawablePolygon> allPolygons)? onPolygonDrawn;

  /// Called when a polygon is selected
  void Function(DrawablePolygon selected)? onPolygonSelected;

  /// Called when a polygon is updated (points or color)
  void Function(DrawablePolygon updated)? onPolygonUpdated;

  /// Called when a polygon is deleted
  void Function(String deletedPolygonId)? onPolygonDeleted;

  double updatedZoom = 0;

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
    notifyListeners();  // This will trigger the UI update to use the new icon
  }

  void setPolygonCustomMarkerIcon(BitmapDescriptor icon) {
    customPolygonMarkerIcon = icon;
    notifyListeners();  // This will trigger the UI update to use the new icon
  }

  void setColor(Color color) {
    _currentDrawingColor = color;
    notifyListeners();
  }

  void updateColor(String polygonId, Color newColor) {
    final index = _polygons.indexWhere((p) => p.id == polygonId);
    if (index == -1) return;

    final oldPolygon = _polygons[index];
    final updatedPolygon = oldPolygon.copyWith(strokeColor: newColor, fillColor: newColor.withValues(alpha: 0.2));

    _polygons[index] = updatedPolygon;

    if (_selectedPolygon?.id == polygonId) {
      _selectedPolygon = updatedPolygon;
    }

    notifyListeners();
  }

  void setDrawMode(DrawMode mode) {
    _currentMode = mode;
    _activePolygon = null;
    _selectedPolygon = null;
    notifyListeners();
  }

  double _calculateDistanceMeters(LatLng p1, LatLng p2) {
    const R = 6371000; // Radius of Earth in meters
    final lat1 = p1.latitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    final dLat = (p2.latitude - p1.latitude) * pi / 180;
    final dLng = (p2.longitude - p1.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
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
      _activePolygon = DrawablePolygon(
        id: UniqueKey().toString(),
        points: [point],
        strokeColor: Colors.transparent,
      );
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
        _activePolygon = _activePolygon!.copyWith(
          points: [..._activePolygon!.points, firstPoint],
        );
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
    const baseThreshold = 300.0;  // Starting threshold at zoom 0
    final scaleFactor = pow(2, zoom); // 2^zoom scaling factor

    // Dynamically scale the threshold for higher zoom levels, but avoid too small thresholds
    final threshold = baseThreshold / scaleFactor;

    // Prevent threshold from being too small at high zoom levels
    // Cap the threshold between 1 meter and 300 meters for reasonable behavior
    return threshold < 1.0 ? 1.0 : threshold > 300.0 ? 300.0 : threshold;
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
      final finalizedPolygon = _activePolygon!.copyWith(
        points: points,
        strokeColor: currentDrawingColor,
        fillColor: currentDrawingColor.withValues(alpha: 0.2),
      );
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

    _currentMode = DrawMode.none;
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
    return LatLng(
      (p1.latitude + p2.latitude) / 2,
      (p1.longitude + p2.longitude) / 2,
    );
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
    final polygonIndex = _polygons.indexWhere((p) => p.id == polygonId);
    if (polygonIndex == -1) return;

    final polygon = _polygons[polygonIndex];
    final points = [...polygon.points];

    // Insert the new midpoint between the two points at the given index and index + 1
    // If the polygon is closed, index + 1 wraps around
    final isClosed = points.first == points.last;
    final nextIndex = (index + 1) % points.length;

    // Only allow insertion if valid index
    if (index < 0 || nextIndex >= points.length) return;

    points.insert(nextIndex, newPosition);

    // Update the polygon with the new point inserted
    final updatedPolygon = polygon.copyWith(points: points);
    _polygons[polygonIndex] = updatedPolygon;

    // Update polyline if exists
    final polylineIndex = _polylines.indexWhere((p) => p.id == polygonId);
    if (polylineIndex != -1) {
      _polylines[polylineIndex] = _polylines[polylineIndex].copyWith(points: points);
    }

    if (_selectedPolygon?.id == polygonId) {
      _selectedPolygon = updatedPolygon;
    }

    notifyListeners();
    onPolygonUpdated?.call(updatedPolygon);
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
      if(_selectedPolygon != null) {
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
}
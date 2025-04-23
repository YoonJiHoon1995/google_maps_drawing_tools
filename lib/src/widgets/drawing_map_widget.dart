// File: lib/src/widgets/drawing_map_widget.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../drawing_controller.dart';

class DrawingMapWidget extends StatefulWidget {
  final CameraPosition initialCameraPosition;
  final DrawingController controller;
  final MapCreatedCallback? onMapCreated;
  final Set<Polygon>? polygons;
  final Set<Polyline>? polylines;
  final Set<Marker>? markers;
  final Set<Circle>? circles;
  final void Function(LatLng)? onTap;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool? compassEnabled;
  final MapType? mapType;
  final bool? trafficEnabled;
  final bool? rotateGesturesEnabled;
  final bool? tiltGesturesEnabled;
  final bool? zoomGesturesEnabled;
  final bool? scrollGesturesEnabled;
  final bool? zoomControlsEnabled;
  final bool? indoorViewEnabled;
  final bool? buildingsEnabled;
  final void Function(CameraPosition)? onCameraMove;
  final CameraTargetBounds? cameraTargetBounds;
  final MinMaxZoomPreference? minMaxZoomPreference;
  final Set<TileOverlay>? tileOverlays;
  final EdgeInsets padding;
  final bool mapToolbarEnabled;
  final void Function(LatLng)? onLongPress;
  final String? style;
  final String? cloudMapId;
  final Set<ClusterManager> clusterManagers;
  final bool fortyFiveDegreeImageryEnabled;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;
  final Set<GroundOverlay> groundOverlays;
  final Set<Heatmap> heatmaps;
  final TextDirection? layoutDirection;
  final bool liteModeEnabled;
  final void Function()? onCameraIdle;
  final void Function()? onCameraMoveStarted;
  final WebGestureHandling? webGestureHandling;

  const DrawingMapWidget({
    super.key,
    required this.initialCameraPosition,
    required this.controller,
    this.onMapCreated,
    this.circles,
    this.polygons,
    this.polylines,
    this.markers,
    this.onTap,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = true,
    this.compassEnabled,
    this.mapType,
    this.trafficEnabled,
    this.rotateGesturesEnabled,
    this.tiltGesturesEnabled,
    this.zoomGesturesEnabled,
    this.scrollGesturesEnabled,
    this.zoomControlsEnabled,
    this.indoorViewEnabled,
    this.buildingsEnabled,
    this.onCameraMove,
    this.cameraTargetBounds,
    this.minMaxZoomPreference,
    this.tileOverlays,
    this.padding = EdgeInsets.zero,
    this.mapToolbarEnabled = true,
    this.onLongPress,
    this.style,
    this.cloudMapId,
    this.clusterManagers = const <ClusterManager>{},
    this.fortyFiveDegreeImageryEnabled = false,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
    this.groundOverlays = const <GroundOverlay>{},
    this.heatmaps = const <Heatmap>{},
    this.layoutDirection,
    this.liteModeEnabled = false,
    this.onCameraIdle,
    this.onCameraMoveStarted,
    this.webGestureHandling,
  });

  @override
  State<DrawingMapWidget> createState() => _DrawingMapWidgetState();
}

class _DrawingMapWidgetState extends State<DrawingMapWidget> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  void _onMapTap(LatLng position) {
    if (widget.controller.currentMode == DrawMode.polygon) {
      widget.controller.addPolygonPoint(position);
    } else {
      widget.controller.deselectPolygon();
    }
  }

  Set<Marker> _buildEditingMarkers() {
    final selected = widget.controller.selectedPolygon;

    // Show markers only when in polygon mode and a polygon is selected
    if (widget.controller.currentMode != DrawMode.polygon || selected == null) {
      return {};
    }

    final points = selected.points;

    final isClosed = points.length > 2 &&
        widget.controller.isNearPoint(
          points.first,
          points.last,
          widget.controller.updatedZoom,
        );

    final uniquePoints = isClosed ? points.sublist(0, points.length - 1) : points;

    final editingMarkers = <Marker>{};

    // Vertex markers
    for (int i = 0; i < uniquePoints.length; i++) {
      final point = uniquePoints[i];

      final isFirst = i == 0;
      final isDrawing = widget.controller.activePolygonId != null;
      final hasEnoughPoints = uniquePoints.length > 2;

      editingMarkers.add(
        Marker(
          markerId: MarkerId('${selected.id}_marker_$i'),
          position: point,
          draggable: true,
          icon: isFirst
              ? widget.controller.firstPolygonMarkerIcon
              : widget.controller.customPolygonMarkerIcon,  // Use custom marker icon
          onDragEnd: (newPosition) {
            widget.controller.updatePolygonPoint(selected.id, i, newPosition);
          },
          onTap: () {
            // Finish polygon if user taps on the first marker while drawing
            if (isFirst && isDrawing && hasEnoughPoints) {
              widget.controller.finishPolygon();
            }
          },
        ),
      );
    }

    // Midpoint markers — show ONLY if polygon is selected AND drawing is finished
    final shouldShowMidpoints =
        widget.controller.currentMode == DrawMode.polygon &&
            widget.controller.selectedPolygon != null &&
            widget.controller.activePolygonId == null;

    if (shouldShowMidpoints) {
      for (int i = 0; i < uniquePoints.length; i++) {
        final p1 = uniquePoints[i];
        final p2 = uniquePoints[(i + 1) % uniquePoints.length]; // Wrap around
        final mid = widget.controller.midpoint(p1, p2);

        editingMarkers.add(
          Marker(
            markerId: MarkerId('${selected.id}_midpoint_$i'),
            position: mid,
            draggable: true,
            onDragEnd: (newPosition) {
              widget.controller.insertMidpointAsVertex(selected.id, i + 1, newPosition);
            },
            icon: widget.controller.midpointPolygonMarkerIcon,
          ),
        );
      }
    }

    // Optionally: show a hint marker if user is near the first point during drawing
    final isDrawing = widget.controller.activePolygonId != null;
    final hasEnoughPoints = uniquePoints.length > 2;

    if (isDrawing && hasEnoughPoints) {
      final firstPoint = uniquePoints.first;
      final currentCursor = widget.controller.currentCursorPosition;

      if (currentCursor != null &&
          widget.controller.isNear(firstPoint, currentCursor, thresholdInMeters: 15)) {
        // This could be used to show a visual hint marker for snapping
        editingMarkers.add(
          Marker(
            markerId: MarkerId('${selected.id}_snap_hint'),
            position: firstPoint,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onTap: () {
              widget.controller.finishPolygon(); // Tap on snap hint also finishes
            },
          ),
        );
      }
    }

    return editingMarkers;
  }




  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return GoogleMap(
          key: widget.key,
          initialCameraPosition: widget.initialCameraPosition,
          onMapCreated: widget.onMapCreated,
          polygons: {...?widget.polygons, ...widget.controller.mapPolygons},
          polylines: {...?widget.polylines, ...widget.controller.mapPolylines},
          markers: {...?widget.markers, ..._buildEditingMarkers()},
          onTap: (latLng) {
            _onMapTap(latLng);
            if(widget.onTap != null) {
              widget.onTap!(latLng);
            }
          },
          myLocationEnabled: widget.myLocationEnabled,
          myLocationButtonEnabled: widget.myLocationButtonEnabled,
          onCameraMove: (position) {
            if(widget.onCameraMove != null) {
              widget.onCameraMove!(position);
            }
            widget.controller.updatedZoom = position.zoom;
          },
          // Forward props
          circles: widget.circles ?? const {},
          compassEnabled: widget.compassEnabled ?? true,
          mapType: widget.mapType ?? MapType.normal,
          trafficEnabled: widget.trafficEnabled ?? false,
          rotateGesturesEnabled: widget.rotateGesturesEnabled ?? true,
          tiltGesturesEnabled: widget.tiltGesturesEnabled ?? true,
          zoomGesturesEnabled: widget.zoomGesturesEnabled ?? true,
          scrollGesturesEnabled: widget.scrollGesturesEnabled ?? true,
          zoomControlsEnabled: widget.zoomControlsEnabled ?? true,
          indoorViewEnabled: widget.indoorViewEnabled ?? false,
          buildingsEnabled: widget.buildingsEnabled ?? true,
          cameraTargetBounds: widget.cameraTargetBounds ?? CameraTargetBounds.unbounded,
          minMaxZoomPreference: widget.minMaxZoomPreference ?? MinMaxZoomPreference.unbounded,
          tileOverlays: widget.tileOverlays ?? const {},
          padding: widget.padding,
          mapToolbarEnabled: widget.mapToolbarEnabled,
          onLongPress: widget.onLongPress,
          style: widget.style,
          cloudMapId: widget.cloudMapId,
          clusterManagers: widget.clusterManagers,
          fortyFiveDegreeImageryEnabled: widget.fortyFiveDegreeImageryEnabled,
          gestureRecognizers: widget.gestureRecognizers,
          groundOverlays: widget.groundOverlays,
          heatmaps: widget.heatmaps,
          layoutDirection: widget.layoutDirection,
          liteModeEnabled: widget.liteModeEnabled,
          onCameraIdle: widget.onCameraIdle,
          onCameraMoveStarted: widget.onCameraMoveStarted,
          webGestureHandling: widget.webGestureHandling,
        );
      }
    );
  }
}

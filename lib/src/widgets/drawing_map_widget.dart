// File: lib/src/widgets/drawing_map_widget.dart

import 'dart:io';

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
  void didUpdateWidget(DrawingMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isDrawingRectangle = widget.controller.currentMode == DrawMode.rectangle;
    _isDrawingFreeHand = widget.controller.currentMode == DrawMode.freehand;
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
    switch (widget.controller.currentMode) {
      case DrawMode.polygon:
        if (widget.controller.currentMode == DrawMode.polygon) {
          final isDrawing = widget.controller.activePolygonId != null;

          if (isDrawing) {
            // Currently drawing a polygon
            widget.controller.addPolygonPoint(position);
          } else {
            // Try selecting an existing polygon first
            final wasPolygonSelected =
                widget.controller.selectPolygonAt(position);

            // If no polygon was selected, start new polygon
            if (!wasPolygonSelected) {
              widget.controller.addPolygonPoint(position);
            }
          }
        }
        break;

      case DrawMode.circle:
        widget.controller.addCircle(position, widget.controller.currentZoom);
        break;

      case DrawMode.rectangle:
        // 1. If we're actively drawing (second tap), finish
        if (_activeDrawingStart != null) {
          widget.controller.finishDrawingRectangle();
          _activeDrawingStart = null;
          return;
        }

        // 2. Otherwise, begin drawing
        _activeDrawingStart = position;
        widget.controller.startDrawingRectangle(position);
        break;

      case DrawMode.freehand:
        // widget.controller.selectFreehandPolygonAt(position);
        break;

      default:
        widget.controller.deselectPolygon();
        widget.controller.deselectCircle();
        widget.controller.deselectRectangle();
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
          widget.controller.currentZoom,
        );

    final uniquePoints =
        isClosed ? points.sublist(0, points.length - 1) : points;

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
                : widget.controller
                    .customPolygonMarkerIcon, // Use custom marker icon
            onDragEnd: (newPosition) {
              widget.controller.updatePolygonPoint(selected.id, i, newPosition);
            },
            onTap: () {
              // Finish polygon if user taps on the first marker while drawing
              if (isFirst && isDrawing && hasEnoughPoints) {
                widget.controller.finishPolygon();
              }
            },
            infoWindow: InfoWindow(
              title: isFirst && isDrawing && hasEnoughPoints
                  ? "탭하여 종료하세요."
                  : "길게 눌러 드래그하세요.",
              onTap: () {
                if (isFirst && isDrawing && hasEnoughPoints) {
                  widget.controller.finishPolygon();
                }
              },
            )),
      );
    }

    if (editingMarkers.length > 2) {
      final markerId = editingMarkers.first.markerId;

      Future.delayed(Duration(milliseconds: 4000), () {
        if (!mounted) return;

        // Try showing the InfoWindow, catching the error if it fails
        widget.controller.googleMapController
            ?.showMarkerInfoWindow(markerId)
            .catchError((e) {
          debugPrint("InfoWindow could not be shown, can be ignored");
        });

        Future.delayed(Duration(milliseconds: 4000), () {
          if (!mounted) return;

          widget.controller.googleMapController
              ?.hideMarkerInfoWindow(markerId)
              .catchError((e) {
            debugPrint("InfoWindow could not be hidden, can be ignored");
          });
        });
      });
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
              widget.controller
                  .insertMidpointAsVertex(selected.id, i + 1, newPosition);
            },
            icon: widget.controller.midpointPolygonMarkerIcon,
            infoWindow:
                InfoWindow(title: '길게 눌러 드래그하세요.'),
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
          widget.controller
              .isNear(firstPoint, currentCursor, thresholdInMeters: 15)) {
        // This could be used to show a visual hint marker for snapping
        editingMarkers.add(
          Marker(
            markerId: MarkerId('${selected.id}_snap_hint'),
            position: firstPoint,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onTap: () {
              widget.controller
                  .finishPolygon(); // Tap on snap hint also finishes
            },
          ),
        );
      }
    }

    return editingMarkers;
  }

  Set<Marker> _buildCircleEditingMarkers() {
    final circle = widget.controller.selectedCircle;
    if (circle == null || widget.controller.currentMode != DrawMode.circle) {
      return {};
    }

    final center = circle.center;
    final handle = widget.controller.computeRadiusHandle(center, circle.radius);

    Set<Marker> markers = {
      // Center marker
      Marker(
        markerId: MarkerId('${circle.id}_center'),
        position: center,
        draggable: true,
        icon: widget.controller.circleCenterMarkerIcon,
        onDragEnd: (newPosition) {
          widget.controller.updateCircleCenter(circle.id, newPosition);
        },
        infoWindow: InfoWindow(
          title: "Circle Center",
          snippet: "Drag to move circle",
        ),
      ),

      // Radius handle
      Marker(
        markerId: MarkerId('${circle.id}_radius_handle'),
        position: handle,
        draggable: true,
        icon: widget.controller.circleRadiusHandleIcon,
        onDrag: (updatedPosition) {
          widget.controller.updateCircleRadius(circle.id, updatedPosition);
        },
        onDragEnd: (newPosition) {
          widget.controller.updateCircleRadius(circle.id, newPosition);
        },
        infoWindow: InfoWindow(
          title: "지름",
          snippet: "${circle.radius.toStringAsFixed(2)} m",
        ),
      ),
    };
    widget.controller.googleMapController
        ?.showMarkerInfoWindow(MarkerId('${circle.id}_radius_handle'));
    return markers;
  }

  bool _isDrawingRectangle = false;
  LatLng? _activeDrawingStart;

  Polygon? get drawingRectanglePolygon {
    final rect = widget.controller.drawingRectangle;
    if (rect == null) return null;

    final sw = rect.bounds.southwest;
    final ne = rect.bounds.northeast;
    final nw = LatLng(ne.latitude, sw.longitude);
    final se = LatLng(sw.latitude, ne.longitude);

    return Polygon(
      polygonId: PolygonId(rect.id),
      points: [sw, se, ne, nw, sw],
      strokeWidth: 2,
      strokeColor: rect.strokeColor,
      fillColor: rect.fillColor,
    );
  }

  Set<Polygon> get allRectanglePolygons {
    return widget.controller.rectangles.map((rect) {
      final sw = rect.bounds.southwest;
      final ne = rect.bounds.northeast;
      final nw = LatLng(ne.latitude, sw.longitude);
      final se = LatLng(sw.latitude, ne.longitude);

      final isSelected = widget.controller.selectedRectangleId == rect.id;

      return Polygon(
        polygonId: PolygonId(rect.id),
        points: [sw, se, ne, nw, sw],
        strokeWidth: isSelected ? 4 : 2,
        strokeColor: rect.strokeColor,
        fillColor: rect.fillColor,
        consumeTapEvents: true,
        onTap: () => widget.controller.selectRectangle(rect.id),
      );
    }).toSet();
  }

  bool _isDrawingFreeHand = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            key: widget.key,
            initialCameraPosition: widget.initialCameraPosition,
            onMapCreated: (controller) {
              widget.controller.googleMapController = controller;
              if (widget.onMapCreated != null) {
                widget.onMapCreated!(controller);
              }
            },
            polygons: {
              ...?widget.polygons,
              ...widget.controller.mapPolygons,
              ...widget.controller.mapFreeHandPolygons,
              ...allRectanglePolygons,
              if (widget.controller.drawingFreehandPolygon != null)
                widget.controller.drawingFreehandPolygon!,
              if (drawingRectanglePolygon != null) drawingRectanglePolygon!,
            },
            polylines: {
              ...?widget.polylines,
              ...widget.controller.mapPolylines
            },
            markers: {
              ...?widget.markers,
              ...widget.controller.rectangleStartMarker != null
                  ? [widget.controller.rectangleStartMarker!]
                  : [],
              ..._buildEditingMarkers(), // polygon
              ..._buildCircleEditingMarkers(), // circle
              ...widget.controller.rectangleEditHandles,
            },
            onTap: (latLng) {
              _onMapTap(latLng);
              if (widget.onTap != null) {
                widget.onTap!(latLng);
              }
            },
            myLocationEnabled: widget.myLocationEnabled,
            myLocationButtonEnabled: widget.myLocationButtonEnabled,
            onCameraMove: (position) {
              if (widget.onCameraMove != null) {
                widget.onCameraMove!(position);
              }
              widget.controller.currentZoom = position.zoom;
            },
            // Forward props
            circles: {
              ...?widget.circles,
              ...widget.controller.mapCircles,
            },
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
            cameraTargetBounds:
                widget.cameraTargetBounds ?? CameraTargetBounds.unbounded,
            minMaxZoomPreference:
                widget.minMaxZoomPreference ?? MinMaxZoomPreference.unbounded,
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
            webGestureHandling: widget.controller.onPanStarted ||
                    widget.controller.rectangleStarted
                ? WebGestureHandling.none
                : widget.webGestureHandling,
          ),
        ),
        // if(_isDrawingFreeHand || (_isDrawingRectangle && widget.controller.rectangleStarted))
        Positioned.fill(
          child: GestureDetector(
            onPanStart: _isDrawingFreeHand
                ? (details) async {
                    widget.controller.onPanStarted = true;
                    widget.controller.onPanEnded = false;
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final localOffset =
                          box.globalToLocal(details.globalPosition);
                      double pixelRatio =
                          MediaQuery.of(context).devicePixelRatio;
                      if (kIsWeb || Platform.isIOS) {
                        pixelRatio = 1;
                      }
                      final screenCoordinate = ScreenCoordinate(
                        x: (localOffset.dx * pixelRatio).round(),
                        y: (localOffset.dy * pixelRatio).round(),
                      );
                      final latLng = await widget
                          .controller.googleMapController!
                          .getLatLng(screenCoordinate);
                      widget.controller.startFreehandDrawing();
                      widget.controller.addFreehandPoint(latLng);
                    }
                  }
                : null,
            onPanUpdate: _isDrawingRectangle &&
                    widget.controller.selectedRectangle == null
                ? (details) async {
                    if (_activeDrawingStart != null &&
                        widget.controller.googleMapController != null) {
                      // Get RenderBox from context
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final localOffset =
                            box.globalToLocal(details.globalPosition);
                        double pixelRatio =
                            MediaQuery.of(context).devicePixelRatio;
                        if (kIsWeb || Platform.isIOS) {
                          pixelRatio = 1;
                        }
                        final screenCoordinate = ScreenCoordinate(
                          x: (localOffset.dx * pixelRatio).round(),
                          y: (localOffset.dy * pixelRatio).round(),
                        );
                        final newLatLng = await widget
                            .controller.googleMapController!
                            .getLatLng(screenCoordinate);
                        widget.controller.updateDrawingRectangle(newLatLng);
                      }
                    }
                  }
                : (_isDrawingFreeHand
                    ? (details) async {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box != null) {
                          final localOffset =
                              box.globalToLocal(details.globalPosition);
                          double pixelRatio =
                              MediaQuery.of(context).devicePixelRatio;
                          if (kIsWeb || Platform.isIOS) {
                            pixelRatio = 1;
                          }
                          final screenCoordinate = ScreenCoordinate(
                            x: (localOffset.dx * pixelRatio).round(),
                            y: (localOffset.dy * pixelRatio).round(),
                          );
                          final latLng = await widget
                              .controller.googleMapController!
                              .getLatLng(screenCoordinate);
                          widget.controller.addFreehandPoint(latLng);
                        }
                      }
                    : null),
            onPanEnd: _isDrawingFreeHand
                ? (details) {
                    widget.controller.onPanStarted = false;
                    widget.controller.onPanEnded = true;
                    widget.controller.finishFreehandDrawing();
                  }
                : null,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

// Inside your main screen (where you use DrawingMapWidget)

import 'package:flutter/material.dart';
import 'package:google_maps_drawing_tools/google_maps_drawing_tools.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart'; // Your package

class MapDrawingScreen extends StatefulWidget {
  const MapDrawingScreen({super.key});

  @override
  State<MapDrawingScreen> createState() => _MapDrawingScreenState();
}

class _MapDrawingScreenState extends State<MapDrawingScreen> {
  final DrawingController _drawingController = DrawingController(
    onPolygonDrawn: (allPolygons) {
      print("All polygons drawn: ${allPolygons.map((polygon) => polygon.id).join(", ")}");
    },
    onPolygonSelected: (polygon) {
      print("Selected polygon: ${polygon.id}");
    },
    onPolygonUpdated: (polygon) {
      print("Updated polygon: ${polygon.id}");
    },
    onPolygonDeleted: (polygonId) {
      print("Deleted polygon: $polygonId");
    },
  );

  @override
  void initState() {
    super.initState();

    // Set a custom marker icon
    _drawingController.setPolygonCustomMarkerIcon(BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed));

    // Handle the drawn polygons
    _drawingController.onPolygonDrawn = (allPolygons) {
      setState(() {
        // Handle the drawn polygons list
        print("All drawn polygons: ${allPolygons.map((polygon) => polygon.id).join(", ")}");
      });
    };
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          DrawingMapWidget(
            initialCameraPosition: CameraPosition(
              target: LatLng(37.7749, -122.4194),
              zoom: 14,
            ),
            controller: _drawingController,
            webGestureHandling: WebGestureHandling.cooperative,
          ),
          Positioned(
            bottom: 320,
            right: 20,
            child: PointerInterceptor(
              child: FloatingActionButton(
                onPressed: () {
                  if(_drawingController.currentMode == DrawMode.polygon) {
                    _drawingController.deleteSelectedPolygon();
                  } else if(_drawingController.currentMode == DrawMode.circle) {
                    _drawingController.deleteSelectedCircle();
                  } else if(_drawingController.currentMode == DrawMode.rectangle) {
                    _drawingController.deleteSelectedRectangle();
                  } else if(_drawingController.currentMode == DrawMode.freehand) {
                    _drawingController.deleteSelectedFreehandPolygon();
                  }
                },
                tooltip: 'Delete',
                child: const Icon(Icons.delete_forever),
              ),
            ),
          ),
          Positioned(
            bottom: 260,
            right: 20,
            child: PointerInterceptor(
              child: FloatingActionButton(
                onPressed: () => _drawingController.setDrawMode(DrawMode.freehand),
                tooltip: 'Draw Freehand',
                child: Icon(_drawingController.currentMode == DrawMode.freehand ? Icons.shape_line : Icons.shape_line_outlined),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            right: 20,
            child: PointerInterceptor(
              child: FloatingActionButton(
                onPressed: () => _drawingController.setDrawMode(DrawMode.polygon),
                tooltip: 'Draw Polygon',
                child: Icon(_drawingController.currentMode == DrawMode.polygon ? Icons.pentagon : Icons.pentagon_outlined),
              ),
            ),
          ),
          Positioned(
            bottom: 140,
            right: 20,
            child: PointerInterceptor(
              child: FloatingActionButton(
                onPressed: () => _drawingController.setDrawMode(DrawMode.rectangle),
                tooltip: 'Draw Rectangle',
                child: Icon(_drawingController.currentMode == DrawMode.rectangle ? Icons.rectangle : Icons.rectangle_outlined),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 20,
            child: PointerInterceptor(
              child: FloatingActionButton(
                onPressed: () => _drawingController.setDrawMode(DrawMode.circle),
                tooltip: 'Draw Circle',
                child: Icon(_drawingController.currentMode == DrawMode.circle ? Icons.circle : Icons.circle_outlined),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: PointerInterceptor(
              child: FloatingActionButton(
                onPressed: () {
                  _drawingController.setDrawMode(DrawMode.none);
                },
                tooltip: 'Finish Shape',
                child: const Icon(Icons.check),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

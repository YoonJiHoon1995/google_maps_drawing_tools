🗺️ google_maps_drawing_tools
A powerful Flutter package that adds advanced drawing tools to Google Maps for Flutter. Supports polygon drawing, editing, and snapping with a smooth and customizable UX — perfect for geofencing, region selection, and map-based user interaction features.

🚀 Features
✏️ Draw polygons interactively on the map

🛠️ Edit existing polygons with draggable vertices

🧲 Smart snapping logic for aligning nearby vertices

🎨 Customizable polygon styles (color, stroke, fill)

💥 Clean and modular architecture — easy to integrate

📱 Built for Flutter Google Maps (google_maps_flutter)

📸 Screenshots
Add your GIF or images here — showing polygon drawing, editing, and snapping in action.

📦 Installation
Add the package to your pubspec.yaml:

yaml
Copy
Edit
dependencies:
google_maps_drawing_tools: ^0.0.1
Then run:

bash
Copy
Edit
flutter pub get
🛠️ Usage
1. Initialize the controller
   dart
   Copy
   Edit
   GoogleMapDrawingController drawingController = GoogleMapDrawingController();
2. Wrap your GoogleMap widget
   dart
   Copy
   Edit
   GoogleMapDrawingTools(
   controller: drawingController,
   child: GoogleMap(
   initialCameraPosition: CameraPosition(
   target: LatLng(37.42796133580664, -122.085749655962),
   zoom: 14.4746,
   ),
   onMapCreated: (controller) {
   drawingController.setMapController(controller);
   },
   ),
   )
3. Start drawing
   dart
   Copy
   Edit
   drawingController.startPolygonDrawing();
4. Stop drawing
   dart
   Copy
   Edit
   drawingController.stopDrawing();
5. Get the drawn polygon
   dart
   Copy
   Edit
   List<LatLng> polygonPoints = drawingController.getCurrentPolygonPoints();
6. Edit polygon
   dart
   Copy
   Edit
   drawingController.enablePolygonEditing();
7. Snap settings (optional)
   dart
   Copy
   Edit
   drawingController.setSnappingEnabled(true);
   drawingController.setSnapThreshold(20.0); // pixels
   🧪 Example
   Check out the example app for a full working demo.

🧱 Architecture
🔁 Controller-based design for better state management

✨ Separation of drawing logic, snapping, and editing

🧩 Clean integration with google_maps_flutter

🧑‍💻 Contributing
Pull requests are welcome! If you find a bug or want a feature, feel free to open an issue.

📜 License
MIT License. See the LICENSE file for details.
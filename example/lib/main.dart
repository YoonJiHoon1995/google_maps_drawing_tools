// ignore_for_file: unused_import

import 'package:example/src/map_drawing_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_drawing_tools/google_maps_drawing_tools.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Maps Drawing Tools Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MapDrawingScreen(),
    );
  }
}

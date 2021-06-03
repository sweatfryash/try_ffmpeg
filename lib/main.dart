import 'package:flutter/material.dart';
import 'package:try_ffmpeg/home_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TO GIF',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark
        //scaffoldBackgroundColor: Color(0xffe0e0e0)
      ),
      home: HomePage(),
    );
  }
}

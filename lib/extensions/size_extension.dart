import 'package:flutter/material.dart';

extension SizeExtension on Size {
  String toFixedString(){
    return '${this.width.toInt()}x${this.height.toInt()}';
  }
}
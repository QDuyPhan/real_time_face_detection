import 'dart:io';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

double translateX(
  double x,
  InputImageRotation rotation,
  Size size,
  Size absoluteImageSize,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
      return x * size.width / absoluteImageSize.height;
    case InputImageRotation.rotation270deg:
      return size.width - x * size.width / absoluteImageSize.height;
    case InputImageRotation.rotation180deg:
      return size.width - x * size.width / absoluteImageSize.width;
    default:
      return x * size.width / absoluteImageSize.width;
  }
}

double translateY(
  double y,
  InputImageRotation rotation,
  Size size,
  Size absoluteImageSize,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return y * size.height / absoluteImageSize.width;
    case InputImageRotation.rotation180deg:
      return size.height - y * size.height / absoluteImageSize.height;
    default:
      return y * size.height / absoluteImageSize.height;
  }
}

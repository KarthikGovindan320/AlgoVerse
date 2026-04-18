import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:screenshot/screenshot.dart';

/// Handles capturing Flutter widgets as images for sharing.
///
/// Usage:
/// 1. Wrap the widget you want to capture in a [RepaintBoundary] with a [GlobalKey].
/// 2. Call [captureWidget] with that key to get raw bytes.
/// 3. Pass the bytes to [shareBytes] or save to camera roll.
class ShareService {
  static final ShareService _instance = ShareService._();
  factory ShareService() => _instance;
  ShareService._();

  final _screenshotController = ScreenshotController();

  /// Captures a widget subtree identified by [key] at [pixelRatio] resolution.
  /// Returns raw PNG bytes, or null if the capture fails.
  Future<Uint8List?> captureWidget(GlobalKey key,
      {double pixelRatio = 3.0}) async {
    try {
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Captures a Flutter widget built off-screen using [ScreenshotController].
  /// Useful for share cards that aren't currently visible on screen.
  Future<Uint8List?> captureOffscreen(
    Widget widget, {
    double pixelRatio = 3.0,
    Size? size,
  }) async {
    try {
      return await _screenshotController.captureFromWidget(
        widget,
        pixelRatio: pixelRatio,
        targetSize: size,
      );
    } catch (_) {
      return null;
    }
  }
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Chumpy-style wallpaper palette: weighted hue histogram over a heavily
/// downscaled image; the top-3 well-separated hue buckets become accent
/// seeds ("Wallpaper 1/2/3").
abstract final class WallpaperPalette {
  static Future<List<Color>> extract(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 96);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      final bins = List<double>.filled(24, 0);
      if (data != null) {
        final px = data.buffer.asUint8List();
        final stride = image.width * 4;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final o = y * stride + x * 4;
            final a = px[o + 3];
            if (a < 32) continue;
            final c = Color.fromARGB(a, px[o], px[o + 1], px[o + 2]);
            final hsl = HSLColor.fromColor(c);
            if (hsl.saturation < 0.2) continue;
            final l = hsl.lightness;
            if (l < 0.15 || l > 0.85) continue;
            final weight = hsl.saturation * (1 - (l - 0.5).abs() * 2);
            if (weight <= 0) continue;
            bins[(hsl.hue / 15).floor() % 24] += weight;
          }
        }
      }
      image.dispose();
      final order = List.generate(24, (i) => i)
        ..sort((a, b) => bins[b].compareTo(bins[a]));
      final picked = <int>[];
      for (final b in order) {
        if (bins[b] <= 0) break;
        final far = picked.every((p) {
          final d = (p - b).abs();
          return d >= 3 && d <= 21;
        });
        if (far) picked.add(b);
        if (picked.length == 3) break;
      }
      return [
        for (final b in picked)
          HSLColor.fromAHSL(1, b * 15 + 7.5, 0.62, 0.5).toColor(),
      ];
    } catch (_) {
      return const [];
    }
  }
}

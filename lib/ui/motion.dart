import 'package:flutter/material.dart';

abstract final class WayMotion {
  static const Duration fast = Duration(milliseconds: 220);

  static const Duration medium = Duration(milliseconds: 320);

  static const Duration slow = Duration(milliseconds: 540);

  static const Duration spring = Duration(milliseconds: 560);

  static const Curve emphasized = Easing.emphasizedDecelerate;

  static const Curve emphasizedIn = Easing.emphasizedAccelerate;

  static const Curve springy = Curves.easeOutBack;

  static const Curve elastic = Curves.elasticOut;

  static const Curve morph = Easing.emphasizedDecelerate;

  static final SpringDescription springDesc =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.68,
  );

  static final SpringDescription softSpring =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 260,
    ratio: 0.72,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Unified Material 3 Expressive motion tokens for the whole app.
///
/// Every animated transition (nav shell, connect button morph, entrances,
/// squish feedback, sheet/dialog fades) should pull its duration and curve
/// from here so the app moves as one coherent system.
abstract final class WayMotion {
  // --- durations ---
  /// Micro-feedback: press squish, icon crossfades.
  static const Duration fast = Duration(milliseconds: 220);

  /// Standard screen/surface transitions.
  static const Duration medium = Duration(milliseconds: 320);

  /// Large expressive moves: shape morphs, entrance staggers.
  static const Duration slow = Duration(milliseconds: 540);

  /// Spring settle used by the nav pill and button bounce.
  static const Duration spring = Duration(milliseconds: 560);

  // --- curves ---
  /// Decelerating emphasized move for things entering the screen.
  static const Curve emphasized = Easing.emphasizedDecelerate;

  /// Accelerating emphasized move for things leaving the screen.
  static const Curve emphasizedIn = Easing.emphasizedAccelerate;

  /// Slight overshoot for playful pops (chips, badges, tiles).
  static const Curve springy = Curves.easeOutBack;

  /// Long elastic settle reserved for the big connect button.
  static const Curve elastic = Curves.elasticOut;

  /// Expressive spatial curve for shape morphs (circle → shield).
  static const Curve morph = Easing.emphasizedDecelerate;

  // --- springs ---
  /// Default spring for simulation-driven widgets (nav pill).
  static final SpringDescription springDesc = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.68,
  );

  /// Softer spring for larger surfaces.
  static final SpringDescription softSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 260,
    ratio: 0.72,
  );
}

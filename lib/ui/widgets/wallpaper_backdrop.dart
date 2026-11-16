import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/vpn_bridge.dart';
import '../../state/app_state.dart';

class WallpaperBackdrop extends StatelessWidget {
  final double scrim;
  final double blur;

  const WallpaperBackdrop({
    super.key,
    required this.scrim,
    this.blur = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer<AppState>(
      builder: (context, state, _) {
        final path = state.wallpaperPath;
        if (path.isEmpty || !File(path).existsSync()) {
          return const SizedBox.shrink();
        }
        var image = Image.file(
          File(path),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          cacheWidth: 1440,
          gaplessPlayback: true,
        );
        final gray = state.grayWhenOff &&
            state.vpn.phase != VpnPhase.connected;
        if (gray) {
          image = ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, 0, //
              0.2126, 0.7152, 0.0722, 0, 0, //
              0.2126, 0.7152, 0.0722, 0, 0, //
              0, 0, 0, 1, 0,
            ]),
            child: image,
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            blur > 0
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: image,
                  )
                : image,
            ColoredBox(
              color: scheme.surface.withValues(alpha: scrim),
            ),
          ],
        );
      },
    );
  }
}

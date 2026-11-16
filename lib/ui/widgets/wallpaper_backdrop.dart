import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        final image = Image.file(
          File(path),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          cacheWidth: 1440,
          gaplessPlayback: true,
        );
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

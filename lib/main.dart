import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/app_state.dart';

void main(List<String> args) {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
    for (final arg in args) {
      if (arg.contains('://')) {
        AppState.launchLink = arg;
        break;
      }
    }
    runApp(
      ChangeNotifierProvider(
        create: (_) {
          final state = AppState();
          state.init();
          return state;
        },
        child: const WayApp(),
      ),
    );
  }, (error, stack) {
    if (kDebugMode) {
      debugPrint('uncaught zone error: $error');
    }
  });
}

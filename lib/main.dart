import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretwork/app.dart';
import 'package:fretwork/bootstrap.dart';
import 'package:fretwork/core/data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final store = await bootstrap();

  runApp(
    ProviderScope(
      overrides: [storeProvider.overrideWithValue(store)],
      child: const FretworkApp(),
    ),
  );
}

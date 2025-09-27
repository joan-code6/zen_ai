import 'package:flutter/material.dart';
export 'src/app.dart';
import 'src/app.dart';
import 'src/state/user_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserPreferences.init();

  runApp(const ZenDesktopApp());
}


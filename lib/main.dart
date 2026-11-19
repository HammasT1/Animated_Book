import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/library_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(AnimatedBookApp(state: AppState(prefs)));
}

class AnimatedBookApp extends StatelessWidget {
  const AnimatedBookApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Animated Book Reader',
          debugShowCheckedModeBanner: false,
          // A single theme rebuilt per paper style; MaterialApp's
          // AnimatedTheme cross-fades between light, sepia and dark.
          theme: buildAppTheme(state.readerTheme),
          home: const BookLibraryScreen(),
        ),
      ),
    );
  }
}

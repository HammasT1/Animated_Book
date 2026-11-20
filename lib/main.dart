import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/book_storage.dart';
import 'data/library_store.dart';
import 'screens/library_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final library = LibraryStore(BookStorage());
  await library.load();
  runApp(AnimatedBookApp(state: AppState(prefs), library: library));
}

class AnimatedBookApp extends StatelessWidget {
  /// [library] defaults to just the bundled books, kept in memory.
  AnimatedBookApp({super.key, required this.state, LibraryStore? library})
    : library = library ?? LibraryStore.inMemory();

  final AppState state;
  final LibraryStore library;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: LibraryScope(
        library: library,
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
      ),
    );
  }
}

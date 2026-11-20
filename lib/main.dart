import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/book_storage.dart';
import 'data/library_store.dart';
import 'feedback/page_turn_feedback.dart';
import 'screens/library_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final library = LibraryStore(BookStorage());
  await library.load();
  runApp(
    AnimatedBookApp(
      state: AppState(prefs),
      library: library,
      feedback: DevicePageTurnFeedback(),
    ),
  );
}

class AnimatedBookApp extends StatelessWidget {
  /// [library] defaults to just the bundled books, kept in memory, and
  /// [feedback] to silence (as in tests); `main` passes the real ones.
  AnimatedBookApp({
    super.key,
    required this.state,
    LibraryStore? library,
    this.feedback = const PageTurnFeedback(),
  }) : library = library ?? LibraryStore.inMemory();

  final AppState state;
  final LibraryStore library;
  final PageTurnFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: LibraryScope(
        library: library,
        child: PageTurnFeedbackScope(
          feedback: feedback,
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
      ),
    );
  }
}

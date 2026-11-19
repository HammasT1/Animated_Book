import 'package:animated_book/data/library.dart';
import 'package:animated_book/main.dart';
import 'package:animated_book/state/app_state.dart';
import 'package:animated_book/theme/app_theme.dart';
import 'package:animated_book/widgets/page_flip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _freshState([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return AppState(await SharedPreferences.getInstance());
}

Future<void> _openFirstBook(WidgetTester tester) async {
  await tester.tap(find.byType(Hero).first);
  await tester.pumpAndSettle();
}

void main() {
  final firstBook = kLibrary.first;

  group('Library', () {
    testWidgets('shows the shelf and a start button for a new book', (
      tester,
    ) async {
      await tester.pumpWidget(AnimatedBookApp(state: await _freshState()));

      expect(find.text('My Library'), findsOneWidget);
      expect(find.text(firstBook.title), findsOneWidget);
      expect(find.text('Start reading'), findsOneWidget);
    });

    testWidgets('shows continue progress for a started book', (tester) async {
      final state = await _freshState({'progress.${firstBook.id}': 1});
      await tester.pumpWidget(AnimatedBookApp(state: state));

      expect(
        find.text('Continue · Page 2 of ${firstBook.pages.length}'),
        findsOneWidget,
      );
    });
  });

  group('Reader', () {
    testWidgets('opens on page 1 and turns pages with the buttons', (
      tester,
    ) async {
      final state = await _freshState();
      await tester.pumpWidget(AnimatedBookApp(state: state));
      await _openFirstBook(tester);

      final total = firstBook.pages.length;
      expect(find.text('Page 1 of $total'), findsOneWidget);

      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of $total'), findsOneWidget);
      expect(state.lastPage(firstBook.id), 1);

      await tester.tap(find.byTooltip('Previous page'));
      await tester.pumpAndSettle();
      expect(find.text('Page 1 of $total'), findsOneWidget);
    });

    testWidgets('resumes at the saved page', (tester) async {
      final state = await _freshState({'progress.${firstBook.id}': 1});
      await tester.pumpWidget(AnimatedBookApp(state: state));
      await _openFirstBook(tester);

      expect(
        find.text('Page 2 of ${firstBook.pages.length}'),
        findsOneWidget,
      );
    });

    testWidgets('arrow keys turn pages', (tester) async {
      await tester.pumpWidget(AnimatedBookApp(state: await _freshState()));
      await _openFirstBook(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.textContaining('Page 2 of'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.textContaining('Page 1 of'), findsOneWidget);
    });

    testWidgets('a quick short flick turns the page', (tester) async {
      await tester.pumpWidget(AnimatedBookApp(state: await _freshState()));
      await _openFirstBook(tester);

      // After touch slop this registers as ~40 px: below the 70 px drag
      // threshold, but fast enough to count as a flick.
      await tester.fling(
        find.byType(PageFlipWidget),
        const Offset(-60, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Page 2 of'), findsOneWidget);
    });

    testWidgets('a slow short drag snaps back', (tester) async {
      await tester.pumpWidget(AnimatedBookApp(state: await _freshState()));
      await _openFirstBook(tester);

      await tester.timedDrag(
        find.byType(PageFlipWidget),
        const Offset(-40, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Page 1 of'), findsOneWidget);
    });

    testWidgets('bookmarks are saved to preferences', (tester) async {
      final state = await _freshState();
      await tester.pumpWidget(AnimatedBookApp(state: state));
      await _openFirstBook(tester);

      await tester.tap(find.byTooltip('Bookmark (B)'));
      await tester.pump();
      expect(state.isBookmarked(firstBook.id, 0), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('bookmarks.${firstBook.id}'), ['0']);
    });
  });

  group('AppState persistence', () {
    test('reader settings survive a restart', () async {
      final state = await _freshState();
      state
        ..setReaderTheme(ReaderTheme.sepia)
        ..setFontSize(22)
        ..setLineHeight(2.0)
        ..setFont(ReaderFont.sans)
        ..toggleBookmark('x', 3)
        ..setLastPage('x', 2);

      final reloaded = AppState(await SharedPreferences.getInstance());
      expect(reloaded.readerTheme, ReaderTheme.sepia);
      expect(reloaded.fontSize, 22);
      expect(reloaded.lineHeight, 2.0);
      expect(reloaded.font, ReaderFont.sans);
      expect(reloaded.isBookmarked('x', 3), isTrue);
      expect(reloaded.lastPage('x'), 2);
    });

    test('dark toggle goes from sepia to dark and back to light', () async {
      final state = await _freshState({'reader.theme': 'sepia'});
      state.toggleDark();
      expect(state.readerTheme, ReaderTheme.dark);
      state.toggleDark();
      expect(state.readerTheme, ReaderTheme.light);
    });
  });
}

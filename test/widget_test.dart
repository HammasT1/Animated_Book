import 'dart:convert';

import 'package:animated_book/data/library.dart';
import 'package:animated_book/data/library_store.dart';
import 'package:animated_book/widgets/book_cover.dart';
import 'package:animated_book/feedback/page_turn_feedback.dart';
import 'package:animated_book/main.dart';
import 'package:animated_book/state/app_state.dart';
import 'package:animated_book/theme/app_theme.dart';
import 'package:animated_book/widgets/page_curl.dart';
import 'package:animated_book/widgets/page_flip.dart';
import 'package:animated_book/widgets/spread_flip.dart';
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

final _pageLabel = RegExp(r'^Page (\d+) of (\d+)$');

/// Reads the reader's "Page x of y" label as (x, y).
(int, int) _pageInfo(WidgetTester tester) {
  final label = tester.widget<Text>(find.textContaining(_pageLabel)).data!;
  final match = _pageLabel.firstMatch(label)!;
  return (int.parse(match[1]!), int.parse(match[2]!));
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

    testWidgets('shows continue progress as a percentage', (tester) async {
      final half = firstBook.text.length ~/ 2;
      final state = await _freshState({
        'position.${firstBook.id}': ['0', '$half'],
      });
      await tester.pumpWidget(AnimatedBookApp(state: state));

      final percent = (half / firstBook.text.length * 100).floor();
      expect(find.text('Continue · $percent%'), findsOneWidget);
    });
  });

  group('Reader', () {
    testWidgets('opens on page 1 and turns pages with the buttons', (
      tester,
    ) async {
      final state = await _freshState();
      await tester.pumpWidget(AnimatedBookApp(state: state));
      await _openFirstBook(tester);

      final (page, total) = _pageInfo(tester);
      expect(page, 1);
      expect(total, greaterThan(1));
      expect(state.positionOf(firstBook.id)?.start, 0);

      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(_pageInfo(tester), (2, total));
      expect(state.positionOf(firstBook.id)!.start, greaterThan(0));

      await tester.tap(find.byTooltip('Previous page'));
      await tester.pumpAndSettle();
      expect(_pageInfo(tester), (1, total));
    });

    testWidgets('resumes at the saved position', (tester) async {
      final start = firstBook.sectionStart(firstBook.sections.length - 1);
      final state = await _freshState({
        'position.${firstBook.id}': ['$start', '${start + 1}'],
      });
      await tester.pumpWidget(AnimatedBookApp(state: state));
      await _openFirstBook(tester);

      expect(_pageInfo(tester).$1, greaterThan(1));
      expect(state.positionOf(firstBook.id)!.start, start);
    });

    testWidgets('changing the text size re-paginates and keeps the place', (
      tester,
    ) async {
      final state = await _freshState();
      await tester.pumpWidget(AnimatedBookApp(state: state));
      await _openFirstBook(tester);

      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      final anchor = state.positionOf(firstBook.id)!.start;
      final (_, smallTotal) = _pageInfo(tester);

      state.setFontSize(AppState.maxFontSize);
      await tester.pumpAndSettle();

      final (page, bigTotal) = _pageInfo(tester);
      expect(bigTotal, greaterThan(smallTotal));
      expect(page, greaterThan(1));
      // The anchor survives, and the page on screen still holds it.
      final position = state.positionOf(firstBook.id)!;
      expect(position.start, anchor);
      expect(position.end, greaterThan(anchor));
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
      expect(state.bookmarksFor(firstBook.id), {0});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('marks.${firstBook.id}'), ['0']);

      await tester.tap(find.byTooltip('Remove bookmark (B)'));
      await tester.pump();
      expect(state.bookmarksFor(firstBook.id), isEmpty);
    });
  });

  group('Bookmarks list', () {
    testWidgets('shows an empty state when nothing is bookmarked', (
      tester,
    ) async {
      await tester.pumpWidget(AnimatedBookApp(state: await _freshState()));
      await _openFirstBook(tester);

      await tester.tap(find.byTooltip('Bookmarks (Shift+B)'));
      await tester.pumpAndSettle();
      expect(find.text('No bookmarks yet'), findsOneWidget);
    });

    testWidgets('tapping a bookmark jumps to its page', (tester) async {
      final lastChar = firstBook.text.length - 1;
      final state = await _freshState({
        'marks.${firstBook.id}': ['$lastChar'],
      });
      await tester.pumpWidget(AnimatedBookApp(state: state));
      await _openFirstBook(tester);
      final (_, total) = _pageInfo(tester);

      await tester.tap(find.byTooltip('Bookmarks (Shift+B)'));
      await tester.pumpAndSettle();
      // The last character is on the last page.
      await tester.tap(find.text('Page $total'));
      await tester.pumpAndSettle();

      expect(find.text('No bookmarks yet'), findsNothing);
      expect(_pageInfo(tester), (total, total));
      expect(state.positionOf(firstBook.id)!.end, firstBook.text.length);
    });

    testWidgets('Shift+B opens the list and bookmarks can be removed', (
      tester,
    ) async {
      final lastChar = firstBook.text.length - 1;
      final state = await _freshState({
        'marks.${firstBook.id}': ['0', '$lastChar'],
      });
      await tester.pumpWidget(AnimatedBookApp(state: state));
      await _openFirstBook(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      final (_, total) = _pageInfo(tester);
      expect(find.text('Page 1 · You are here'), findsOneWidget);
      expect(find.text('Page $total'), findsOneWidget);
      // Shift+B must not also toggle the current page's bookmark.
      expect(state.bookmarksFor(firstBook.id), contains(0));

      await tester.tap(find.byTooltip('Remove bookmark').last);
      await tester.pumpAndSettle();
      expect(find.text('Page $total'), findsNothing);
      expect(state.bookmarksFor(firstBook.id), {0});
    });
  });

  group('Page turn', () {
    final curlPainter = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is PageCurlPainter,
    );

    Future<void> startTurn(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Next page'));
      await tester.pump(); // the animation clock starts on this frame
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('curls the page by default', (tester) async {
      final state = await _freshState();
      expect(state.turnStyle, PageTurnStyle.curl);
      await tester.pumpWidget(AnimatedBookApp(state: state));
      await _openFirstBook(tester);

      expect(curlPainter, findsNothing);
      await startTurn(tester);
      expect(curlPainter, findsOneWidget);

      await tester.pumpAndSettle();
      expect(curlPainter, findsNothing);
      expect(_pageInfo(tester).$1, 2);
    });

    testWidgets('can be switched to the flip in reading settings', (
      tester,
    ) async {
      final state = await _freshState();
      await tester.pumpWidget(AnimatedBookApp(state: state));
      await _openFirstBook(tester);

      await tester.tap(find.byTooltip('Reading settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flip'));
      await tester.pumpAndSettle();
      expect(state.turnStyle, PageTurnStyle.flip);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reader.turnStyle'), 'flip');

      await tester.tapAt(const Offset(10, 10)); // close the sheet
      await tester.pumpAndSettle();
      await startTurn(tester);
      expect(curlPainter, findsNothing);
      await tester.pumpAndSettle();
      expect(_pageInfo(tester).$1, 2);
    });
  });

  group('Imported books', () {
    Uint8List txt(String s) => Uint8List.fromList(utf8.encode(s));

    Future<void> showLastBook(WidgetTester tester) async {
      for (var i = 0; i < kLibrary.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('appear on the shelf, open, and can be removed', (
      tester,
    ) async {
      final state = await _freshState();
      final library = LibraryStore.inMemory();
      final (book, _) = await library.importFile(
        'a_short_tale.txt',
        txt('Once upon a time.\n\nThe end.'),
      );
      await tester.pumpWidget(AnimatedBookApp(state: state, library: library));
      await showLastBook(tester);

      // No cover in a .txt file, so a cover is generated with the title.
      expect(find.byType(GeneratedCover), findsWidgets);
      expect(find.text('a short tale'), findsWidgets);
      expect(find.text('Remove from library'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_pageInfo(tester), (1, 1));
      expect(state.positionOf(book.id), isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      // Below the shelf; scroll it into view first.
      await tester.ensureVisible(find.text('Remove from library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from library'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(library.books, kLibrary);
      expect(state.positionOf(book.id), isNull);
      expect(find.text('Removed "a short tale"'), findsOneWidget);
    });

    testWidgets('a long book shows page numbers once paginated', (
      tester,
    ) async {
      final library = LibraryStore.inMemory();
      final chapter = List.filled(
        60,
        'A long paragraph of prose that goes on for a while, much like the '
        'chapters of a real novel tend to do when the author is in the mood.',
      ).join('\n\n');
      final file = [
        for (var i = 1; i <= 12; i++) 'CHAPTER $i\n\n$chapter',
      ].join('\n\n');
      await library.importFile('long.txt', txt(file));
      expect(library.books.last.text.length, greaterThan(40000));

      await tester.pumpWidget(
        AnimatedBookApp(state: await _freshState(), library: library),
      );
      await showLastBook(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      // Only the first chapter is paginated straight away; until the rest
      // are, the reader shows how far through the book it is.
      expect(find.textContaining(_pageLabel), findsNothing);
      expect(find.textContaining(RegExp(r'^\d+%$')), findsOneWidget);

      // The remaining chapters are paginated a frame interval at a time.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final (page, total) = _pageInfo(tester);
      expect(page, 1);
      expect(total, greaterThan(12)); // at least a page per chapter

      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(_pageInfo(tester), (2, total));
    });
  });

  group('Two-page spread', () {
    Future<AppState> openWide(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Large text, so the book runs to several spreads.
      final state = await _freshState({'reader.fontSize': 28.0});
      await tester.pumpWidget(AnimatedBookApp(state: state));
      await _openFirstBook(tester);
      return state;
    }

    final spreadLabel = RegExp(r'^Pages (\d+)\u2013(\d+) of (\d+)$');

    testWidgets('shows two pages when the window is wide', (tester) async {
      final state = await openWide(tester);
      expect(find.byType(SpreadFlipWidget), findsOneWidget);
      expect(find.byType(PageFlipWidget), findsNothing);
      final label = tester.widget<Text>(find.textContaining(spreadLabel)).data!;
      final total = int.parse(spreadLabel.firstMatch(label)![3]!);
      expect(label, 'Pages 1\u20132 of $total');
      expect(total, greaterThan(2));

      // A turn moves a whole spread.
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(RegExp('^Pages? 3(\u20134)? of $total\$')),
        findsOneWidget,
      );
      // Progress counts both pages on screen.
      final position = state.positionOf(firstBook.id)!;
      expect(position.end, greaterThan(position.start));

      await tester.tap(find.byTooltip('Previous page'));
      await tester.pumpAndSettle();
      expect(find.text('Pages 1\u20132 of $total'), findsOneWidget);
    });

    testWidgets('a bookmark covers the spread on screen', (tester) async {
      final state = await openWide(tester);
      await tester.tap(find.byTooltip('Bookmark (B)'));
      await tester.pump();
      expect(state.bookmarksFor(firstBook.id), {0});
      expect(find.byTooltip('Remove bookmark (B)'), findsOneWidget);
    });

    testWidgets('narrowing the window goes back to one page, same place', (
      tester,
    ) async {
      final state = await openWide(tester);
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      final anchor = state.positionOf(firstBook.id)!.start;
      expect(anchor, greaterThan(0));

      tester.view.physicalSize = const Size(700, 900);
      await tester.pumpAndSettle();
      expect(find.byType(PageFlipWidget), findsOneWidget);
      expect(find.byType(SpreadFlipWidget), findsNothing);
      expect(state.positionOf(firstBook.id)!.start, anchor);
    });
  });

  group('Page-turn sound and haptics', () {
    Future<(AppState, _RecordingFeedback)> open(WidgetTester tester) async {
      final state = await _freshState();
      final feedback = _RecordingFeedback();
      await tester.pumpWidget(
        AnimatedBookApp(state: state, feedback: feedback),
      );
      await _openFirstBook(tester);
      return (state, feedback);
    }

    testWidgets('a turn plays the sound, then taps as the page lands', (
      tester,
    ) async {
      final (_, feedback) = await open(tester);
      await tester.tap(find.byTooltip('Next page'));
      await tester.pump();
      expect(feedback.sounds, 1);
      expect(feedback.taps, 0); // not until the page lands
      await tester.pumpAndSettle();
      expect(feedback.taps, 1);
    });

    testWidgets('a drag that snaps back is silent', (tester) async {
      final (_, feedback) = await open(tester);
      await tester.timedDrag(
        find.byType(PageFlipWidget),
        const Offset(-40, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(feedback.sounds, 0);
      expect(feedback.taps, 0);
    });

    testWidgets('both can be switched off in reading settings', (tester) async {
      final (state, feedback) = await open(tester);
      expect(state.turnSound, isTrue);
      expect(state.haptics, isTrue);

      await tester.tap(find.byTooltip('Reading settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Page-turn sound'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vibrate when a page lands'));
      await tester.pumpAndSettle();
      expect(state.turnSound, isFalse);
      expect(state.haptics, isFalse);

      await tester.tapAt(const Offset(10, 10)); // close the sheet
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(_pageInfo(tester).$1, 2);
      expect(feedback.sounds, 0);
      expect(feedback.taps, 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('reader.turnSound'), isFalse);
      expect(prefs.getBool('reader.haptics'), isFalse);
      final reloaded = AppState(prefs);
      expect(reloaded.turnSound, isFalse);
      expect(reloaded.haptics, isFalse);
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
        ..toggleBookmark('x', 3, 10)
        ..setPosition('x', const ReadingPosition(2, 9));

      final reloaded = AppState(await SharedPreferences.getInstance());
      expect(reloaded.readerTheme, ReaderTheme.sepia);
      expect(reloaded.fontSize, 22);
      expect(reloaded.lineHeight, 2.0);
      expect(reloaded.font, ReaderFont.sans);
      expect(reloaded.bookmarksFor('x'), {3});
      expect(reloaded.positionOf('x'), const ReadingPosition(2, 9));
    });

    test('page numbers saved by older versions become offsets', () async {
      final state = await _freshState({
        'progress.${firstBook.id}': 1,
        'bookmarks.${firstBook.id}': ['0', '2', '99'],
      });

      final s1 = firstBook.sectionStart(1);
      expect(
        state.positionOf(firstBook.id),
        ReadingPosition(s1, s1 + firstBook.sections[1].length),
      );
      // Out-of-range page 99 is dropped.
      expect(state.bookmarksFor(firstBook.id), {0, firstBook.sectionStart(2)});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('progress.${firstBook.id}'), isFalse);
      expect(prefs.containsKey('bookmarks.${firstBook.id}'), isFalse);
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

/// Counts page-turn feedback instead of playing it.
class _RecordingFeedback extends PageTurnFeedback {
  int sounds = 0;
  int taps = 0;

  @override
  void turnStarted() => sounds++;

  @override
  void turnLanded() => taps++;
}

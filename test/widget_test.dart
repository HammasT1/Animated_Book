import 'package:animated_book/data/library.dart';
import 'package:animated_book/main.dart';
import 'package:animated_book/state/app_state.dart';
import 'package:animated_book/theme/app_theme.dart';
import 'package:animated_book/widgets/page_curl.dart';
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

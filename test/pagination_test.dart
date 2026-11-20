import 'package:animated_book/data/library.dart';
import 'package:animated_book/reading/book_pagination.dart';
import 'package:animated_book/reading/pagination.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

PageTextStyle _style(double fontSize) =>
    PageTextStyle(fontFamily: 'Serif', fontSize: fontSize, lineHeight: 1.8);

double _laidOutHeight(
  String text,
  PageRange page,
  PageTextStyle style,
  Size size,
) {
  final painter = TextPainter(
    text: buildPageSpan(text, page, style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width);
  final height = painter.height;
  painter.dispose();
  return height;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final text = kLibrary.map((b) => b.text).join('\n\n');
  const size = Size(320, 400);

  test('pages cover every word exactly once, in order', () {
    final pages = paginate(text: text, size: size, style: _style(18));

    expect(pages.length, greaterThan(1));
    for (var i = 1; i < pages.length; i++) {
      expect(pages[i].start, greaterThanOrEqualTo(pages[i - 1].end));
      // Only whitespace is skipped between pages.
      expect(text.substring(pages[i - 1].end, pages[i].start).trim(), isEmpty);
    }
    // Compare without whitespace, since a page may break after a hyphen.
    String ink(String s) => s.replaceAll(RegExp(r'\s+'), '');
    final rejoined = pages.map((p) => text.substring(p.start, p.end)).join();
    expect(ink(rejoined), ink(text));
  });

  test('every page fits in the page box', () {
    for (final fontSize in [14.0, 18.0, 28.0]) {
      final style = _style(fontSize);
      final pages = paginate(text: text, size: size, style: style);
      for (final page in pages) {
        expect(
          _laidOutHeight(text, page, style, size),
          lessThanOrEqualTo(size.height + 0.5),
          reason: 'font $fontSize, $page',
        );
      }
    }
  });

  test('pages only break between words or after a hyphen', () {
    final pages = paginate(text: text, size: size, style: _style(18));
    for (final page in pages.take(pages.length - 1)) {
      final breaksCleanly =
          RegExp(r'\s').hasMatch(text[page.end]) ||
          RegExp(r'[-—]').hasMatch(text[page.end - 1]);
      expect(breaksCleanly, isTrue, reason: '$page');
    }
  });

  test('larger text needs more pages', () {
    final small = paginate(text: text, size: size, style: _style(14));
    final large = paginate(text: text, size: size, style: _style(28));
    expect(large.length, greaterThan(small.length));
  });

  test('only paragraphs that start on a page get a drop cap', () {
    final style = _style(28);
    final pages = paginate(text: text, size: size, style: style);
    final carried = pages.firstWhere((p) => !startsParagraph(text, p.start));
    final opening = pages.first;

    bool hasLeadingDropCap(PageRange page) =>
        (buildPageSpan(text, page, style).children!.first as TextSpan).style ==
        style.dropCap;

    expect(hasLeadingDropCap(opening), isTrue);
    expect(hasLeadingDropCap(carried), isFalse);
  });

  test('a range of only whitespace has no pages', () {
    expect(paginate(text: '  \n', size: size, style: _style(18)), isEmpty);
  });

  test('a range paginates only its own text', () {
    final style = _style(18);
    const start = 200;
    final end = text.length ~/ 2;
    final pages = paginate(
      text: text,
      size: size,
      style: style,
      start: start,
      end: end,
    );
    expect(pages.first.start, greaterThanOrEqualTo(start));
    expect(pages.last.end, lessThanOrEqualTo(end));
  });

  test('pageIndexFor finds the page holding an offset', () {
    const pages = [PageRange(0, 10), PageRange(12, 20), PageRange(21, 30)];
    expect(pageIndexFor(pages, 0), 0);
    expect(pageIndexFor(pages, 11), 0);
    expect(pageIndexFor(pages, 12), 1);
    expect(pageIndexFor(pages, 29), 2);
    expect(pageIndexFor(pages, 99), 2);
  });

  group('BookPagination', () {
    // Three chapters; the middle one is long enough for several pages.
    final chapters = [
      kLibrary[0].text,
      kLibrary.map((b) => b.text).join('\n\n'),
      kLibrary[2].text,
    ];
    final bookText = chapters.join('\n\n');
    final starts = <int>[];
    var offset = 0;
    for (final c in chapters) {
      starts.add(offset);
      offset += c.length + 2;
    }

    BookPagination build({int eagerLimit = 0}) => BookPagination(
      text: bookText,
      chapterStarts: starts,
      size: size,
      style: _style(18),
      eagerLimit: eagerLimit,
    );

    List<PageRange> walk(BookPagination p) {
      final pages = [p.pageAt(0)];
      for (var next = p.after(pages.last); next != null;) {
        pages.add(next);
        next = p.after(next);
      }
      return pages;
    }

    test('every chapter starts on a new page', () {
      final pages = walk(build());
      for (final start in starts) {
        expect(pages.any((p) => p.start == start), isTrue, reason: '$start');
      }
      for (final page in pages) {
        final chapterEnds = starts.skip(1).map((s) => s - 2);
        expect(
          chapterEnds.any((e) => page.start < e && page.end > e + 2),
          isFalse,
          reason: '$page spans a chapter break',
        );
      }
    });

    test('pages can be walked forwards and backwards', () {
      final p = build();
      final forward = walk(p);
      final backward = [forward.last];
      for (var prev = p.before(backward.last); prev != null;) {
        backward.add(prev);
        prev = p.before(prev);
      }
      expect(backward.reversed.toList(), forward);
    });

    test('is lazy: only visited chapters are paginated up front', () {
      final p = build();
      expect(p.isComplete, isFalse);
      expect(p.pageCount, isNull);

      final last = p.pageAt(bookText.length - 1);
      expect(last.end, bookText.length);
      // Page numbers need every chapter before it.
      expect(p.indexOf(last), isNull);

      while (p.step()) {}
      expect(p.isComplete, isTrue);
      expect(p.indexOf(last), p.pageCount! - 1);
      expect(p.pageCount, walk(p).length);
    });

    test('spreads pair pages within chapters, each chapter opening left', () {
      final p = build();
      final pages = walk(p);
      final spreads = [p.spreadAt(0)];
      for (var next = p.spreadAfter(spreads.last); next != null;) {
        spreads.add(next);
        next = p.spreadAfter(next);
      }
      // Every page appears exactly once, as a left or a right page.
      final shown = [
        for (final left in spreads) ...[left, ?p.rightOf(left)],
      ];
      expect(shown, pages);
      // Every chapter starts on a left page.
      for (final start in starts) {
        expect(spreads.any((left) => left.start == start), isTrue);
      }
      // A spread never straddles a chapter break.
      for (final left in spreads) {
        final right = p.rightOf(left);
        if (right == null) continue;
        expect(
          starts.any((s) => s > left.start && s <= right.start),
          isFalse,
          reason: '$left + $right',
        );
      }
      // Walking back visits the same spreads, and any offset on a right
      // page finds its spread's left page.
      final back = [spreads.last];
      for (var prev = p.spreadBefore(back.last); prev != null;) {
        back.add(prev);
        prev = p.spreadBefore(prev);
      }
      expect(back.reversed.toList(), spreads);
      for (final left in spreads) {
        final right = p.rightOf(left);
        if (right != null) expect(p.spreadAt(right.start + 1), left);
      }
    });

    test('short books are paginated straight away', () {
      final p = build(eagerLimit: 1 << 30);
      expect(p.isComplete, isTrue);
      expect(p.indexOf(p.pageAt(0)), 0);
    });

    test('an empty book still has one (blank) page', () {
      final p = BookPagination(
        text: '',
        chapterStarts: const [0],
        size: size,
        style: _style(18),
      );
      expect(p.pageAt(0), const PageRange(0, 0));
      expect(p.after(p.pageAt(0)), isNull);
      expect(p.pageCount, 1);
    });
  });
}

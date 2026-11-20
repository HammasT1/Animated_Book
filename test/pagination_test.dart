import 'package:animated_book/data/library.dart';
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

  test('empty text gives one empty page', () {
    expect(paginate(text: '  \n', size: size, style: _style(18)), [
      const PageRange(0, 0),
    ]);
  });

  test('pageIndexFor finds the page holding an offset', () {
    const pages = [PageRange(0, 10), PageRange(12, 20), PageRange(21, 30)];
    expect(pageIndexFor(pages, 0), 0);
    expect(pageIndexFor(pages, 11), 0);
    expect(pageIndexFor(pages, 12), 1);
    expect(pageIndexFor(pages, 29), 2);
    expect(pageIndexFor(pages, 99), 2);
  });
}

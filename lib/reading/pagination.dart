import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A page: the half-open character range [start, end) of a book's text.
@immutable
class PageRange {
  const PageRange(this.start, this.end);

  final int start;
  final int end;

  bool contains(int offset) => offset >= start && offset < end;

  @override
  bool operator ==(Object other) =>
      other is PageRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PageRange($start, $end)';
}

/// The two text styles a page is set in: the body, and the large initial
/// that opens each paragraph.
///
/// Both are `inherit: false` so a page lays out exactly the same in a
/// [TextPainter] (when paginating) as in a `Text.rich` (when drawn),
/// whatever [DefaultTextStyle] happens to be above it.
@immutable
class PageTextStyle {
  PageTextStyle({
    required String fontFamily,
    required double fontSize,
    required double lineHeight,
    Color ink = const Color(0xFF000000),
    Color dropCapColor = const Color(0xFF000000),
  }) : body = TextStyle(
         inherit: false,
         fontFamily: fontFamily,
         fontSize: fontSize,
         height: lineHeight,
         color: ink,
         textBaseline: TextBaseline.alphabetic,
       ),
       dropCap = TextStyle(
         inherit: false,
         fontFamily: 'Serif',
         fontSize: fontSize * 2.33,
         fontWeight: FontWeight.bold,
         height: 0.9,
         letterSpacing: 6,
         color: dropCapColor,
         textBaseline: TextBaseline.alphabetic,
       ),
       layoutKey = (fontFamily, fontSize, lineHeight);

  final TextStyle body;
  final TextStyle dropCap;

  /// Everything about the style that affects where lines break. Colours are
  /// left out on purpose: they animate during a theme cross-fade and must not
  /// trigger re-pagination on every frame.
  final Object layoutKey;
}

/// Splits [text] into pages that each fit in [size] when set in [style].
///
/// Pages break at line ends, so no word is ever split across pages unless it
/// is wider than the page itself. Whitespace between pages is skipped, so a
/// page never starts with a blank line. Every non-space character of [text]
/// lands on exactly one page.
List<PageRange> paginate({
  required String text,
  required Size size,
  required PageTextStyle style,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  var start = _skipSpace(text, 0);
  if (start >= text.length) return const [PageRange(0, 0)];
  if (size.width <= 0 || size.height <= 0) {
    return [PageRange(0, text.length)];
  }

  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  );
  final pages = <PageRange>[];
  try {
    while (start < text.length) {
      var end = _fitPage(painter, text, start, size, style);
      end = _trimEnd(text, start, end);
      // Always make progress, even if not a single line fits.
      if (end <= start) end = math.min(text.length, start + 1);
      pages.add(PageRange(start, end));
      start = _skipSpace(text, end);
    }
  } finally {
    painter.dispose();
  }
  return pages;
}

/// Index of the page that holds [offset] (the last page starting at or
/// before it).
int pageIndexFor(List<PageRange> pages, int offset) {
  var lo = 0;
  var hi = pages.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (pages[mid].start <= offset) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}

/// Builds the styled text for one page: a drop cap on every paragraph that
/// starts on this page, and none on a paragraph carried over from the page
/// before. The span holds exactly the characters of [range], so offsets in
/// the laid-out span map one-to-one onto offsets in [text].
TextSpan buildPageSpan(String text, PageRange range, PageTextStyle style) {
  final parts = text.substring(range.start, range.end).split('\n\n');
  final children = <InlineSpan>[];
  for (var i = 0; i < parts.length; i++) {
    if (i > 0) children.add(const TextSpan(text: '\n\n'));
    final part = parts[i];
    if (part.isEmpty) continue;

    final opensParagraph = i > 0 || startsParagraph(text, range.start);
    final initial = String.fromCharCode(part.runes.first);
    if (opensParagraph && initial.trim().isNotEmpty) {
      children
        ..add(TextSpan(text: initial, style: style.dropCap))
        ..add(TextSpan(text: part.substring(initial.length)));
    } else {
      children.add(TextSpan(text: part));
    }
  }
  return TextSpan(style: style.body, children: children);
}

/// Whether [offset] is the first character of a paragraph (as opposed to
/// the middle of one that began on an earlier page).
bool startsParagraph(String text, int offset) {
  var newlines = 0;
  for (var i = offset - 1; i >= 0; i--) {
    final c = text.codeUnitAt(i);
    if (!_isSpace(c)) return newlines >= 2;
    if (c == 0x0A) newlines++;
  }
  return true;
}

/// The end offset of the longest run of whole lines from [start] that fits
/// in [size].
int _fitPage(
  TextPainter painter,
  String text,
  int start,
  Size size,
  PageTextStyle style,
) {
  // Lay out a chunk comfortably bigger than a page; grow it only if the
  // whole chunk fits, so long books cost about one chunk per page.
  var chunk = 2000;
  while (true) {
    final chunkEnd = math.min(text.length, start + chunk);
    painter.text = buildPageSpan(text, PageRange(start, chunkEnd), style);
    painter.layout(maxWidth: size.width);

    if (painter.height <= size.height) {
      if (chunkEnd == text.length) return chunkEnd;
      chunk *= 2;
      continue;
    }

    final lines = painter.computeLineMetrics();
    var bottom = 0.0;
    var last = 0;
    for (var i = 0; i < lines.length; i++) {
      bottom += lines[i].height;
      // Half a pixel of slack absorbs floating-point rounding.
      if (bottom > size.height + 0.5) break;
      last = i;
    }

    // Probe the middle of the last line that fits: unlike its left edge,
    // that point can't be mistaken for the end of the line above.
    final line = lines[last];
    final probe = painter.getPositionForOffset(
      Offset(line.left + line.width / 2, line.baseline - line.ascent / 2),
    );
    return start + painter.getLineBoundary(probe).end;
  }
}

int _skipSpace(String text, int offset) {
  while (offset < text.length && _isSpace(text.codeUnitAt(offset))) {
    offset++;
  }
  return offset;
}

int _trimEnd(String text, int start, int end) {
  while (end > start && _isSpace(text.codeUnitAt(end - 1))) {
    end--;
  }
  return end;
}

bool _isSpace(int c) => c == 0x20 || c == 0x0A || c == 0x09 || c == 0x0D;

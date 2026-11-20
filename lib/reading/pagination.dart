import 'dart:math' as math;
import 'dart:ui' as ui;

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

/// Splits [text] (or just its [start]..[end] range, e.g. one chapter) into
/// pages that each fit in [size] when set in [style].
///
/// Pages break at line ends, so no word is ever split across pages unless it
/// is wider than the page itself. Whitespace between pages is skipped, so a
/// page never starts with a blank line. Every non-space character in the
/// range lands on exactly one page; a range of only whitespace has no pages.
///
/// Text is laid out a large block at a time and many pages are cut from each
/// layout, so the cost is roughly one layout pass over the text.
List<PageRange> paginate({
  required String text,
  required Size size,
  required PageTextStyle style,
  TextScaler textScaler = TextScaler.noScaling,
  int start = 0,
  int? end,
}) {
  final rangeEnd = end ?? text.length;
  var pos = _skipSpace(text, start, rangeEnd);
  if (pos >= rangeEnd) return const [];
  if (size.width <= 0 || size.height <= 0) {
    return [PageRange(pos, _trimEnd(text, pos, rangeEnd))];
  }

  final pages = <PageRange>[];
  while (pos < rangeEnd) {
    pos = _cutPages(text, pos, rangeEnd, size, style, textScaler, pages);
  }
  return pages;
}

/// Characters laid out at once: comfortably more than a page at any text
/// size, while keeping a single layout cheap.
const int _kChunk = 12000;

/// Lays out one chunk from [pos], appends every page that is complete within
/// it to [pages], and returns where the next chunk should start.
int _cutPages(
  String text,
  int pos,
  int rangeEnd,
  Size size,
  PageTextStyle style,
  TextScaler textScaler,
  List<PageRange> pages,
) {
  final chunkEnd = math.min(rangeEnd, pos + _kChunk);
  final isLastChunk = chunkEnd == rangeEnd;

  // Built exactly as TextPainter (and so Text.rich) builds its paragraph,
  // so lines break in the same places as on screen. A ui.Paragraph is used
  // directly for its cheap getLineNumberAt.
  final span = buildPageSpan(text, PageRange(pos, chunkEnd), style);
  final builder = ui.ParagraphBuilder(
    span.style!.getParagraphStyle(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    ),
  );
  span.build(builder, textScaler: textScaler);
  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: size.width));

  try {
    final lines = paragraph.computeLineMetrics();
    final chunkLength = chunkEnd - pos;

    // Offset (relative to pos) of the first character on line k, found by
    // binary search over the paragraph's cheap offset -> line lookup.
    int lineStart(int k) {
      if (k <= 0) return 0;
      if (k >= lines.length) return chunkLength;
      var lo = 0;
      var hi = chunkLength;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if ((paragraph.getLineNumberAt(mid) ?? lines.length) >= k) {
          hi = mid;
        } else {
          lo = mid + 1;
        }
      }
      return lo;
    }

    // Blank lines (between paragraphs) have no width.
    bool isBlank(int i) => lines[i].width < 0.5;

    var i = 0;
    while (true) {
      // A page never starts with a blank line.
      while (i < lines.length && isBlank(i)) {
        i++;
      }
      if (i >= lines.length) return chunkEnd;

      // Take whole lines while they fit. Half a pixel of slack absorbs
      // floating-point rounding.
      var j = i;
      var height = 0.0;
      while (j < lines.length &&
          height + lines[j].height <= size.height + 0.5) {
        height += lines[j].height;
        j++;
      }

      final pageStart = _skipSpace(text, pos + lineStart(i), chunkEnd);
      // The chunk ran out before the page filled up: its last line may be
      // cut short, so lay out again from this page's start (unless the page
      // already began the chunk, which only absurd sizes could cause).
      if (j == lines.length && !isLastChunk && pageStart > pos) {
        return pageStart;
      }
      // Always make progress, even if not a single line fits.
      if (j == i) j = i + 1;

      var pageEnd = _trimEnd(text, pageStart, pos + lineStart(j));
      if (pageEnd <= pageStart) pageEnd = math.min(rangeEnd, pageStart + 1);
      pages.add(PageRange(pageStart, pageEnd));
      i = j;
      if (j == lines.length) return isLastChunk ? rangeEnd : pageEnd;
    }
  } finally {
    paragraph.dispose();
  }
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

int _skipSpace(String text, int offset, [int? end]) {
  final limit = end ?? text.length;
  while (offset < limit && _isSpace(text.codeUnitAt(offset))) {
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

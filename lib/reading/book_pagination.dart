import 'package:flutter/painting.dart';

import 'pagination.dart';

/// The pages of a whole book for one page size and typography, worked out
/// one chapter at a time.
///
/// Chapters always start on a new page, so each can be paginated on its own.
/// Only the chapters the reader actually visits are paginated straight away
/// ([pageAt], [after], [before]); [step] fills in the rest a chapter at a
/// time, so a long book never stalls the UI. Page numbers ([indexOf],
/// [pageCount]) become known as the chapters before them are done.
///
/// Pages are identified by their [PageRange] (character offsets), never by
/// index, so they stay valid while the rest of the book is still being
/// paginated.
class BookPagination {
  BookPagination({
    required this.text,
    required List<int> chapterStarts,
    required this.size,
    required this.style,
    this.textScaler = TextScaler.noScaling,
    int eagerLimit = 40000,
  }) : _starts = chapterStarts.isEmpty ? const [0] : chapterStarts,
       _pages = List.filled(
         chapterStarts.isEmpty ? 1 : chapterStarts.length,
         null,
       ) {
    // Short books are cheap enough to do in one go.
    if (text.length <= eagerLimit) {
      while (step()) {}
    }
  }

  final String text;
  final Size size;
  final PageTextStyle style;
  final TextScaler textScaler;

  final List<int> _starts;
  final List<List<PageRange>?> _pages;
  int _done = 0;

  /// The page shown for an empty book.
  static const PageRange _blank = PageRange(0, 0);

  bool get isComplete => _done == _pages.length;

  /// Fraction of chapters paginated so far.
  double get progress => _done / _pages.length;

  /// Total pages, once every chapter has been paginated.
  int? get pageCount {
    if (!isComplete) return null;
    final total = _pages.fold<int>(0, (sum, p) => sum + p!.length);
    return total == 0 ? 1 : total;
  }

  /// Paginates the first chapter not done yet. Returns whether any remain.
  bool step() {
    final next = _pages.indexOf(null);
    if (next < 0) return false;
    _chapter(next);
    return !isComplete;
  }

  /// The page holding [offset] (or the nearest page, if [offset] falls in
  /// blank space between pages).
  PageRange pageAt(int offset) {
    final c = _chapterOf(offset);
    final pages = _chapter(c);
    if (pages.isNotEmpty) return pages[pageIndexFor(pages, offset)];
    // An empty chapter: use the next page, else the previous one.
    return _firstPageFrom(c + 1) ?? _lastPageUpTo(c - 1) ?? _blank;
  }

  /// The page after [page], or null at the end of the book.
  PageRange? after(PageRange page) {
    final c = _chapterOf(page.start);
    final pages = _chapter(c);
    final i = pages.indexOf(page);
    if (i >= 0 && i + 1 < pages.length) return pages[i + 1];
    return _firstPageFrom(c + 1);
  }

  /// The page before [page], or null at the start of the book.
  PageRange? before(PageRange page) {
    final c = _chapterOf(page.start);
    final pages = _chapter(c);
    final i = pages.indexOf(page);
    if (i > 0) return pages[i - 1];
    return _lastPageUpTo(c - 1);
  }

  // ---------------------------------------------------------------------------
  // Two-page spreads
  //
  // Pages pair up within each chapter: a chapter always opens on a left page,
  // and one with an odd number of pages ends on a blank right page, as in a
  // printed book. Pairing within chapters keeps spreads stable however much
  // of the rest of the book has been paginated. A spread is identified by
  // its left page.
  // ---------------------------------------------------------------------------

  /// The left page of the spread holding [offset].
  PageRange spreadAt(int offset) {
    final page = pageAt(offset);
    final c = _chapterOf(page.start);
    final pages = _chapter(c);
    final i = pages.indexOf(page);
    return i <= 0 ? page : pages[i - i % 2];
  }

  /// The right page of the spread starting at [left], or null if it's blank.
  PageRange? rightOf(PageRange left) {
    final pages = _chapter(_chapterOf(left.start));
    final i = pages.indexOf(left);
    return i >= 0 && i + 1 < pages.length ? pages[i + 1] : null;
  }

  /// The left page of the next spread, or null at the end of the book.
  PageRange? spreadAfter(PageRange left) {
    final next = after(rightOf(left) ?? left);
    return next == null ? null : spreadAt(next.start);
  }

  /// The left page of the previous spread, or null at the start.
  PageRange? spreadBefore(PageRange left) {
    final previous = before(left);
    return previous == null ? null : spreadAt(previous.start);
  }

  /// 0-based page number of [page], once every chapter before it is done.
  int? indexOf(PageRange page) {
    final c = _chapterOf(page.start);
    var index = 0;
    for (var i = 0; i < c; i++) {
      final pages = _pages[i];
      if (pages == null) return null;
      index += pages.length;
    }
    final local = _chapter(c).indexOf(page);
    return local < 0 ? null : index + local;
  }

  List<PageRange> _chapter(int c) {
    final cached = _pages[c];
    if (cached != null) return cached;
    final end = c + 1 < _starts.length ? _starts[c + 1] : text.length;
    final pages = paginate(
      text: text,
      size: size,
      style: style,
      textScaler: textScaler,
      start: _starts[c],
      end: end,
    );
    _pages[c] = pages;
    _done++;
    return pages;
  }

  int _chapterOf(int offset) {
    var lo = 0;
    var hi = _starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_starts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  PageRange? _firstPageFrom(int c) {
    for (var i = c; i < _starts.length; i++) {
      final pages = _chapter(i);
      if (pages.isNotEmpty) return pages.first;
    }
    return null;
  }

  PageRange? _lastPageUpTo(int c) {
    for (var i = c; i >= 0; i--) {
      final pages = _chapter(i);
      if (pages.isNotEmpty) return pages.last;
    }
    return null;
  }
}

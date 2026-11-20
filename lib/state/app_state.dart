import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/library.dart';
import '../models/book.dart';
import '../theme/app_theme.dart';

/// Where a reader is in a book: the character range of the page on screen.
///
/// [start] is where reading resumes (it stays put when the text is
/// re-paginated); [end] says how far through the book the reader has got.
@immutable
class ReadingPosition {
  const ReadingPosition(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is ReadingPosition && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Everything the app remembers between launches: paper style, reader
/// typography, bookmarks and the reading position in each book.
///
/// Positions and bookmarks are character offsets into [Book.text], so they
/// stay on the same words however the text is paginated.
///
/// Every setter writes through to [SharedPreferences] immediately, so state
/// survives the app being killed at any point.
class AppState extends ChangeNotifier {
  /// [books] is only used to migrate progress and bookmarks saved by older
  /// versions, which stored fixed page numbers.
  AppState(this._prefs, {List<Book> books = kLibrary}) {
    _migrateLegacyPages(books);
    _load();
  }

  final SharedPreferences _prefs;

  static const double minFontSize = 14;
  static const double maxFontSize = 28;
  static const double defaultFontSize = 18;
  static const double minLineHeight = 1.4;
  static const double maxLineHeight = 2.2;
  static const double defaultLineHeight = 1.8;

  static const _kTheme = 'reader.theme';
  static const _kFontSize = 'reader.fontSize';
  static const _kLineHeight = 'reader.lineHeight';
  static const _kFont = 'reader.font';
  static const _kTurnStyle = 'reader.turnStyle';
  static const _kBookmarksPrefix = 'marks.';
  static const _kPositionPrefix = 'position.';

  // Keys used before pagination was dynamic; values were section indices.
  static const _kLegacyBookmarksPrefix = 'bookmarks.';
  static const _kLegacyProgressPrefix = 'progress.';

  ReaderTheme _readerTheme = ReaderTheme.light;
  double _fontSize = defaultFontSize;
  double _lineHeight = defaultLineHeight;
  ReaderFont _font = ReaderFont.serif;
  PageTurnStyle _turnStyle = PageTurnStyle.curl;
  final Map<String, Set<int>> _bookmarks = {};
  final Map<String, ReadingPosition> _positions = {};

  ReaderTheme get readerTheme => _readerTheme;
  bool get isDark => _readerTheme.isDark;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  ReaderFont get font => _font;
  PageTurnStyle get turnStyle => _turnStyle;

  void _load() {
    _readerTheme =
        ReaderTheme.values.asNameMap()[_prefs.getString(_kTheme)] ??
        ReaderTheme.light;
    _fontSize = (_prefs.getDouble(_kFontSize) ?? defaultFontSize).clamp(
      minFontSize,
      maxFontSize,
    );
    _lineHeight = (_prefs.getDouble(_kLineHeight) ?? defaultLineHeight).clamp(
      minLineHeight,
      maxLineHeight,
    );
    _font =
        ReaderFont.values.asNameMap()[_prefs.getString(_kFont)] ??
        ReaderFont.serif;
    _turnStyle =
        PageTurnStyle.values.asNameMap()[_prefs.getString(_kTurnStyle)] ??
        PageTurnStyle.curl;

    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_kBookmarksPrefix)) {
        final offsets = _prefs.getStringList(key) ?? const [];
        _bookmarks[key.substring(_kBookmarksPrefix.length)] = {
          for (final o in offsets) ?int.tryParse(o),
        };
      } else if (key.startsWith(_kPositionPrefix)) {
        final value = _prefs.getStringList(key) ?? const [];
        final start = value.isNotEmpty ? int.tryParse(value[0]) : null;
        final end = value.length > 1 ? int.tryParse(value[1]) : null;
        if (start != null && end != null) {
          _positions[key.substring(_kPositionPrefix.length)] = ReadingPosition(
            start,
            end,
          );
        }
      }
    }
  }

  /// Converts section-index progress and bookmarks from older versions into
  /// character offsets, then removes the old keys.
  void _migrateLegacyPages(List<Book> books) {
    for (final book in books) {
      final progressKey = '$_kLegacyProgressPrefix${book.id}';
      final legacyPage = _prefs.getInt(progressKey);
      if (legacyPage != null) {
        final i = legacyPage.clamp(0, book.sections.length - 1);
        final start = book.sectionStart(i);
        if (!_prefs.containsKey('$_kPositionPrefix${book.id}')) {
          _prefs.setStringList('$_kPositionPrefix${book.id}', [
            '$start',
            '${start + book.sections[i].length}',
          ]);
        }
        _prefs.remove(progressKey);
      }

      final marksKey = '$_kLegacyBookmarksPrefix${book.id}';
      final legacyMarks = _prefs.getStringList(marksKey);
      if (legacyMarks != null) {
        final offsets = {
          for (final p in legacyMarks.map(int.tryParse))
            if (p != null && p >= 0 && p < book.sections.length)
              book.sectionStart(p),
          ...?_prefs
              .getStringList('$_kBookmarksPrefix${book.id}')
              ?.map(int.tryParse)
              .whereType<int>(),
        };
        _prefs.setStringList(
          '$_kBookmarksPrefix${book.id}',
          (offsets.toList()..sort()).map((o) => '$o').toList(),
        );
        _prefs.remove(marksKey);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Appearance
  // ---------------------------------------------------------------------------

  void setReaderTheme(ReaderTheme theme) {
    if (theme == _readerTheme) return;
    _readerTheme = theme;
    _prefs.setString(_kTheme, theme.name);
    notifyListeners();
  }

  /// Quick sun/moon toggle: dark goes back to light, light or sepia go dark.
  void toggleDark() =>
      setReaderTheme(isDark ? ReaderTheme.light : ReaderTheme.dark);

  void setFontSize(double size) {
    final clamped = size.clamp(minFontSize, maxFontSize);
    if (clamped == _fontSize) return;
    _fontSize = clamped;
    _prefs.setDouble(_kFontSize, clamped);
    notifyListeners();
  }

  void setLineHeight(double height) {
    final clamped = height.clamp(minLineHeight, maxLineHeight);
    if (clamped == _lineHeight) return;
    _lineHeight = clamped;
    _prefs.setDouble(_kLineHeight, clamped);
    notifyListeners();
  }

  void setFont(ReaderFont font) {
    if (font == _font) return;
    _font = font;
    _prefs.setString(_kFont, font.name);
    notifyListeners();
  }

  void setTurnStyle(PageTurnStyle style) {
    if (style == _turnStyle) return;
    _turnStyle = style;
    _prefs.setString(_kTurnStyle, style.name);
    notifyListeners();
  }

  void resetTypography() {
    _fontSize = defaultFontSize;
    _lineHeight = defaultLineHeight;
    _font = ReaderFont.serif;
    _prefs
      ..remove(_kFontSize)
      ..remove(_kLineHeight)
      ..remove(_kFont);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Bookmarks
  // ---------------------------------------------------------------------------

  /// Bookmarked character offsets in a book.
  Set<int> bookmarksFor(String bookId) =>
      Set.unmodifiable(_bookmarks[bookId] ?? const <int>{});

  /// Whether any bookmark falls inside the character range [start, end).
  bool hasBookmarkIn(String bookId, int start, int end) =>
      _bookmarks[bookId]?.any((o) => o >= start && o < end) ?? false;

  /// Bookmarks the page [start, end), or removes every bookmark on it.
  void toggleBookmark(String bookId, int start, int end) {
    if (hasBookmarkIn(bookId, start, end)) {
      removeBookmarksIn(bookId, start, end);
    } else {
      _bookmarks.putIfAbsent(bookId, () => <int>{}).add(start);
      _saveBookmarks(bookId);
    }
  }

  void removeBookmarksIn(String bookId, int start, int end) {
    final offsets = _bookmarks[bookId];
    if (offsets == null) return;
    offsets.removeWhere((o) => o >= start && o < end);
    _saveBookmarks(bookId);
  }

  void _saveBookmarks(String bookId) {
    final offsets = _bookmarks[bookId]!.toList()..sort();
    _prefs.setStringList(
      '$_kBookmarksPrefix$bookId',
      offsets.map((o) => '$o').toList(),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reading progress
  // ---------------------------------------------------------------------------

  /// Where the reader is in a book, or null if it was never opened.
  ReadingPosition? positionOf(String bookId) => _positions[bookId];

  /// Forgets the position and bookmarks of a book taken off the shelf.
  void forgetBook(String bookId) {
    _positions.remove(bookId);
    _bookmarks.remove(bookId);
    _prefs
      ..remove('$_kPositionPrefix$bookId')
      ..remove('$_kBookmarksPrefix$bookId');
    notifyListeners();
  }

  void setPosition(String bookId, ReadingPosition position) {
    if (_positions[bookId] == position) return;
    _positions[bookId] = position;
    _prefs.setStringList('$_kPositionPrefix$bookId', [
      '${position.start}',
      '${position.end}',
    ]);
    notifyListeners();
  }
}

/// Makes [AppState] available to the whole widget tree and rebuilds
/// dependents whenever it changes.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  /// Reads the state and subscribes [context] to changes.
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateScope>()!.notifier!;

  /// Reads the state without subscribing (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppStateScope>()!.notifier!;
}

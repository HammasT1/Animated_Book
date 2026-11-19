import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Everything the app remembers between launches: paper style, reader
/// typography, bookmarks and the last page read in each book.
///
/// Every setter writes through to [SharedPreferences] immediately, so state
/// survives the app being killed at any point.
class AppState extends ChangeNotifier {
  AppState(this._prefs) {
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
  static const _kBookmarksPrefix = 'bookmarks.';
  static const _kProgressPrefix = 'progress.';

  ReaderTheme _readerTheme = ReaderTheme.light;
  double _fontSize = defaultFontSize;
  double _lineHeight = defaultLineHeight;
  ReaderFont _font = ReaderFont.serif;
  final Map<String, Set<int>> _bookmarks = {};
  final Map<String, int> _lastPage = {};

  ReaderTheme get readerTheme => _readerTheme;
  bool get isDark => _readerTheme.isDark;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  ReaderFont get font => _font;

  void _load() {
    _readerTheme = ReaderTheme.values.asNameMap()[_prefs.getString(_kTheme)] ??
        ReaderTheme.light;
    _fontSize = (_prefs.getDouble(_kFontSize) ?? defaultFontSize)
        .clamp(minFontSize, maxFontSize);
    _lineHeight = (_prefs.getDouble(_kLineHeight) ?? defaultLineHeight)
        .clamp(minLineHeight, maxLineHeight);
    _font =
        ReaderFont.values.asNameMap()[_prefs.getString(_kFont)] ??
        ReaderFont.serif;

    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_kBookmarksPrefix)) {
        final pages = _prefs.getStringList(key) ?? const [];
        _bookmarks[key.substring(_kBookmarksPrefix.length)] = {
          for (final p in pages) ?int.tryParse(p),
        };
      } else if (key.startsWith(_kProgressPrefix)) {
        final page = _prefs.getInt(key);
        if (page != null) {
          _lastPage[key.substring(_kProgressPrefix.length)] = page;
        }
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

  bool isBookmarked(String bookId, int page) =>
      _bookmarks[bookId]?.contains(page) ?? false;

  Set<int> bookmarksFor(String bookId) =>
      Set.unmodifiable(_bookmarks[bookId] ?? const <int>{});

  void toggleBookmark(String bookId, int page) {
    final pages = _bookmarks.putIfAbsent(bookId, () => <int>{});
    if (!pages.remove(page)) pages.add(page);
    _prefs.setStringList(
      '$_kBookmarksPrefix$bookId',
      (pages.toList()..sort()).map((p) => '$p').toList(),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reading progress
  // ---------------------------------------------------------------------------

  /// The page the reader was last on, or null if the book was never opened.
  int? lastPage(String bookId) => _lastPage[bookId];

  void setLastPage(String bookId, int page) {
    if (_lastPage[bookId] == page) return;
    _lastPage[bookId] = page;
    _prefs.setInt('$_kProgressPrefix$bookId', page);
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

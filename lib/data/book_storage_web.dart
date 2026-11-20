import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../import/parsed_book.dart';
import '../models/book.dart';
import 'book_storage.dart';

/// Stores imported books in the browser's local storage (through
/// shared_preferences). Browsers allow only a few megabytes per site, so a
/// very large book may not fit; that is reported as an import error.
class PlatformBookStorage implements BookStorage {
  static const _kIds = 'library.ids';
  static String _bookKey(String id) => 'library.book.$id';
  static String _coverKey(String id) => 'library.cover.$id';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<List<Book>> loadAll() async {
    final prefs = await _prefs;
    final books = <(Book, int)>[];
    for (final id in prefs.getStringList(_kIds) ?? const <String>[]) {
      final json = prefs.getString(_bookKey(id));
      if (json == null) continue;
      try {
        final cover = prefs.getString(_coverKey(id));
        books.add(decodeBook(json, cover == null ? null : base64Decode(cover)));
      } catch (_) {
        // Skip a damaged entry rather than losing the whole library.
      }
    }
    return sortByAdded(books);
  }

  @override
  Future<void> save(Book book) async {
    final prefs = await _prefs;
    try {
      final cover = book.coverImage;
      if (cover != null) {
        await prefs.setString(_coverKey(book.id), base64Encode(cover));
      }
      await prefs.setString(_bookKey(book.id), encodeBook(book));
      final ids = prefs.getStringList(_kIds) ?? <String>[];
      if (!ids.contains(book.id)) {
        await prefs.setStringList(_kIds, [...ids, book.id]);
      }
    } catch (_) {
      await delete(book.id);
      throw const BookImportException(
        "there isn't enough storage space in this browser",
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    final prefs = await _prefs;
    await prefs.remove(_bookKey(id));
    await prefs.remove(_coverKey(id));
    final ids = prefs.getStringList(_kIds) ?? <String>[];
    if (ids.remove(id)) await prefs.setStringList(_kIds, ids);
  }
}

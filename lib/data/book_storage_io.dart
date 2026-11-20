import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import 'book_storage.dart';

/// Stores each imported book as `<id>.json` (plus `<id>.cover`) in a
/// `books` folder inside the app's private support directory.
class PlatformBookStorage implements BookStorage {
  Directory? _dir;

  Future<Directory> _folder() async {
    final existing = _dir;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}books');
    await dir.create(recursive: true);
    return _dir = dir;
  }

  File _file(Directory dir, String id, String ext) =>
      File('${dir.path}${Platform.pathSeparator}$id.$ext');

  @override
  Future<List<Book>> loadAll() async {
    final dir = await _folder();
    final books = <(Book, int)>[];
    await for (final entry in dir.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      try {
        final id = entry.uri.pathSegments.last.replaceAll('.json', '');
        final coverFile = _file(dir, id, 'cover');
        final cover = await coverFile.exists()
            ? await coverFile.readAsBytes()
            : null;
        books.add(decodeBook(await entry.readAsString(), cover));
      } catch (_) {
        // Skip a damaged file rather than losing the whole library.
      }
    }
    return sortByAdded(books);
  }

  @override
  Future<void> save(Book book) async {
    final dir = await _folder();
    final cover = book.coverImage;
    if (cover != null) {
      await _file(dir, book.id, 'cover').writeAsBytes(cover, flush: true);
    }
    // Write the text last and atomically, so a half-written book is never
    // listed.
    final tmp = _file(dir, book.id, 'json.tmp');
    await tmp.writeAsString(encodeBook(book), flush: true);
    await tmp.rename(_file(dir, book.id, 'json').path);
  }

  @override
  Future<void> delete(String id) async {
    final dir = await _folder();
    for (final ext in const ['json', 'cover']) {
      final file = _file(dir, id, ext);
      if (await file.exists()) await file.delete();
    }
  }
}

import 'dart:convert';
import 'dart:typed_data';

import '../models/book.dart';
import 'book_storage_io.dart'
    if (dart.library.js_interop) 'book_storage_web.dart'
    as platform;

/// Where imported books are kept between launches.
abstract class BookStorage {
  /// The storage for this platform: files in the app's support folder on
  /// Android and desktop, the browser's local storage on the web.
  factory BookStorage() = platform.PlatformBookStorage;

  /// Every stored book, oldest import first.
  Future<List<Book>> loadAll();

  /// Stores [book] (text, metadata and cover).
  Future<void> save(Book book);

  Future<void> delete(String id);
}

/// Keeps books in memory only: for tests, and as a fallback when the
/// platform storage can't be reached.
class MemoryBookStorage implements BookStorage {
  final Map<String, Book> _books = {};

  @override
  Future<List<Book>> loadAll() async => _books.values.toList();

  @override
  Future<void> save(Book book) async => _books[book.id] = book;

  @override
  Future<void> delete(String id) async => _books.remove(id);
}

/// The JSON stored for a book; the cover is stored separately as bytes.
String encodeBook(Book book) => jsonEncode({
  'version': 1,
  'id': book.id,
  'title': book.title,
  'author': book.author,
  'addedAt': DateTime.now().millisecondsSinceEpoch,
  'sections': book.sections,
});

/// Rebuilds an imported book from [encodeBook]'s JSON, with its sort key.
(Book, int) decodeBook(String json, Uint8List? cover) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  final book = Book(
    id: map['id'] as String,
    title: map['title'] as String,
    author: map['author'] as String,
    sections: (map['sections'] as List).cast<String>(),
    coverImage: cover,
    sectionsAreChapters: true,
    isImported: true,
  );
  return (book, (map['addedAt'] as num?)?.toInt() ?? 0);
}

/// Sorts decoded books oldest first.
List<Book> sortByAdded(Iterable<(Book, int)> books) {
  final list = books.toList()..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (book, _) in list) book];
}

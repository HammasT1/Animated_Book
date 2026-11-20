import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../import/book_import.dart';
import '../models/book.dart';
import 'book_storage.dart';
import 'library.dart';

/// The shelf: the bundled books followed by the ones the reader imported.
class LibraryStore extends ChangeNotifier {
  LibraryStore(
    this._storage, {
    this.bundled = kLibrary,
    this.parseInBackground = true,
  });

  /// A shelf with only the bundled books, nothing saved: for tests.
  LibraryStore.inMemory({this.parseInBackground = false})
    : _storage = MemoryBookStorage(),
      bundled = kLibrary;

  final BookStorage _storage;
  final List<Book> bundled;

  /// Parse files in a separate isolate, so a big EPUB doesn't freeze the UI.
  final bool parseInBackground;

  List<Book> _imported = const [];
  late List<Book> _books = bundled;

  List<Book> get books => _books;

  void _set(List<Book> imported) {
    _imported = imported;
    _books = [...bundled, ...imported];
    notifyListeners();
  }

  /// Loads imported books from storage. A failure leaves the shelf with just
  /// the bundled books instead of stopping the app from starting.
  Future<void> load() async {
    try {
      _set(await _storage.loadAll());
    } catch (e) {
      debugPrint('Could not load imported books: $e');
    }
  }

  /// Reads a `.txt` or `.epub` file and puts it on the shelf.
  ///
  /// Returns the book and whether it was already on the shelf (the same
  /// book imported twice is kept once). Throws [BookImportException] with a
  /// reader-facing reason if the file can't be read or stored.
  Future<(Book book, bool alreadyThere)> importFile(
    String fileName,
    Uint8List bytes,
  ) async {
    final ParsedBook parsed;
    try {
      parsed = parseInBackground
          ? await compute(parseBookFile, (fileName, bytes))
          : parseBookFile((fileName, bytes));
    } on BookImportException {
      rethrow;
    } catch (e) {
      debugPrint('Import of $fileName failed: $e');
      throw const BookImportException("it couldn't be read");
    }

    final id = bookIdFor(parsed);
    for (final book in _imported) {
      if (book.id == id) return (book, true);
    }

    final book = Book(
      id: id,
      title: parsed.title,
      author: parsed.author,
      sections: parsed.chapters,
      coverImage: parsed.cover,
      sectionsAreChapters: true,
      isImported: true,
    );
    try {
      await _storage.save(book);
    } on BookImportException {
      rethrow;
    } catch (e) {
      debugPrint('Saving $fileName failed: $e');
      throw const BookImportException("it couldn't be saved");
    }
    _set([..._imported, book]);
    return (book, false);
  }

  /// Takes an imported book off the shelf and deletes its stored copy.
  Future<void> remove(String id) async {
    await _storage.delete(id);
    _set([
      for (final b in _imported)
        if (b.id != id) b,
    ]);
  }
}

/// A stable id for an imported book, derived from its content, so the same
/// book imported twice gets the same id (and keeps its reading position).
String bookIdFor(ParsedBook book) {
  // 32-bit FNV-1a: plenty for a personal shelf, and the same on the web.
  var hash = 0x811C9DC5;
  void add(String s) {
    for (final unit in s.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
  }

  add(book.title);
  add('\u0000');
  add(book.author);
  add('\u0000${book.length}\u0000');
  final first = book.chapters.isEmpty ? '' : book.chapters.first;
  add(first.length > 4000 ? first.substring(0, 4000) : first);
  return 'import-${hash.toRadixString(16).padLeft(8, '0')}';
}

/// Makes the [LibraryStore] available to the widget tree.
class LibraryScope extends InheritedNotifier<LibraryStore> {
  const LibraryScope({
    super.key,
    required LibraryStore library,
    required super.child,
  }) : super(notifier: library);

  static LibraryStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LibraryScope>()!.notifier!;

  static LibraryStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LibraryScope>()!.notifier!;
}

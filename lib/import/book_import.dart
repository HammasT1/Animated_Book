import 'dart:typed_data';

import 'epub_import.dart';
import 'parsed_book.dart';
import 'txt_import.dart';

export 'parsed_book.dart' show BookImportException, ParsedBook;

/// File types the app can import.
const List<String> kImportExtensions = ['txt', 'epub'];

/// Reads a `.txt` or `.epub` file into a [ParsedBook].
///
/// Throws [BookImportException] with a reader-facing reason if it can't.
/// Takes a single record argument so it can run in another isolate via
/// `compute`.
ParsedBook parseBookFile((String, Uint8List) file) {
  final (fileName, bytes) = file;
  final extension = fileName.contains('.')
      ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
      : '';
  if (bytes.isEmpty) throw const BookImportException('the file is empty');
  return switch (extension) {
    'txt' => parseTxt(fileName, bytes),
    'epub' => parseEpub(fileName, bytes),
    _ => throw const BookImportException(
      'only .txt and .epub files are supported',
    ),
  };
}

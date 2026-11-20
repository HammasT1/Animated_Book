import 'dart:typed_data';

/// What an importer gets out of a file, before it becomes a [Book] on the
/// shelf.
class ParsedBook {
  const ParsedBook({
    required this.title,
    required this.author,
    required this.chapters,
    this.cover,
  });

  final String title;
  final String author;

  /// Chapter texts in reading order. Paragraphs are separated by exactly
  /// one blank line, and no chapter is longer than [kMaxChapterLength].
  final List<String> chapters;

  /// Cover image bytes, if the file had one.
  final Uint8List? cover;

  int get length => chapters.fold(0, (sum, c) => sum + c.length);
}

/// Thrown when a file can't be turned into a book.
class BookImportException implements Exception {
  const BookImportException(this.message);

  /// Short, reader-facing reason, e.g. "it has no readable text".
  final String message;

  @override
  String toString() => message;
}

/// Chapters always start a new page and are paginated one at a time, so
/// very long ones are split (at a paragraph) to keep each quick to lay out.
const int kMaxChapterLength = 50000;

/// Tidies extracted text into paragraphs separated by one blank line.
///
/// Paragraphs are split at blank lines. Within a paragraph, single line
/// breaks are kept (verse, addresses); runs of spaces and tabs collapse.
/// Non-breaking spaces are kept: books use them on purpose.
String normalizeParagraphs(String text) {
  final paragraphs = <String>[];
  for (final block
      in text
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split(RegExp(r'\n[ \t\u00A0]*\n'))) {
    final lines = block
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isNotEmpty) paragraphs.add(lines.join('\n'));
  }
  return paragraphs.join('\n\n');
}

/// Splits any chapter longer than [maxLength] at paragraph breaks, so no
/// chapter (except one with a single giant paragraph) exceeds it.
List<String> splitLongChapters(
  List<String> chapters, {
  int maxLength = kMaxChapterLength,
}) {
  final result = <String>[];
  for (final chapter in chapters) {
    if (chapter.length <= maxLength) {
      result.add(chapter);
      continue;
    }
    final buffer = StringBuffer();
    for (final paragraph in chapter.split('\n\n')) {
      if (buffer.isNotEmpty &&
          buffer.length + paragraph.length + 2 > maxLength) {
        result.add(buffer.toString());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(paragraph);
    }
    if (buffer.isNotEmpty) result.add(buffer.toString());
  }
  return result;
}

/// A readable title from a file name: "the_time-machine.txt" becomes
/// "the time machine".
String titleFromFileName(String fileName) {
  var name = fileName.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  if (dot > 0) name = name.substring(0, dot);
  name = name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  return name.isEmpty ? 'Untitled' : name;
}

import 'dart:convert';
import 'dart:typed_data';

import 'parsed_book.dart';

/// Reads a plain-text book.
///
/// * Decodes UTF-8, falling back to Latin-1 for older files.
/// * Strips Project Gutenberg's licence header and footer, taking the title
///   and author from the header when it has them.
/// * Re-joins hard-wrapped lines into paragraphs, but keeps the line breaks
///   of short lines such as verse.
/// * Starts a new chapter at headings like "CHAPTER IV" or "Part Two".
ParsedBook parseTxt(String fileName, Uint8List bytes) {
  var text = _decode(bytes).replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  String? title;
  String? author;
  final start = RegExp(
    r'^\*{3}\s*START OF (THE|THIS) PROJECT GUTENBERG.*$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(text);
  if (start != null) {
    final header = text.substring(0, start.start);
    title = _headerField(header, 'Title');
    author = _headerField(header, 'Author');
    text = text.substring(start.end);
  }
  final end = RegExp(
    r'^\*{3}\s*END OF (THE|THIS) PROJECT GUTENBERG',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(text);
  if (end != null) text = text.substring(0, end.start);

  final paragraphs = _paragraphs(text);
  if (paragraphs.isEmpty) {
    throw const BookImportException('it has no readable text');
  }

  return ParsedBook(
    title: title ?? titleFromFileName(fileName),
    author: author ?? 'Unknown author',
    chapters: splitLongChapters(_chapters(paragraphs)),
  );
}

String _decode(Uint8List bytes) {
  var data = bytes;
  // Byte-order mark.
  if (data.length >= 3 &&
      data[0] == 0xEF &&
      data[1] == 0xBB &&
      data[2] == 0xBF) {
    data = Uint8List.sublistView(data, 3);
  }
  try {
    return utf8.decode(data);
  } on FormatException {
    return latin1.decode(data);
  }
}

String? _headerField(String header, String name) {
  final match = RegExp(
    '^$name:[ \\t]*(.+)\$',
    multiLine: true,
  ).firstMatch(header);
  final value = match?.group(1)?.trim();
  return (value == null || value.isEmpty) ? null : value;
}

/// Splits text into paragraphs, undoing hard wrapping.
List<String> _paragraphs(String text) {
  text = text.trim();
  final lines = text.split('\n');
  final nonBlank = lines.where((l) => l.trim().isNotEmpty).length;
  final blank = lines.length - nonBlank;

  // Some files put each paragraph on one line with no blank lines between.
  if (nonBlank > 0 && blank < nonBlank * 0.02) {
    return [
      for (final line in lines)
        if (line.trim().isNotEmpty) _collapse(line),
    ];
  }

  final paragraphs = <String>[];
  for (final block in text.split(RegExp(r'\n[ \t]*\n'))) {
    final blockLines = [
      for (final l in block.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    if (blockLines.isEmpty) continue;
    // Prose is wrapped at around 60-80 columns; verse lines are short.
    final wrapped =
        blockLines.length == 1 ||
        blockLines
                .take(blockLines.length - 1)
                .where((l) => l.length >= 50)
                .length >=
            (blockLines.length - 1) * 0.6;
    paragraphs.add(
      wrapped
          ? _collapse(blockLines.join(' '))
          : blockLines.map(_collapse).join('\n'),
    );
  }
  return paragraphs;
}

String _collapse(String s) => s.replaceAll(RegExp(r'[ \t]+'), ' ').trim();

final RegExp _chapterHeading = RegExp(
  r'^(chapter|book|part|letter|volume|act|canto|stave)\s+'
  r'([0-9]+|[ivxlcdm]+|one|two|three|four|five|six|seven|eight|nine|ten|'
  r'eleven|twelve|first|second|third|fourth|fifth|the\s+\w+)\b',
  caseSensitive: false,
);

/// Groups paragraphs into chapters, starting a new one at each heading.
List<String> _chapters(List<String> paragraphs) {
  final chapters = <List<String>>[[]];
  var length = 0;
  for (final p in paragraphs) {
    final isHeading = p.length <= 80 && _chapterHeading.hasMatch(p);
    // Only break once the current chapter has real content, so a table of
    // contents (a run of headings) stays together instead of becoming a
    // page per line.
    if (isHeading && length >= 600) {
      chapters.add([]);
      length = 0;
    }
    chapters.last.add(p);
    length += p.length;
  }
  return [
    for (final c in chapters)
      if (c.isNotEmpty) c.join('\n\n'),
  ];
}

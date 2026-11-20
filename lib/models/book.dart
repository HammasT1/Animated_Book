import 'dart:typed_data';

/// A book on the shelf: one of the bundled books, or one the reader imported
/// from a `.txt` or `.epub` file.
///
/// [id] is a stable key used to persist reading progress and bookmarks,
/// so it must not change between releases even if the title does.
///
/// The book's content is one continuous [text]; it is split into pages at
/// runtime to fit the screen and the reader's typography (see
/// `lib/reading/`). Positions are stored as character offsets into [text],
/// so they survive re-pagination.
class Book {
  final String id;
  final String title;
  final String author;

  /// Cover image bundled with the app, if any.
  final String? coverAsset;

  /// Cover image taken from an imported file, if any. A book with neither
  /// gets a generated cover.
  final Uint8List? coverImage;

  /// The source text in blocks, joined with blank lines to form [text].
  final List<String> sections;

  /// Whether each section is a chapter that starts on a fresh page, as in
  /// imported books. Otherwise (the bundled books) sections only exist to
  /// keep the source readable and to migrate positions saved by older
  /// versions, which stored a section index.
  final bool sectionsAreChapters;

  /// Imported by the reader (and so removable), rather than bundled.
  final bool isImported;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.sections,
    this.coverAsset,
    this.coverImage,
    this.sectionsAreChapters = false,
    this.isImported = false,
  });

  static const String paragraphBreak = '\n\n';

  static final Expando<String> _textCache = Expando('Book.text');

  /// The full text, paragraphs separated by [paragraphBreak]. Built once per
  /// book, since imported books can run to megabytes.
  String get text => _textCache[this] ??= sections.join(paragraphBreak);

  /// Character offset in [text] where section [index] begins.
  int sectionStart(int index) {
    var offset = 0;
    for (var i = 0; i < index && i < sections.length; i++) {
      offset += sections[i].length + paragraphBreak.length;
    }
    return offset;
  }

  /// Where each chapter begins in [text]; chapters always start a new page.
  List<int> get chapterStarts {
    if (!sectionsAreChapters || sections.isEmpty) return const [0];
    final starts = <int>[];
    var offset = 0;
    for (final section in sections) {
      starts.add(offset);
      offset += section.length + paragraphBreak.length;
    }
    return starts;
  }
}

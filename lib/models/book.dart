/// A book on the shelf.
///
/// [id] is a stable key used to persist reading progress and bookmarks,
/// so it must not change between releases even if the title does.
///
/// The book's content is one continuous [text]; it is split into pages at
/// runtime to fit the screen and the reader's typography (see
/// `lib/reading/pagination.dart`). Positions are stored as character
/// offsets into [text], so they survive re-pagination.
class Book {
  final String id;
  final String title;
  final String author;
  final String coverAsset;

  /// The source text in blocks, joined with blank lines to form [text].
  /// Block boundaries carry no meaning for layout; they only exist so the
  /// bundled books stay readable in source and so positions saved by older
  /// versions (which stored a block index) can be migrated.
  final List<String> sections;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverAsset,
    required this.sections,
  });

  static const String paragraphBreak = '\n\n';

  /// The full text, paragraphs separated by [paragraphBreak].
  String get text => sections.join(paragraphBreak);

  /// Character offset in [text] where section [index] begins.
  int sectionStart(int index) {
    var offset = 0;
    for (var i = 0; i < index && i < sections.length; i++) {
      offset += sections[i].length + paragraphBreak.length;
    }
    return offset;
  }
}

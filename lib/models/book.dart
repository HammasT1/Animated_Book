/// A book on the shelf.
///
/// [id] is a stable key used to persist reading progress and bookmarks,
/// so it must not change between releases even if the title does.
class Book {
  final String id;
  final String title;
  final String author;
  final String coverAsset;
  final List<String> pages;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverAsset,
    required this.pages,
  });
}

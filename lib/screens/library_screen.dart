import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library_store.dart';
import '../import/book_import.dart';
import '../models/book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/book_cover.dart';
import '../widgets/theme_toggle_button.dart';
import 'reader_screen.dart';

/// Swipeable shelf of covers with per-book reading progress, where the
/// reader can also add their own `.txt` and `.epub` books.
class BookLibraryScreen extends StatefulWidget {
  const BookLibraryScreen({super.key});

  @override
  State<BookLibraryScreen> createState() => _BookLibraryScreenState();
}

class _BookLibraryScreenState extends State<BookLibraryScreen> {
  late final PageController _shelfController;
  int _activeBookIndex = 0;
  bool _importing = false;

  List<Book> get _books => LibraryScope.read(context).books;

  @override
  void initState() {
    super.initState();
    // Each cover takes nearly the full width, with a sliver of the
    // neighbouring covers peeking in on either side.
    _shelfController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _shelfController.dispose();
    super.dispose();
  }

  void _openBook(int bookIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return BookReaderScreen(
            book: _books[bookIndex],
            heroTag: 'book_cover_$bookIndex',
          );
        },
        // The Hero on the cover handles the big visual move; the route just
        // needs a quick fade so it doesn't fight with the flight.
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  void _moveShelf(int delta) {
    _showBook((_activeBookIndex + delta).clamp(0, _books.length - 1));
  }

  void _showBook(int index) {
    if (index == _activeBookIndex || !_shelfController.hasClients) return;
    _shelfController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  // ---------------------------------------------------------------------------
  // Adding and removing books
  // ---------------------------------------------------------------------------

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Lets the reader pick a `.txt` or `.epub` file and puts it on the shelf.
  Future<void> _addBook() async {
    if (_importing) return;
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: 'Add a book',
        type: FileType.custom,
        allowedExtensions: kImportExtensions,
      );
    } catch (e) {
      _toast("Couldn't open the file picker.");
      return;
    }
    if (file == null || !mounted) return;
    final name = file.name;

    setState(() => _importing = true);
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final (book, alreadyThere) = await LibraryScope.read(
        context,
      ).importFile(name, bytes);
      if (!mounted) return;
      _toast(
        alreadyThere
            ? '"${book.title}" is already on your shelf'
            : 'Added "${book.title}"',
      );
      // Slide the shelf over to the book once it's been laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showBook(_books.indexWhere((b) => b.id == book.id));
      });
    } on BookImportException catch (e) {
      if (mounted) _toast('Couldn\'t add "$name": $e.');
    } catch (e) {
      if (mounted) _toast('Couldn\'t add "$name".');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// Asks, then takes an imported book off the shelf along with its
  /// reading position and bookmarks.
  Future<void> _removeBook(Book book) async {
    if (!book.isImported) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove book?'),
        content: Text(
          '"${book.title}" will be removed from your library, along with '
          'your place in it and its bookmarks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final library = LibraryScope.read(context);
    final state = AppStateScope.read(context);
    try {
      await library.remove(book.id);
    } catch (e) {
      if (mounted) _toast('Couldn\'t remove "${book.title}".');
      return;
    }
    state.forgetBook(book.id);
    if (!mounted) return;
    setState(() {
      _activeBookIndex = _activeBookIndex.clamp(0, _books.length - 1);
    });
    _toast('Removed "${book.title}"');
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final palette = ReaderPalette.of(context);
    final state = AppStateScope.of(context);
    final books = LibraryScope.of(context).books;
    if (_activeBookIndex >= books.length) _activeBookIndex = books.length - 1;
    final activeBook = books[_activeBookIndex];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _moveShelf(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _moveShelf(1),
        const SingleActivator(LogicalKeyboardKey.enter): () =>
            _openBook(_activeBookIndex),
        const SingleActivator(LogicalKeyboardKey.space): () =>
            _openBook(_activeBookIndex),
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): _addBook,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              _importing
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Add a book (.txt or .epub)',
                      onPressed: _addBook,
                      icon: Icon(
                        Icons.library_add_outlined,
                        color: palette.icon,
                      ),
                    ),
              const ThemeToggleButton(),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text('My Library', style: theme.textTheme.displayLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Swipe and tap a cover to start reading',
                          style: theme.textTheme.bodyLarge!.copyWith(
                            color: palette.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    height: screenSize.height * 0.68,
                    child: PageView.builder(
                      controller: _shelfController,
                      itemCount: books.length,
                      onPageChanged: (index) =>
                          setState(() => _activeBookIndex = index),
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return _ShelfCover(
                          book: book,
                          heroTag: 'book_cover_$index',
                          isCurrent: index == _activeBookIndex,
                          progress: _progressFor(state, book),
                          width: screenSize.width * 0.86,
                          height: screenSize.height * 0.64,
                          onTap: () => _openBook(index),
                          onLongPress: book.isImported
                              ? () => _removeBook(book)
                              : null,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      key: ValueKey<String>(activeBook.id),
                      children: [
                        Text(
                          activeBook.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeBook.author,
                          style: theme.textTheme.bodyLarge!.copyWith(
                            fontSize: 14,
                            color: palette.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ProgressSummary(
                          book: activeBook,
                          position: state.positionOf(activeBook.id),
                          onContinue: () => _openBook(_activeBookIndex),
                        ),
                        if (activeBook.isImported)
                          TextButton.icon(
                            onPressed: () => _removeBook(activeBook),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remove from library'),
                            style: TextButton.styleFrom(
                              foregroundColor: palette.muted,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 0..1 for a started book, null if never opened.
  double? _progressFor(AppState state, Book book) {
    final position = state.positionOf(book.id);
    if (position == null) return null;
    return readFraction(book, position);
  }
}

class _ShelfCover extends StatelessWidget {
  const _ShelfCover({
    required this.book,
    required this.heroTag,
    required this.isCurrent,
    required this.progress,
    required this.width,
    required this.height,
    required this.onTap,
    this.onLongPress,
  });

  final Book book;
  final String heroTag;
  final bool isCurrent;
  final double? progress;
  final double width;
  final double height;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isCurrent ? 1.0 : 0.88,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isCurrent ? 0.3 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The Hero carries the cover art from the shelf into the
                // reader: the "card grows into full screen" move.
                Hero(
                  tag: heroTag,
                  flightShuttleBuilder: _roundedShuttle,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: const Color(0xFF2C2420)),
                        BookCover(book: book),
                      ],
                    ),
                  ),
                ),

                // Thin progress strip along the bottom edge of the cover
                // (outside the Hero so it doesn't fly into the reader).
                if (progress != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        color: const Color(0xFFFFC107),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _roundedShuttle(
    BuildContext flightContext,
    Animation<double> heroAnimation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final isPush = direction == HeroFlightDirection.push;
    final radius = Tween<double>(begin: isPush ? 16 : 0, end: isPush ? 0 : 16);
    final curved = CurvedAnimation(
      parent: heroAnimation,
      curve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: heroAnimation,
      builder: (context, child) => ClipRRect(
        borderRadius: BorderRadius.circular(radius.evaluate(curved)),
        child: child,
      ),
      child: (isPush ? toContext : fromContext).widget,
    );
  }
}

/// How far through [book] the reader is, 0..1, counting the page on screen
/// as read. Pages depend on screen size and typography, so progress is
/// measured in characters rather than pages.
double readFraction(Book book, ReadingPosition position) {
  final length = book.text.length;
  if (length == 0) return 1;
  return (position.end / length).clamp(0.0, 1.0);
}

/// "Start reading" / "Continue · 42%" / "Finished · Read again" under the
/// title.
class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({
    required this.book,
    required this.position,
    required this.onContinue,
  });

  final Book book;
  final ReadingPosition? position;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final position = this.position;

    if (position == null) {
      return FilledButton.tonalIcon(
        onPressed: onContinue,
        icon: const Icon(Icons.menu_book, size: 18),
        label: const Text('Start reading'),
      );
    }

    final fraction = readFraction(book, position);
    final finished = fraction >= 1;
    return Column(
      children: [
        SizedBox(
          width: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              color: palette.dropCap,
              backgroundColor: palette.trayBorder,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: onContinue,
          icon: Icon(
            finished ? Icons.check_circle : Icons.play_arrow,
            size: 18,
          ),
          label: Text(
            finished
                ? 'Finished · Read again'
                : 'Continue · ${(fraction * 100).floor()}%',
          ),
        ),
      ],
    );
  }
}

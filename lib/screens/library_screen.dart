import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/library.dart';
import '../models/book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_toggle_button.dart';
import 'reader_screen.dart';

/// Swipeable shelf of covers with per-book reading progress.
class BookLibraryScreen extends StatefulWidget {
  const BookLibraryScreen({super.key, this.books = kLibrary});

  final List<Book> books;

  @override
  State<BookLibraryScreen> createState() => _BookLibraryScreenState();
}

class _BookLibraryScreenState extends State<BookLibraryScreen> {
  late final PageController _shelfController;
  int _activeBookIndex = 0;

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
            book: widget.books[bookIndex],
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
    final target = (_activeBookIndex + delta).clamp(0, widget.books.length - 1);
    if (target == _activeBookIndex) return;
    _shelfController.animateToPage(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final palette = ReaderPalette.of(context);
    final state = AppStateScope.of(context);
    final activeBook = widget.books[_activeBookIndex];

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
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: const [ThemeToggleButton()],
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
                      itemCount: widget.books.length,
                      onPageChanged: (index) =>
                          setState(() => _activeBookIndex = index),
                      itemBuilder: (context, index) {
                        final book = widget.books[index];
                        return _ShelfCover(
                          book: book,
                          heroTag: 'book_cover_$index',
                          isCurrent: index == _activeBookIndex,
                          progress: _progressFor(state, book),
                          width: screenSize.width * 0.86,
                          height: screenSize.height * 0.64,
                          onTap: () => _openBook(index),
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
                          lastPage: state.lastPage(activeBook.id),
                          onContinue: () => _openBook(_activeBookIndex),
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
    final last = state.lastPage(book.id);
    if (last == null) return null;
    return (last + 1) / book.pages.length;
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
  });

  final Book book;
  final String heroTag;
  final bool isCurrent;
  final double? progress;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isCurrent ? 1.0 : 0.88,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTap: onTap,
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
                        Image.asset(
                          book.coverAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: const Color(0xFF5D4037),
                                child: const Center(
                                  child: Icon(
                                    Icons.book,
                                    size: 48,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                        ),
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

/// "Not started" / "Page 2 of 3 · Continue" / "Finished" under the title.
class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({
    required this.book,
    required this.lastPage,
    required this.onContinue,
  });

  final Book book;
  final int? lastPage;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final total = book.pages.length;
    final last = lastPage;

    if (last == null) {
      return FilledButton.tonalIcon(
        onPressed: onContinue,
        icon: const Icon(Icons.menu_book, size: 18),
        label: const Text('Start reading'),
      );
    }

    final finished = last >= total - 1;
    return Column(
      children: [
        SizedBox(
          width: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (last + 1) / total,
              minHeight: 4,
              color: palette.dropCap,
              backgroundColor: palette.trayBorder,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: onContinue,
          icon: Icon(finished ? Icons.check_circle : Icons.play_arrow, size: 18),
          label: Text(
            finished
                ? 'Finished · Read again'
                : 'Continue · Page ${last + 1} of $total',
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const AnimatedBookApp());
}

/// ============================================================================
/// BOOK MODEL
/// ============================================================================
class Book {
  final String title;
  final String author;
  final String coverAsset;
  final List<String> pages;

  const Book({
    required this.title,
    required this.author,
    required this.coverAsset,
    required this.pages,
  });
}

/// ============================================================================
/// ROOT APP CONFIGURATION
/// ============================================================================
class AnimatedBookApp extends StatefulWidget {
  const AnimatedBookApp({super.key});

  @override
  State<AnimatedBookApp> createState() => _AnimatedBookAppState();
}

class _AnimatedBookAppState extends State<AnimatedBookApp> {
  bool _isDarkMode = false;

  // Real-time track of bookmarks: Key is book index, Value is Set of bookmarked page indices
  final Map<int, Set<int>> _bookmarkedPages = {
    0: {}, // Book 1 Bookmarks
    1: {}, // Book 2 Bookmarks
  };

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _toggleBookmark(int bookIndex, int pageIndex) {
    setState(() {
      final bookmarks = _bookmarkedPages[bookIndex] ?? {};
      if (bookmarks.contains(pageIndex)) {
        bookmarks.remove(pageIndex);
      } else {
        bookmarks.add(pageIndex);
      }
      _bookmarkedPages[bookIndex] = bookmarks;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Animated Book Reader',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4423),
          brightness: Brightness.light,
          surface: const Color(0xFFFAF8F3),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Serif',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C2420),
          ),
          headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2420),
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Serif',
            fontSize: 18,
            height: 1.8,
            color: Color(0xFF3A3633),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B7355),
          brightness: Brightness.dark,
          surface: const Color(0xFF1A1613),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Serif',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF5EFEB),
          ),
          headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE6DFDA),
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Serif',
            fontSize: 18,
            height: 1.8,
            color: Color(0xFFD5CFC9),
          ),
        ),
      ),
      home: BookLibraryScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
        bookmarkedPages: _bookmarkedPages,
        onToggleBookmark: _toggleBookmark,
      ),
    );
  }
}

/// ============================================================================
/// BOOK LIBRARY SCREEN (Swipeable Book Shelf)
/// ============================================================================
class BookLibraryScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Map<int, Set<int>> bookmarkedPages;
  final Function(int, int) onToggleBookmark;

  const BookLibraryScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.bookmarkedPages,
    required this.onToggleBookmark,
  });

  @override
  State<BookLibraryScreen> createState() => _BookLibraryScreenState();
}

class _BookLibraryScreenState extends State<BookLibraryScreen> {
  late PageController _shelfController;
  int _activeBookIndex = 0;

  // The 2 Custom Books utilizing your real templates and structured chapters
  final List<Book> _myLibrary = [
    Book(
      title: 'Kafka on the Shore',
      author: 'Haruki Murakami',
      coverAsset: 'assets/images/book_cover.jpg',
      pages: [
        '''The ancient library stood as a monument to human curiosity and imagination. Its walls were lined with countless volumes, each containing worlds waiting to be explored. The smell of aged paper mixed with leather bindings filled the air, creating an atmosphere of endless possibilities.

Every book was a gateway to another time, another place, another mind. The librarians who maintained this sacred space understood the profound responsibility they held: to preserve knowledge and foster wonder in those who entered.''',
        '''Chapter One: The Shoreline of Mind

The journey always begins with a single step, though few recognize it as such in the moment. Kafka had always loved books more than people, finding solace in their quiet companionship. On this particular autumn afternoon, as leaves swirled outside the library windows, he discovered something that would change everything.

It was a volume bound in unusual purple leather, its title written in faded silver ink. The book seemed to call to him, despite his rational mind suggesting it was merely another volume among thousands.''',
        '''The pages were thick and cream-colored, as if untouched by time. The typeface was elegant, reminiscent of manuscripts from centuries past. What struck her most was the personal nature of the marginalia—handwritten notes in the margins, passages underlined, thoughts recorded in the spaces between printed words.

Someone had loved this book deeply, engaging with it as a conversation partner rather than merely a consumer of text.''',
      ],
    ),
    Book(
      title: 'The Picture of Dorian Gray',
      author: 'Oscar Wilde',
      coverAsset: 'assets/images/fantasyfiction_book_cover_template.jpg',
      pages: [
        '''The studio was filled with the rich odour of roses, and when the light summer wind stirred amidst the trees of the garden, there came through the open door the heavy scent of the lilac, or the more delicate perfume of the pink-flowering thorn.

From the corner of the divan of Persian saddle-bags on which he was lying, smoking, as was his custom, innumerable cigarettes, Lord Henry Wotton could just catch the gleam of the honey-sweet and honey-coloured blossoms of a laburnum, whose tremulous branches seemed hardly able to bear the burden of a beauty so flamelike as theirs.''',
        '''Chapter One: The Artist's Vision

"It is your best work, Basil, the best thing you have ever done," said Lord Henry languidly. "You must certainly send it next year to the Grosvenor. The Academy is too large and too vulgar. Whenever I have gone there, there have been either so many people that I have not been able to see the pictures, which was dreadful, or so many pictures that I have not been able to see the people, which was even worse. The Grosvenor is really the only place."''',
        '''"I don't think I shall send it anywhere," the artist answered, tossing his head back in that odd way that used to make his friends laugh at him at Oxford. "No, I won't send it anywhere."

Lord Henry elevated his eyebrows and looked at him in amazement through the thin blue wreaths of smoke that curled up in such fanciful whorls from his heavy, opium-tainted cigarette.''',
      ],
    ),
    Book(
      title: 'The Secret Garden',
      author: 'Frances Hodgson Burnett',
      coverAsset: 'assets/images/book3_cover.jpg',
      pages: [
        '''When Mary Lennox was sent to Misselthwaite Manor to live with her uncle, everybody said she was the most disagreeable-looking child ever seen. It was true, too. She had a little thin face and a little thin body, thin light hair and a sour expression.

Her hair was yellow, and her face was yellow because she had been born in India and had always been ill in one way or another. She had not been actually interested in anybody or anything until the day the garden's secret began to unfold itself to her.''',
        '''Chapter One: The Locked Door

The manor stood upon the edge of the moor, gray stone walls rising against a sky that seemed always on the verge of rain. Mary had heard the servants whisper of a garden that had been locked for ten years, its key buried somewhere no one could find, its door hidden beneath a curtain of ivy grown thick and wild.

No one was allowed to speak of it. But curiosity, once planted in a lonely child's mind, tends to grow faster than any garden ever could.''',
        '''She found the key quite by accident, glinting faintly in the freshly turned earth where a robin had been scratching. Her fingers trembled as she closed around it, and for a long moment she simply stood there, listening to the wind moving through the bare branches overhead.

Some doors, once opened, cannot be closed again — not truly. And some gardens, once tended, have a way of tending back the one who found them.''',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Larger viewport fraction so each book cover takes up nearly the
    // full width of the screen, with just a sliver of the neighboring
    // covers peeking in on either side.
    _shelfController = PageController(viewportFraction: 0.92, initialPage: 0);
  }

  @override
  void dispose() {
    _shelfController.dispose();
    super.dispose();
  }

  void _navigateToReader(int bookIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return BookReaderScreen(
            book: _myLibrary[bookIndex],
            bookIndex: bookIndex,
            isDarkMode: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme,
            bookmarkedPages: widget.bookmarkedPages,
            onToggleBookmark: widget.onToggleBookmark,
          );
        },
        // The Hero on the cover image handles the big visual move on its
        // own; the route itself just needs a quick, unobtrusive fade so it
        // doesn't fight with the flight.
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: widget.isDarkMode ? Colors.amber : const Color(0xFF6B4423),
            ),
          ),
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
                      'Swipe and tap your favorite template to read',
                      style: theme.textTheme.bodyLarge!.copyWith(
                        color: widget.isDarkMode
                            ? const Color(0xFFCBB69B)
                            : const Color(0xFF8B7355),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Horizontal Swipeable Carousel for custom books — sized to
              // fill most of the available screen height.
              SizedBox(
                height: screenSize.height * 0.68,
                child: PageView.builder(
                  controller: _shelfController,
                  itemCount: _myLibrary.length,
                  onPageChanged: (index) {
                    setState(() {
                      _activeBookIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final book = _myLibrary[index];
                    final isCurrent = index == _activeBookIndex;

                    return AnimatedScale(
                      scale: isCurrent ? 1.0 : 0.88,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: GestureDetector(
                        onTap: () => _navigateToReader(index),
                        child: Center(
                          child: Container(
                            width: screenSize.width * 0.86,
                            height: screenSize.height * 0.64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isCurrent ? 0.3 : 0.1,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            // The Hero carries the cover art from the shelf
                            // straight into the reader — the classic
                            // "card grows into full screen" move.
                            child: Hero(
                              tag: 'book_cover_$index',
                              flightShuttleBuilder:
                                  (
                                  flightContext,
                                  heroAnimation,
                                  direction,
                                  fromContext,
                                  toContext,
                                  ) {
                                final radiusTween = Tween<double>(
                                  begin: direction == HeroFlightDirection.push
                                      ? 16
                                      : 0,
                                  end: direction == HeroFlightDirection.push
                                      ? 0
                                      : 16,
                                );
                                return AnimatedBuilder(
                                  animation: heroAnimation,
                                  builder: (context, child) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        radiusTween.evaluate(
                                          CurvedAnimation(
                                            parent: heroAnimation,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                      ),
                                      child: child,
                                    );
                                  },
                                  child:
                                  (direction == HeroFlightDirection.push
                                      ? toContext
                                      : fromContext)
                                      .widget,
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Fallback color
                                    Container(color: const Color(0xFF2C2420)),
                                    // The pristine book cover templates (no text overlay!)
                                    Image.asset(
                                      book.coverAsset,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: const Color(0xFF5D4037),
                                          child: const Center(
                                            child: Icon(
                                              Icons.book,
                                              size: 48,
                                              color: Colors.white54,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Active Book Metadata Indicator
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey<int>(_activeBookIndex),
                  children: [
                    Text(
                      _myLibrary[_activeBookIndex].title,
                      style: theme.textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _myLibrary[_activeBookIndex].author,
                      style: theme.textTheme.bodyLarge!.copyWith(
                        fontSize: 14,
                        color: const Color(0xFF8B7355),
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
    );
  }
}

/// ============================================================================
/// BOOK READER SCREEN (Bookmark Sync + Directional Page Flip)
/// ============================================================================
class BookReaderScreen extends StatefulWidget {
  final Book book;
  final int bookIndex;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Map<int, Set<int>> bookmarkedPages;
  final Function(int, int) onToggleBookmark;

  const BookReaderScreen({
    super.key,
    required this.book,
    required this.bookIndex,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.bookmarkedPages,
    required this.onToggleBookmark,
  });

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen>
    with TickerProviderStateMixin {
  late AnimationController _pageFlipController;
  late Animation<double> _pageFlipAnimation;

  // Drives the reader chrome (top bar, page card, nav tray) rising up and
  // fading in over the cover once the Hero flight has landed — the classic
  // "card expands, then content settles in" beat.
  late AnimationController _revealController;
  late Animation<double> _revealFade;
  late Animation<Offset> _revealSlide;
  late Animation<double> _scrimFade;

  int _currentPageIndex = 0;
  double _dragOffset = 0;
  bool _isDragging = false;

  // NEW: tracks which way the page is turning so the flip widget can
  // mirror the hinge side + rotation direction for a proper "back flip".
  bool _isFlippingForward = true;

  @override
  void initState() {
    super.initState();
    _pageFlipController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );

    _pageFlipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pageFlipController, curve: Curves.easeInOutQuad),
    );

    _revealController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scrimFade = CurvedAnimation(parent: _revealController, curve: Curves.easeOut);
    _revealFade = CurvedAnimation(
      parent: _revealController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _revealSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Let the Hero flight get moving first, then rise the content in —
    // this is what sells the "cover expands, book opens" feeling.
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _revealController.forward();
    });
  }

  @override
  void dispose() {
    _pageFlipController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-200.0, 200.0);

      // Live-update the flip direction while dragging so the preview
      // hinge/rotation matches which way the user is swiping.
      if (_dragOffset < 0) {
        _isFlippingForward = true; // swiping left -> next page
      } else if (_dragOffset > 0) {
        _isFlippingForward = false; // swiping right -> previous page
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    const dragThreshold = 70.0;
    if (_dragOffset.abs() > dragThreshold) {
      if (_dragOffset < 0 && _currentPageIndex < widget.book.pages.length - 1) {
        setState(() {
          _isFlippingForward = true;
        });
        _pageFlipController.forward(from: 0.0).then((_) {
          setState(() {
            _currentPageIndex++;
            _dragOffset = 0;
            _pageFlipController.value = 0.0;
          });
        });
      } else if (_dragOffset > 0 && _currentPageIndex > 0) {
        setState(() {
          _isFlippingForward = false;
        });
        _pageFlipController.forward(from: 0.0).then((_) {
          setState(() {
            _currentPageIndex--;
            _dragOffset = 0;
            _pageFlipController.value = 0.0;
          });
        });
      } else {
        _resetDrag();
      }
    } else {
      _resetDrag();
    }
  }

  void _resetDrag() {
    setState(() {
      _dragOffset = 0;
    });
  }

  void _goToNextPage() {
    if (_currentPageIndex < widget.book.pages.length - 1) {
      setState(() {
        _isFlippingForward = true;
      });
      _pageFlipController.forward(from: 0.0).then((_) {
        setState(() {
          _currentPageIndex++;
          _pageFlipController.value = 0.0;
        });
      });
    }
  }

  void _goToPreviousPage() {
    if (_currentPageIndex > 0) {
      setState(() {
        _isFlippingForward = false;
      });
      _pageFlipController.forward(from: 0.0).then((_) {
        setState(() {
          _currentPageIndex--;
          _pageFlipController.value = 0.0;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // Check if current page is in bookmarked collection
    final isPageBookmarked =
        widget.bookmarkedPages[widget.bookIndex]?.contains(_currentPageIndex) ??
            false;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // 1. The Hero cover that flew in from the shelf, filling the
          // whole screen — this is the visual anchor of the transition.
          Positioned.fill(
            child: Hero(
              tag: 'book_cover_${widget.bookIndex}',
              child: Image.asset(
                widget.book.coverAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: const Color(0xFF5D4037));
                },
              ),
            ),
          ),

          // 2. A scrim that grows in as the reader settles, so the cover
          // recedes into the background instead of just disappearing.
          Positioned.fill(
            child: FadeTransition(
              opacity: _scrimFade,
              child: Container(color: theme.colorScheme.surface),
            ),
          ),

          // 3. The reader chrome: rises up and fades in over the cover.
          FadeTransition(
            opacity: _revealFade,
            child: SlideTransition(
              position: _revealSlide,
              child: SafeArea(
                child: Column(
                  children: [
                    // Custom top bar (kept out of Scaffold.appBar so it can
                    // join the fade/rise instead of snapping in instantly).
                    Container(
                      color: widget.isDarkMode
                          ? const Color(0xFF26211D)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: theme.colorScheme.onSurface,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              widget.book.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall!.copyWith(
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Bookmark Page',
                            onPressed: () {
                              widget.onToggleBookmark(
                                widget.bookIndex,
                                _currentPageIndex,
                              );
                              setState(() {});
                            },
                            icon: Icon(
                              isPageBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: isPageBookmarked
                                  ? Colors.amber[700]
                                  : (widget.isDarkMode
                                  ? Colors.white70
                                  : const Color(0xFF6B4423)),
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onToggleTheme,
                            icon: Icon(
                              widget.isDarkMode
                                  ? Icons.light_mode
                                  : Icons.dark_mode,
                              color: widget.isDarkMode
                                  ? Colors.amber
                                  : const Color(0xFF6B4423),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: GestureDetector(
                        onHorizontalDragUpdate: _onHorizontalDragUpdate,
                        onHorizontalDragEnd: _onHorizontalDragEnd,
                        child: PageFlipWidget(
                          dragOffset: _dragOffset,
                          isDragging: _isDragging,
                          isFlippingForward: _isFlippingForward,
                          currentPage: widget.book.pages[_currentPageIndex],
                          nextPage:
                          _currentPageIndex < widget.book.pages.length - 1
                              ? widget.book.pages[_currentPageIndex + 1]
                              : '',
                          previousPage: _currentPageIndex > 0
                              ? widget.book.pages[_currentPageIndex - 1]
                              : '',
                          pageFlipAnimation: _pageFlipAnimation,
                          screenSize: screenSize,
                          isDarkMode: widget.isDarkMode,
                          isCurrentPageBookmarked: isPageBookmarked,
                        ),
                      ),
                    ),

                    // Reader Navigation Tray
                    Container(
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? const Color(0xFF201B18)
                            : Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: widget.isDarkMode
                                ? const Color(0xFF362E28)
                                : const Color(0xFFE8DDD0),
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _currentPageIndex > 0
                                ? _goToPreviousPage
                                : null,
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 20,
                            ),
                            color: _currentPageIndex > 0
                                ? const Color(0xFF8B7355)
                                : Colors.grey.withOpacity(0.3),
                          ),
                          Text(
                            'Page ${_currentPageIndex + 1} of ${widget.book.pages.length}',
                            style: theme.textTheme.bodyLarge!.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: widget.isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                          IconButton(
                            onPressed:
                            _currentPageIndex <
                                widget.book.pages.length - 1
                                ? _goToNextPage
                                : null,
                            icon: const Icon(Icons.arrow_forward_ios, size: 20),
                            color:
                            _currentPageIndex <
                                widget.book.pages.length - 1
                                ? const Color(0xFF8B7355)
                                : Colors.grey.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// PAGE FLIP WIDGET (Directional: forward flips left->right hinge-left,
/// backward flips mirror it hinge-right, with paper texture & bookmark ribbon)
/// ============================================================================
class PageFlipWidget extends StatelessWidget {
  final double dragOffset;
  final bool isDragging;
  final bool isFlippingForward;
  final String currentPage;
  final String nextPage;
  final String previousPage;
  final Animation<double> pageFlipAnimation;
  final Size screenSize;
  final bool isDarkMode;
  final bool isCurrentPageBookmarked;

  const PageFlipWidget({
    required this.dragOffset,
    required this.isDragging,
    required this.isFlippingForward,
    required this.currentPage,
    required this.nextPage,
    required this.previousPage,
    required this.pageFlipAnimation,
    required this.screenSize,
    required this.isDarkMode,
    required this.isCurrentPageBookmarked,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paperColor = isDarkMode ? const Color(0xFF2C2520) : Colors.white;

    // The underlay is whichever page gets revealed by the current
    // direction of travel: nextPage when moving forward, previousPage
    // when moving backward.
    final underlayPage = isFlippingForward ? nextPage : previousPage;
    final hingeAlignment = isFlippingForward
        ? Alignment.centerLeft
        : Alignment.centerRight;

    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Underlay Screen (Next or Previous Page Content, depending on direction)
          if (underlayPage.isNotEmpty)
            Card(
              color: paperColor,
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: isDarkMode ? 0.04 : 0.12,
                      child: Image.asset(
                        'assets/images/texture_bg.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildPageContent(underlayPage, theme),
                  ),
                ],
              ),
            ),

          // 2. Transformed Screen (Flipping active Page)
          AnimatedBuilder(
            animation: pageFlipAnimation,
            builder: (context, child) {
              final flipVal = pageFlipAnimation.value;
              final dragRatio = (dragOffset / 200.0).clamp(-1.0, 1.0);

              // Base magnitude of the flip (0 -> fully turned).
              double magnitude = flipVal * math.pi / 2;
              if (isDragging) {
                magnitude += dragRatio.abs() * 0.3;
              }
              magnitude = magnitude.clamp(0.0, math.pi / 2);

              // Forward flips rotate negative around the LEFT hinge
              // (page lifts on the right and turns away to the left).
              // Backward flips mirror this: rotate positive around the
              // RIGHT hinge (page lifts on the left and turns away to
              // the right) — giving a visually distinct "back flip".
              final angle = isFlippingForward ? -magnitude : magnitude;

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0009)
                  ..rotateY(angle),
                alignment: hingeAlignment,
                child: Card(
                  color: paperColor,
                  elevation: 8,
                  shadowColor: Colors.black26,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Paper Texture background
                      Positioned.fill(
                        child: Opacity(
                          opacity: isDarkMode ? 0.04 : 0.12,
                          child: Image.asset(
                            'assets/images/texture_bg.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                          ),
                        ),
                      ),

                      // Visual Red/Amber bookmark ribbon inside the page if bookmarked
                      if (isCurrentPageBookmarked)
                        Positioned(
                          right: 16,
                          top: 0,
                          child: Container(
                            width: 14,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),

                      // Turning simulation shade overlay — the shadow hugs
                      // whichever edge is lifting away (mirrored per direction).
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: magnitude > 0.05
                              ? LinearGradient(
                            begin: isFlippingForward
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            end: isFlippingForward
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            colors: [
                              Colors.black.withOpacity(0.08 * magnitude),
                              Colors.transparent,
                            ],
                          )
                              : null,
                        ),
                        padding: const EdgeInsets.all(24),
                        child: _buildPageContent(currentPage, theme),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(String pageText, ThemeData theme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: RichText(
        text: TextSpan(children: _buildFormattedText(pageText, theme)),
      ),
    );
  }

  List<InlineSpan> _buildFormattedText(String text, ThemeData theme) {
    final spans = <InlineSpan>[];
    final paragraphs = text.split('\n\n');

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      if (paragraph.trim().isEmpty) continue;

      final firstLetter = paragraph[0];
      final restOfParagraph = paragraph.substring(1);

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 2),
            child: Text(
              firstLetter,
              style: TextStyle(
                fontFamily: 'Serif',
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? const Color(0xFFCBB69B)
                    : const Color(0xFF6B4423),
                height: 0.9,
              ),
            ),
          ),
        ),
      );

      spans.add(
        TextSpan(text: restOfParagraph, style: theme.textTheme.bodyLarge),
      );

      if (i < paragraphs.length - 1) {
        spans.add(const TextSpan(text: '\n\n'));
      }
    }

    return spans;
  }
}
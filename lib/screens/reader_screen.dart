import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../reading/pagination.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/bookmarks_sheet.dart';
import '../widgets/page_flip.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/theme_toggle_button.dart';

/// Drag distance (px) past which releasing always turns the page.
const double _kDragThreshold = 70;

/// Fling speed (px/s) that turns the page even below [_kDragThreshold],
/// or cancels a turn when flung the opposite way.
const double _kFlickVelocity = 600;

/// Full-length page turn used by buttons, keys and the wheel.
const Duration _kFlipDuration = Duration(milliseconds: 650);

/// After a wheel-triggered turn, ignore further wheel events for this long so
/// trackpad momentum doesn't flip several pages at once.
const Duration _kWheelCooldown = Duration(milliseconds: 900);

class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({
    super.key,
    required this.book,
    required this.heroTag,
  });

  final Book book;
  final String heroTag;

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen>
    with TickerProviderStateMixin {
  /// 0 = page flat, 1 = page fully turned. Driven directly (no fixed curve)
  /// so a release can continue from the drag position at the fling's speed.
  late final AnimationController _flipController;

  // Reader chrome rises and fades in once the Hero flight has landed.
  late final AnimationController _revealController;
  late final Animation<double> _revealFade;
  late final Animation<Offset> _revealSlide;
  late final Animation<double> _scrimFade;

  /// The book's text and its pages for the current size and typography.
  late final String _text = widget.book.text;
  List<PageRange> _pages = const [PageRange(0, 0)];
  Object? _paginationKey;

  /// Character offset the reader is anchored to: the start of the page they
  /// turned to. When the text re-paginates, the reader lands on whichever
  /// new page holds this offset, so changing the font never loses the place.
  late int _anchor;
  int _currentPageIndex = 0;
  double _dragOffset = 0;
  bool _isDragging = false;
  bool _isFlippingForward = true;

  /// During a jump to a non-adjacent page (from the bookmarks list), the
  /// page revealed under the turning page; null for ordinary turns.
  int? _jumpTarget;
  DateTime _wheelLockedUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _hasNext => _currentPageIndex < _pages.length - 1;
  bool get _hasPrev => _currentPageIndex > 0;

  @override
  void initState() {
    super.initState();

    // Resume where the reader left off; a finished book starts over. The
    // book is recorded as opened once the first pagination has run.
    final position = AppStateScope.read(context).positionOf(widget.book.id);
    _anchor = (position == null || position.end >= _text.length)
        ? 0
        : position.start.clamp(0, _text.length);

    _flipController = AnimationController(
      vsync: this,
      duration: _kFlipDuration,
    );

    _revealController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scrimFade = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOut,
    );
    _revealFade = CurvedAnimation(
      parent: _revealController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _revealSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _revealController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    // Let the Hero flight get moving first, then rise the content in.
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _revealController.forward();
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  void _saveProgress() => AppStateScope.read(context).setPosition(
    widget.book.id,
    ReadingPosition(_anchor, _pages[_currentPageIndex].end),
  );

  // ---------------------------------------------------------------------------
  // Pagination
  // ---------------------------------------------------------------------------

  /// Re-splits the text into pages when the page area, typography or system
  /// text scale changes. Runs during layout (it needs the page size), so the
  /// top bar and nav tray, built earlier in the frame, are refreshed after.
  void _paginate(Size pageArea, PageTextStyle style, TextScaler textScaler) {
    final key = (pageArea, style.layoutKey, textScaler);
    if (key == _paginationKey) return;
    _paginationKey = key;

    _pages = paginate(
      text: _text,
      size: pageTextSize(pageArea),
      style: style,
      textScaler: textScaler,
    );
    _currentPageIndex = pageIndexFor(_pages, _anchor);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      _saveProgress();
    });
  }

  InlineSpan? _pageSpan(int index, PageTextStyle style) =>
      index >= 0 && index < _pages.length
      ? buildPageSpan(_text, _pages[index], style)
      : null;

  // ---------------------------------------------------------------------------
  // Page turning
  // ---------------------------------------------------------------------------

  /// Animates the current page away and advances. If the controller already
  /// holds partial progress (from a drag), the turn continues from there.
  ///
  /// [to] lands on any page in the direction of travel in a single turn
  /// (used by the bookmarks list); by default the turn moves one page.
  Future<void> _turnPage({
    required bool forward,
    int? to,
    Duration? duration,
    Curve curve = Curves.easeInOutQuad,
  }) async {
    if (_flipController.isAnimating || _isDragging) return;
    if (forward ? !_hasNext : !_hasPrev) return;

    final target = to ?? _currentPageIndex + (forward ? 1 : -1);
    // Remember the destination by offset, not index, in case the text is
    // re-paginated while the page is turning.
    final targetStart = _pages[target].start;
    setState(() {
      _isFlippingForward = forward;
      _jumpTarget = to;
    });
    await _flipController.animateTo(
      1,
      duration: duration ?? _kFlipDuration,
      curve: curve,
    );
    if (!mounted) return;

    setState(() {
      _anchor = targetStart;
      _currentPageIndex = pageIndexFor(_pages, _anchor);
      _jumpTarget = null;
    });
    _flipController.value = 0;
    _saveProgress();
  }

  /// Flips straight to [page], whichever direction it lies in.
  void _jumpToPage(int page) {
    if (page == _currentPageIndex || page < 0 || page >= _pages.length) return;
    _turnPage(forward: page > _currentPageIndex, to: page);
  }

  Future<void> _openBookmarks() async {
    final page = await showBookmarksSheet(
      context,
      bookId: widget.book.id,
      text: _text,
      pages: _pages,
      currentPage: _currentPageIndex,
    );
    if (page != null && mounted) _jumpToPage(page);
  }

  void _nextPage() => _turnPage(forward: true);
  void _previousPage() => _turnPage(forward: false);

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_flipController.isAnimating) return;
    setState(() {
      _isDragging = true;
      _dragOffset = (_dragOffset + details.delta.dx).clamp(
        -kMaxDragOffset,
        kMaxDragOffset,
      );
      // Swiping left previews the next page, right the previous one.
      if (_dragOffset < 0) {
        _isFlippingForward = true;
      } else if (_dragOffset > 0) {
        _isFlippingForward = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final velocity = details.primaryVelocity ?? 0;
    final forward = _dragOffset < 0;
    final canTurn = _dragOffset != 0 && (forward ? _hasNext : _hasPrev);

    // A quick flick in the drag direction turns the page even when short;
    // a quick flick back the other way cancels even a long drag.
    final flickedWith =
        velocity.abs() > _kFlickVelocity && (velocity < 0) == forward;
    final flickedAgainst =
        velocity.abs() > _kFlickVelocity && (velocity < 0) != forward;
    final commit =
        canTurn &&
        !flickedAgainst &&
        (_dragOffset.abs() > _kDragThreshold || flickedWith);

    // Hand the drag's tilt over to the controller so there's no visual jump.
    final start = dragOffsetToFlipProgress(_dragOffset);
    setState(() {
      _isDragging = false;
      _dragOffset = 0;
      _isFlippingForward = forward;
    });
    _flipController.value = start;

    if (commit) {
      // Faster flings finish faster; the remaining distance is shorter too.
      final speedUp = 1 + velocity.abs() / 1500;
      final ms = (_kFlipDuration.inMilliseconds * (1 - start) / speedUp)
          .clamp(160, _kFlipDuration.inMilliseconds)
          .round();
      _turnPage(
        forward: forward,
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
      );
    } else {
      _flipController.animateBack(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Mouse wheel / trackpad: if the page text can still scroll it gets the
  /// event first (Scrollable registers with the resolver before us); only at
  /// the top or bottom edge does the wheel turn the page.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      final delta = scroll.scrollDelta.dy != 0
          ? scroll.scrollDelta.dy
          : scroll.scrollDelta.dx;
      if (delta.abs() < 4) return;

      final now = DateTime.now();
      if (now.isBefore(_wheelLockedUntil) || _flipController.isAnimating) {
        return;
      }
      if (delta > 0 ? !_hasNext : !_hasPrev) return;

      _wheelLockedUntil = now.add(_kWheelCooldown);
      _turnPage(forward: delta > 0);
    });
  }

  void _toggleBookmark() {
    final page = _pages[_currentPageIndex];
    AppStateScope.read(
      context,
    ).toggleBookmark(widget.book.id, page.start, page.end);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ReaderPalette.of(context);
    final state = AppStateScope.of(context);
    final pageTextStyle = PageTextStyle(
      fontFamily: state.font.family,
      fontSize: state.fontSize,
      lineHeight: state.lineHeight,
      ink: palette.ink,
      dropCapColor: palette.dropCap,
    );
    bool isBookmarked(PageRange page) =>
        state.hasBookmarkIn(widget.book.id, page.start, page.end);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): _nextPage,
        const SingleActivator(LogicalKeyboardKey.pageDown): _nextPage,
        const SingleActivator(LogicalKeyboardKey.space): _nextPage,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _previousPage,
        const SingleActivator(LogicalKeyboardKey.pageUp): _previousPage,
        const SingleActivator(LogicalKeyboardKey.space, shift: true):
            _previousPage,
        const SingleActivator(LogicalKeyboardKey.keyB): _toggleBookmark,
        const SingleActivator(LogicalKeyboardKey.keyB, shift: true):
            _openBookmarks,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Stack(
            children: [
              // 1. The Hero cover that flew in from the shelf.
              Positioned.fill(
                child: Hero(
                  tag: widget.heroTag,
                  child: Image.asset(
                    widget.book.coverAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: const Color(0xFF5D4037)),
                  ),
                ),
              ),

              // 2. Scrim that grows in so the cover recedes into the background.
              Positioned.fill(
                child: FadeTransition(
                  opacity: _scrimFade,
                  child: Container(color: theme.colorScheme.surface),
                ),
              ),

              // 3. Reader chrome rises and fades in over the cover.
              FadeTransition(
                opacity: _revealFade,
                child: SlideTransition(
                  position: _revealSlide,
                  child: SafeArea(
                    child: Column(
                      children: [
                        _buildTopBar(
                          theme,
                          palette,
                          isBookmarked(_pages[_currentPageIndex]),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              _paginate(
                                constraints.biggest,
                                pageTextStyle,
                                MediaQuery.textScalerOf(context),
                              );
                              return _buildPage(pageTextStyle, isBookmarked);
                            },
                          ),
                        ),
                        _buildNavTray(theme, palette),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(
    PageTextStyle style,
    bool Function(PageRange page) isBookmarked,
  ) {
    final jump = _jumpTarget;
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: PageFlipWidget(
          dragOffset: _dragOffset,
          isDragging: _isDragging,
          isFlippingForward: _isFlippingForward,
          currentPage: _pageSpan(_currentPageIndex, style)!,
          // During a jump the page revealed underneath is the destination.
          nextPage: _pageSpan(
            jump != null && _isFlippingForward ? jump : _currentPageIndex + 1,
            style,
          ),
          previousPage: _pageSpan(
            jump != null && !_isFlippingForward ? jump : _currentPageIndex - 1,
            style,
          ),
          flipProgress: _flipController,
          isCurrentPageBookmarked: isBookmarked(_pages[_currentPageIndex]),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    ThemeData theme,
    ReaderPalette palette,
    bool isPageBookmarked,
  ) {
    return Container(
      color: palette.bar,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to library',
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              widget.book.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall!.copyWith(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Reading settings',
            onPressed: () => showReaderSettingsSheet(context),
            icon: Icon(Icons.text_fields, color: palette.icon),
          ),
          IconButton(
            tooltip: 'Bookmarks (Shift+B)',
            onPressed: _openBookmarks,
            icon: Icon(Icons.bookmarks_outlined, color: palette.icon),
          ),
          IconButton(
            tooltip: isPageBookmarked ? 'Remove bookmark (B)' : 'Bookmark (B)',
            onPressed: _toggleBookmark,
            icon: Icon(
              isPageBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isPageBookmarked ? Colors.amber[700] : palette.icon,
            ),
          ),
          const ThemeToggleButton(),
        ],
      ),
    );
  }

  Widget _buildNavTray(ThemeData theme, ReaderPalette palette) {
    final disabled = Colors.grey.withValues(alpha: 0.3);
    return Container(
      decoration: BoxDecoration(
        color: palette.tray,
        border: Border(top: BorderSide(color: palette.trayBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: _hasPrev ? _previousPage : null,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: _hasPrev ? palette.muted : disabled,
          ),
          Text(
            'Page ${_currentPageIndex + 1} of ${_pages.length}',
            style: theme.textTheme.bodyLarge!.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: palette.ink.withValues(alpha: 0.75),
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: _hasNext ? _nextPage : null,
            icon: const Icon(Icons.arrow_forward_ios, size: 20),
            color: _hasNext ? palette.muted : disabled,
          ),
        ],
      ),
    );
  }
}

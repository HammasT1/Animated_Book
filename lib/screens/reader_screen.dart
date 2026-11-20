import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../feedback/page_turn_feedback.dart';
import '../reading/book_pagination.dart';
import '../reading/pagination.dart';
import '../widgets/book_cover.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/bookmarks_sheet.dart';
import '../widgets/page_flip.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/spread_flip.dart';
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
  /// Pages are identified by their character range, never by index, since
  /// a long book is still being paginated in the background while it's read.
  late final String _text = widget.book.text;
  BookPagination? _pagination;
  Object? _paginationKey;
  int _paginationGeneration = 0;

  /// Character offset the reader is anchored to: the start of the page they
  /// turned to. When the text re-paginates, the reader lands on whichever
  /// new page holds this offset, so changing the font never loses the place.
  late int _anchor;

  /// The page on screen; in a two-page spread, the left page.
  PageRange _page = const PageRange(0, 0);

  /// Whether the reading area is wide enough for two pages side by side.
  bool _isSpread = false;
  double _dragOffset = 0;
  bool _isDragging = false;
  bool _isFlippingForward = true;

  /// During a jump to a non-adjacent page (from the bookmarks list), the
  /// page revealed under the turning page; null for ordinary turns.
  PageRange? _jumpTarget;
  DateTime _wheelLockedUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// Where a forward or backward turn lands: the next page, or in a spread
  /// the left page of the next spread.
  PageRange? get _nextPageRange =>
      _isSpread ? _pagination?.spreadAfter(_page) : _pagination?.after(_page);
  PageRange? get _previousPageRange =>
      _isSpread ? _pagination?.spreadBefore(_page) : _pagination?.before(_page);

  /// The right page of the spread on screen (null when it's blank, or when
  /// showing a single page).
  PageRange? get _rightPage => _isSpread ? _pagination?.rightOf(_page) : null;

  /// Everything on screen: the page, or both pages of the spread.
  PageRange get _onScreen => PageRange(_page.start, (_rightPage ?? _page).end);

  /// The page (or spread's left page) that holds [offset].
  PageRange _locate(int offset) =>
      _isSpread ? _pagination!.spreadAt(offset) : _pagination!.pageAt(offset);
  bool get _hasNext => _nextPageRange != null;
  bool get _hasPrev => _previousPageRange != null;

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
    _paginationGeneration++; // stops background pagination
    _flipController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  void _saveProgress() => AppStateScope.read(
    context,
  ).setPosition(widget.book.id, ReadingPosition(_anchor, _onScreen.end));

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

    _isSpread = useTwoPageSpread(pageArea);
    final pagination = _pagination = BookPagination(
      text: _text,
      chapterStarts: widget.book.chapterStarts,
      size: _isSpread ? spreadPageTextSize(pageArea) : pageTextSize(pageArea),
      style: style,
      textScaler: textScaler,
    );
    _page = _locate(_anchor);

    final generation = ++_paginationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      _saveProgress();
      _paginateInBackground(pagination, generation);
    });
  }

  /// Paginates the remaining chapters one per frame interval, skipping any
  /// interval in which something is animating (a page turn, the Hero), then
  /// refreshes the page numbers.
  ///
  /// Deliberately not `SchedulerBinding.scheduleTask(..., Priority.idle)`:
  /// while an animation runs, that re-polls with zero-length timers, which
  /// spins the CPU on devices and never settles under a test's fake clock.
  Future<void> _paginateInBackground(
    BookPagination pagination,
    int generation,
  ) async {
    while (!pagination.isComplete) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted || generation != _paginationGeneration) return;
      if (SchedulerBinding.instance.transientCallbackCount > 0) continue;
      pagination.step();
    }
    setState(() {});
  }

  InlineSpan? _pageSpan(PageRange? page, PageTextStyle style) =>
      page == null ? null : buildPageSpan(_text, page, style);

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
    PageRange? to,
    Duration? duration,
    Curve curve = Curves.easeInOutQuad,
  }) async {
    if (_flipController.isAnimating || _isDragging) return;
    final target = to ?? (forward ? _nextPageRange : _previousPageRange);
    if (target == null) return;

    // Remember the destination by offset, in case the text is re-paginated
    // while the page is turning.
    final targetStart = target.start;
    final state = AppStateScope.read(context);
    final feedback = PageTurnFeedbackScope.of(context);
    if (state.turnSound) feedback.turnStarted();
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
      _page = _locate(_anchor);
      _jumpTarget = null;
    });
    _flipController.value = 0;
    _saveProgress();
    if (state.haptics) feedback.turnLanded();
  }

  /// Flips straight to the page holding [offset], whichever way it lies.
  void _jumpToOffset(int offset) {
    final pagination = _pagination;
    if (pagination == null) return;
    final page = _locate(offset);
    if (page == _page) return;
    _turnPage(forward: page.start > _page.start, to: page);
  }

  Future<void> _openBookmarks() async {
    final pagination = _pagination;
    if (pagination == null) return;
    final offset = await showBookmarksSheet(
      context,
      bookId: widget.book.id,
      text: _text,
      pagination: pagination,
      currentPage: _onScreen,
    );
    if (offset != null && mounted) _jumpToOffset(offset);
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

  void _toggleBookmark() => AppStateScope.read(
    context,
  ).toggleBookmark(widget.book.id, _onScreen.start, _onScreen.end);

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
                  child: BookCover(book: widget.book),
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
                        _buildTopBar(theme, palette, isBookmarked(_onScreen)),
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
        child: _isSpread
            ? _buildSpread(style, isBookmarked)
            : PageFlipWidget(
                dragOffset: _dragOffset,
                isDragging: _isDragging,
                isFlippingForward: _isFlippingForward,
                currentPage: _pageSpan(_page, style)!,
                // During a jump the page revealed underneath is the destination.
                nextPage: _pageSpan(
                  jump != null && _isFlippingForward ? jump : _nextPageRange,
                  style,
                ),
                previousPage: _pageSpan(
                  jump != null && !_isFlippingForward
                      ? jump
                      : _previousPageRange,
                  style,
                ),
                flipProgress: _flipController,
                isCurrentPageBookmarked: isBookmarked(_page),
                turnStyle: AppStateScope.of(context).turnStyle,
              ),
      ),
    );
  }

  Widget _buildSpread(
    PageTextStyle style,
    bool Function(PageRange page) isBookmarked,
  ) {
    final pagination = _pagination!;
    final jump = _jumpTarget;
    // During a jump the spread revealed underneath is the destination.
    final next = jump != null && _isFlippingForward ? jump : _nextPageRange;
    final previous = jump != null && !_isFlippingForward
        ? jump
        : _previousPageRange;
    final right = _rightPage;
    return SpreadFlipWidget(
      left: _pageSpan(_page, style),
      right: _pageSpan(right, style),
      nextLeft: _pageSpan(next, style),
      nextRight: _pageSpan(
        next == null ? null : pagination.rightOf(next),
        style,
      ),
      previousLeft: _pageSpan(previous, style),
      previousRight: _pageSpan(
        previous == null ? null : pagination.rightOf(previous),
        style,
      ),
      flipProgress: _flipController,
      dragOffset: _dragOffset,
      isDragging: _isDragging,
      isFlippingForward: _isFlippingForward,
      isLeftBookmarked: isBookmarked(_page),
      isRightBookmarked: right != null && isBookmarked(right),
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

  /// "Page 12 of 340" (or "Pages 12–13 of 340" in a spread), or how far
  /// through the book while a long book is still being paginated.
  String get _pageLabel {
    final pagination = _pagination;
    final index = pagination?.indexOf(_page);
    final count = pagination?.pageCount;
    if (index != null && count != null) {
      return _rightPage != null
          ? 'Pages ${index + 1}\u2013${index + 2} of $count'
          : 'Page ${index + 1} of $count';
    }
    final end = _onScreen.end;
    final percent = _text.isEmpty ? 100 : (end * 100 ~/ _text.length);
    return '$percent%';
  }

  Widget _buildNavTray(ThemeData theme, ReaderPalette palette) {
    final disabled = Colors.grey.withValues(alpha: 0.3);
    final hasPrev = _hasPrev;
    final hasNext = _hasNext;
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
            onPressed: hasPrev ? _previousPage : null,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: hasPrev ? palette.muted : disabled,
          ),
          Text(
            _pageLabel,
            style: theme.textTheme.bodyLarge!.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: palette.ink.withValues(alpha: 0.75),
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: hasNext ? _nextPage : null,
            icon: const Icon(Icons.arrow_forward_ios, size: 20),
            color: hasNext ? palette.muted : disabled,
          ),
        ],
      ),
    );
  }
}

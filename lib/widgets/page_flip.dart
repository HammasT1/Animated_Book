import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_theme.dart';
import 'page_curl.dart';

/// How far (in px) a drag can travel before the preview stops growing.
const double kMaxDragOffset = 200;

/// Space between the edge of the page area and the text on each side:
/// outer padding (16) + card margin (4) + text padding (24).
const double kPageTextInset = 44;

/// The box the text of a page is set in, given the whole page area.
Size pageTextSize(Size pageArea) => Size(
  math.max(0, pageArea.width - 2 * kPageTextInset),
  math.max(0, pageArea.height - 2 * kPageTextInset),
);

/// Extra tilt (radians) the page picks up at [kMaxDragOffset] while dragging.
const double kDragTilt = 0.3;

/// Converts a live drag offset into the equivalent flip progress (0..1), so a
/// release can continue the animation from exactly where the finger left it.
double dragOffsetToFlipProgress(double dragOffset) {
  final ratio = (dragOffset.abs() / kMaxDragOffset).clamp(0.0, 1.0);
  return (ratio * kDragTilt / (math.pi / 2)).clamp(0.0, 1.0);
}

/// A turning page: the current page leaves either by curling away like
/// paper ([PageTurnStyle.curl]) or by swinging on its hinge like a card
/// ([PageTurnStyle.flip]), revealing the next or previous page beneath.
///
/// Forward turns hinge on the left edge, backward turns on the right. Shows
/// paper texture and a bookmark ribbon.
///
/// Pages arrive as styled text already cut to fit (see `buildPageSpan`);
/// a null [nextPage] or [previousPage] means there is none.
class PageFlipWidget extends StatefulWidget {
  final double dragOffset;
  final bool isDragging;
  final bool isFlippingForward;
  final InlineSpan currentPage;
  final InlineSpan? nextPage;
  final InlineSpan? previousPage;

  /// 0 = page flat, 1 = page fully turned away.
  final Animation<double> flipProgress;
  final bool isCurrentPageBookmarked;
  final PageTurnStyle turnStyle;

  const PageFlipWidget({
    super.key,
    required this.dragOffset,
    required this.isDragging,
    required this.isFlippingForward,
    required this.currentPage,
    required this.nextPage,
    required this.previousPage,
    required this.flipProgress,
    required this.isCurrentPageBookmarked,
    this.turnStyle = PageTurnStyle.curl,
  });

  @override
  State<PageFlipWidget> createState() => _PageFlipWidgetState();
}

class _PageFlipWidgetState extends State<PageFlipWidget> {
  /// Wraps the flat current page so it can be captured for the curl.
  final GlobalKey _boundaryKey = GlobalKey();

  /// A picture of the flat current page, bent by [PageCurlPainter] while
  /// the page curls. Captured after any frame in which the page changed.
  ui.Image? _snapshot;
  Object? _snapshotKey;
  Size? _snapshotSize;

  /// What the page looks like now; the snapshot is stale if it differs.
  Object? _pageKey;
  bool _captureScheduled = false;

  /// Whether the snapshot shows the page as it looks now. A size change is
  /// caught after layout, by the next capture.
  bool get _snapshotIsFresh => _snapshot != null && _snapshotKey == _pageKey;

  @override
  void dispose() {
    _snapshot?.dispose();
    super.dispose();
  }

  /// Captures the flat page after this frame has painted, if it changed.
  void _scheduleCapture() {
    if (widget.turnStyle != PageTurnStyle.curl || _captureScheduled) return;
    _captureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureScheduled = false;
      if (!mounted) return;
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.hasSize) return;
      if (_snapshotIsFresh && _snapshotSize == boundary.size) return;
      // Only the flat, visible page is worth capturing. If a turn is under
      // way, the next rebuild (when it ends) will try again.
      if (widget.flipProgress.value != 0 || widget.isDragging) return;
      try {
        final image = boundary.toImageSync(
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
        );
        _snapshot?.dispose();
        _snapshot = image;
        _snapshotKey = _pageKey;
        _snapshotSize = boundary.size;
      } catch (_) {
        // No snapshot means the page falls back to the flip for this turn.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    _pageKey = Object.hash(
      widget.currentPage,
      widget.isCurrentPageBookmarked,
      palette.paper,
      palette.textureOpacity,
      MediaQuery.devicePixelRatioOf(context),
    );
    _scheduleCapture();

    final forward = widget.isFlippingForward;
    // The underlay is whichever page gets revealed by the current direction
    // of travel: nextPage when moving forward, previousPage when moving back.
    final underlayPage = forward ? widget.nextPage : widget.previousPage;

    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Underlay page (next or previous, depending on direction).
          if (underlayPage != null)
            Card(
              margin: const EdgeInsets.all(4),
              color: palette.paper,
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  _PaperTexture(opacity: palette.textureOpacity),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _PageText(text: underlayPage),
                  ),
                ],
              ),
            ),

          // 2. The page that is turning.
          AnimatedBuilder(
            animation: widget.flipProgress,
            builder: (context, text) {
              double magnitude = widget.flipProgress.value * math.pi / 2;
              if (widget.isDragging) {
                final dragRatio = (widget.dragOffset / kMaxDragOffset).clamp(
                  -1.0,
                  1.0,
                );
                magnitude += dragRatio.abs() * kDragTilt;
              }
              magnitude = magnitude.clamp(0.0, math.pi / 2);

              if (widget.turnStyle == PageTurnStyle.flip) {
                return _flipTransform(
                  magnitude,
                  _pageCard(palette, magnitude, text!),
                );
              }

              // Curl: the live page stays in place (hidden while curling) so
              // it can be captured again; the painter bends its snapshot.
              final progress = magnitude / (math.pi / 2);
              final curling = progress > 0 && _snapshotIsFresh;
              final page = Opacity(
                opacity: curling ? 0 : 1,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: _pageCard(palette, 0, text!),
                ),
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Without a snapshot yet, fall back to the flip.
                  progress > 0 && !curling
                      ? _flipTransform(magnitude, page)
                      : page,
                  if (curling)
                    CustomPaint(
                      painter: PageCurlPainter(
                        image: _snapshot!,
                        progress: progress,
                        forward: forward,
                        paperColor: palette.paper,
                        // Light ink on dark paper shows through more.
                        backOpacity:
                            Theme.of(context).brightness == Brightness.dark
                            ? 0.96
                            : 0.88,
                      ),
                    ),
                ],
              );
            },
            // Built once per page, not once per animation frame.
            child: _PageText(text: widget.currentPage),
          ),
        ],
      ),
    );
  }

  /// Swings [child] around the hinge: negative around the LEFT edge going
  /// forward, mirrored around the RIGHT edge going back.
  Widget _flipTransform(double magnitude, Widget child) {
    final forward = widget.isFlippingForward;
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0009)
        ..rotateY(forward ? -magnitude : magnitude),
      alignment: forward ? Alignment.centerLeft : Alignment.centerRight,
      child: child,
    );
  }

  /// The current page on its card. [magnitude] (the flip angle) darkens the
  /// edge that is lifting away.
  Widget _pageCard(ReaderPalette palette, double magnitude, Widget text) {
    final forward = widget.isFlippingForward;
    return Card(
      margin: const EdgeInsets.all(4),
      color: palette.paper,
      elevation: 8,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          _PaperTexture(opacity: palette.textureOpacity),

          if (widget.isCurrentPageBookmarked)
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

          // Shade hugging whichever edge is lifting away.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: magnitude > 0.05
                  ? LinearGradient(
                      begin: forward
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      end: forward
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      colors: [
                        Colors.black.withValues(alpha: 0.08 * magnitude),
                        Colors.transparent,
                      ],
                    )
                  : null,
            ),
            padding: const EdgeInsets.all(24),
            child: text,
          ),
        ],
      ),
    );
  }
}

class _PaperTexture extends StatelessWidget {
  const _PaperTexture({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Opacity(
        opacity: opacity,
        child: Image.asset(
          'assets/images/texture_bg.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Page body. Pagination already sized the text to fit, so the scroll view
/// is only a safety net (e.g. if a font hasn't finished loading yet).
class _PageText extends StatelessWidget {
  const _PageText({required this.text});

  final InlineSpan text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Text.rich(text),
    );
  }
}

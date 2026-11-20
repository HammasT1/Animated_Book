import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How far (in px) a drag can travel before the preview stops growing.
const double kMaxDragOffset = 200;

/// Extra tilt (radians) the page picks up at [kMaxDragOffset] while dragging.
const double kDragTilt = 0.3;

/// Converts a live drag offset into the equivalent flip progress (0..1), so a
/// release can continue the animation from exactly where the finger left it.
double dragOffsetToFlipProgress(double dragOffset) {
  final ratio = (dragOffset.abs() / kMaxDragOffset).clamp(0.0, 1.0);
  return (ratio * kDragTilt / (math.pi / 2)).clamp(0.0, 1.0);
}

/// Directional 3D page turn: forward flips hinge on the left edge, backward
/// flips mirror it on the right. Shows paper texture and a bookmark ribbon.
class PageFlipWidget extends StatelessWidget {
  final double dragOffset;
  final bool isDragging;
  final bool isFlippingForward;
  final String currentPage;
  final String nextPage;
  final String previousPage;

  /// 0 = page flat, 1 = page fully turned away.
  final Animation<double> flipProgress;
  final bool isCurrentPageBookmarked;
  final TextStyle textStyle;

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
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    // The underlay is whichever page gets revealed by the current direction
    // of travel: nextPage when moving forward, previousPage when moving back.
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
          // 1. Underlay page (next or previous, depending on direction).
          if (underlayPage.isNotEmpty)
            Card(
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
                    child: _PageText(
                      text: underlayPage,
                      style: textStyle,
                      dropCapColor: palette.dropCap,
                    ),
                  ),
                ],
              ),
            ),

          // 2. The page that is turning.
          AnimatedBuilder(
            animation: flipProgress,
            builder: (context, child) {
              double magnitude = flipProgress.value * math.pi / 2;
              if (isDragging) {
                final dragRatio = (dragOffset / kMaxDragOffset).clamp(
                  -1.0,
                  1.0,
                );
                magnitude += dragRatio.abs() * kDragTilt;
              }
              magnitude = magnitude.clamp(0.0, math.pi / 2);

              // Forward flips rotate negative around the LEFT hinge; backward
              // flips mirror this around the RIGHT hinge.
              final angle = isFlippingForward ? -magnitude : magnitude;

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0009)
                  ..rotateY(angle),
                alignment: hingeAlignment,
                child: Card(
                  color: palette.paper,
                  elevation: 8,
                  shadowColor: Colors.black26,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      _PaperTexture(opacity: palette.textureOpacity),

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

                      // Shade hugging whichever edge is lifting away.
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
                                    Colors.black.withValues(
                                      alpha: 0.08 * magnitude,
                                    ),
                                    Colors.transparent,
                                  ],
                                )
                              : null,
                        ),
                        padding: const EdgeInsets.all(24),
                        child: child,
                      ),
                    ],
                  ),
                ),
              );
            },
            // Built once per page, not once per animation frame.
            child: _PageText(
              text: currentPage,
              style: textStyle,
              dropCapColor: palette.dropCap,
            ),
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

/// Page body with an illuminated drop cap at the start of every paragraph.
class _PageText extends StatelessWidget {
  const _PageText({
    required this.text,
    required this.style,
    required this.dropCapColor,
  });

  final String text;
  final TextStyle style;
  final Color dropCapColor;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Text.rich(TextSpan(children: _buildSpans())),
    );
  }

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    final paragraphs = text.split('\n\n');
    final dropCapSize = (style.fontSize ?? 18) * 2.33;

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      if (paragraph.trim().isEmpty) continue;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 2),
            child: Text(
              paragraph[0],
              style: TextStyle(
                fontFamily: 'Serif',
                fontSize: dropCapSize,
                fontWeight: FontWeight.bold,
                color: dropCapColor,
                height: 0.9,
              ),
            ),
          ),
        ),
      );
      spans.add(TextSpan(text: paragraph.substring(1), style: style));

      if (i < paragraphs.length - 1) {
        spans.add(const TextSpan(text: '\n\n'));
      }
    }
    return spans;
  }
}

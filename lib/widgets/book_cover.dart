import 'package:flutter/material.dart';

import '../models/book.dart';

/// A book's cover: its bundled art, the image from its EPUB, or (for books
/// without one) a generated leather binding with the title stamped on it.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final generated = GeneratedCover(title: book.title, author: book.author);
    final asset = book.coverAsset;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => generated,
      );
    }
    final image = book.coverImage;
    if (image != null) {
      return Image.memory(
        image,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => generated,
      );
    }
    return generated;
  }
}

/// A leather binding with a gilt frame, title and author. The leather colour
/// is picked from the title, so each book keeps its own look.
class GeneratedCover extends StatelessWidget {
  const GeneratedCover({super.key, required this.title, required this.author});

  final String title;
  final String author;

  static const List<Color> _leathers = [
    Color(0xFF6B4423), // leather
    Color(0xFF5D4037), // mocha
    Color(0xFF3E4A3D), // bottle green
    Color(0xFF4A2C3A), // oxblood
    Color(0xFF2E3B4E), // navy
    Color(0xFF7A4E2A), // tan
  ];
  static const Color _gilt = Color(0xFFE2C48A);
  static const double _designWidth = 300;
  static const double _designHeight = 450;

  @override
  Widget build(BuildContext context) {
    final hash = title.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0xFFFF);
    final leather = _leathers[hash % _leathers.length];

    // Laid out once at a fixed design size, then scaled to fill (cropping
    // a little if needed), so it reads the same on the shelf and full-screen
    // behind the reader, at any aspect ratio, without ever overflowing.
    const w = _designWidth;
    const inset = w * 0.07;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _designWidth,
        height: _designHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(leather, Colors.white, 0.12)!,
                leather,
                Color.lerp(leather, Colors.black, 0.35)!,
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Spine shadow along the left edge.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: w * 0.06,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x66000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(inset),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _gilt.withValues(alpha: 0.7),
                      width: w * 0.008 + 0.5,
                    ),
                    borderRadius: BorderRadius.circular(w * 0.02),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(inset * 0.9),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        Icon(
                          Icons.auto_stories,
                          color: _gilt.withValues(alpha: 0.85),
                          size: w * 0.1,
                        ),
                        SizedBox(height: w * 0.06),
                        Flexible(
                          flex: 5,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Serif',
                              fontWeight: FontWeight.bold,
                              fontSize: w * 0.095,
                              height: 1.15,
                              color: _gilt,
                            ),
                          ),
                        ),
                        SizedBox(height: w * 0.04),
                        Container(
                          width: w * 0.2,
                          height: 1,
                          color: _gilt.withValues(alpha: 0.6),
                        ),
                        SizedBox(height: w * 0.04),
                        Text(
                          author,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Serif',
                            fontSize: w * 0.055,
                            color: _gilt.withValues(alpha: 0.85),
                          ),
                        ),
                        const Spacer(flex: 3),
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
}

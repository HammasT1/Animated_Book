import 'package:flutter/material.dart';

/// The three paper styles a reader can pick from.
enum ReaderTheme {
  light('Light'),
  sepia('Sepia'),
  dark('Dark');

  const ReaderTheme(this.label);
  final String label;

  bool get isDark => this == ReaderTheme.dark;
}

/// The two typefaces bundled with the app (see pubspec.yaml).
enum ReaderFont {
  serif('Serif', 'Serif'),
  sans('Sans', 'Sanseriffic');

  const ReaderFont(this.label, this.family);
  final String label;
  final String family;
}

/// How a page leaves when it is turned.
enum PageTurnStyle {
  /// The free edge bends around a cylinder and folds over, like paper.
  curl('Curl', Icons.auto_stories),

  /// The whole page swings around its hinge like a stiff card.
  flip('Flip', Icons.flip);

  const PageTurnStyle(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// App-specific colours that don't map cleanly onto a Material ColorScheme.
///
/// Registered as a [ThemeExtension] so switching between light, sepia and
/// dark cross-fades smoothly through MaterialApp's built-in AnimatedTheme.
@immutable
class ReaderPalette extends ThemeExtension<ReaderPalette> {
  final Color surface;
  final Color paper;
  final Color bar;
  final Color tray;
  final Color trayBorder;
  final Color ink;
  final Color heading;
  final Color dropCap;
  final Color icon;
  final Color muted;
  final double textureOpacity;

  const ReaderPalette({
    required this.surface,
    required this.paper,
    required this.bar,
    required this.tray,
    required this.trayBorder,
    required this.ink,
    required this.heading,
    required this.dropCap,
    required this.icon,
    required this.muted,
    required this.textureOpacity,
  });

  static const light = ReaderPalette(
    surface: Color(0xFFFAF8F3),
    paper: Colors.white,
    bar: Colors.white,
    tray: Colors.white,
    trayBorder: Color(0xFFE8DDD0),
    ink: Color(0xFF3A3633),
    heading: Color(0xFF2C2420),
    dropCap: Color(0xFF6B4423),
    icon: Color(0xFF6B4423),
    muted: Color(0xFF8B7355),
    textureOpacity: 0.12,
  );

  static const sepia = ReaderPalette(
    surface: Color(0xFFEFE4CC),
    paper: Color(0xFFF6EEDC),
    bar: Color(0xFFF6EEDC),
    tray: Color(0xFFF6EEDC),
    trayBorder: Color(0xFFDCCBAA),
    ink: Color(0xFF5B4636),
    heading: Color(0xFF3E2C1C),
    dropCap: Color(0xFF7A4E2A),
    icon: Color(0xFF7A4E2A),
    muted: Color(0xFF8B7355),
    textureOpacity: 0.16,
  );

  static const dark = ReaderPalette(
    surface: Color(0xFF1A1613),
    paper: Color(0xFF2C2520),
    bar: Color(0xFF26211D),
    tray: Color(0xFF201B18),
    trayBorder: Color(0xFF362E28),
    ink: Color(0xFFD5CFC9),
    heading: Color(0xFFF5EFEB),
    dropCap: Color(0xFFCBB69B),
    icon: Colors.white70,
    muted: Color(0xFFCBB69B),
    textureOpacity: 0.04,
  );

  static ReaderPalette forTheme(ReaderTheme theme) => switch (theme) {
    ReaderTheme.light => light,
    ReaderTheme.sepia => sepia,
    ReaderTheme.dark => dark,
  };

  static ReaderPalette of(BuildContext context) =>
      Theme.of(context).extension<ReaderPalette>() ?? light;

  @override
  ReaderPalette copyWith({
    Color? surface,
    Color? paper,
    Color? bar,
    Color? tray,
    Color? trayBorder,
    Color? ink,
    Color? heading,
    Color? dropCap,
    Color? icon,
    Color? muted,
    double? textureOpacity,
  }) {
    return ReaderPalette(
      surface: surface ?? this.surface,
      paper: paper ?? this.paper,
      bar: bar ?? this.bar,
      tray: tray ?? this.tray,
      trayBorder: trayBorder ?? this.trayBorder,
      ink: ink ?? this.ink,
      heading: heading ?? this.heading,
      dropCap: dropCap ?? this.dropCap,
      icon: icon ?? this.icon,
      muted: muted ?? this.muted,
      textureOpacity: textureOpacity ?? this.textureOpacity,
    );
  }

  @override
  ReaderPalette lerp(ReaderPalette? other, double t) {
    if (other == null) return this;
    return ReaderPalette(
      surface: Color.lerp(surface, other.surface, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      bar: Color.lerp(bar, other.bar, t)!,
      tray: Color.lerp(tray, other.tray, t)!,
      trayBorder: Color.lerp(trayBorder, other.trayBorder, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      heading: Color.lerp(heading, other.heading, t)!,
      dropCap: Color.lerp(dropCap, other.dropCap, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      textureOpacity:
          textureOpacity + (other.textureOpacity - textureOpacity) * t,
    );
  }
}

/// Builds the Material theme for a given paper style.
ThemeData buildAppTheme(ReaderTheme readerTheme) {
  final palette = ReaderPalette.forTheme(readerTheme);
  final brightness = readerTheme.isDark ? Brightness.dark : Brightness.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: readerTheme.isDark
          ? const Color(0xFF8B7355)
          : const Color(0xFF6B4423),
      brightness: brightness,
      surface: palette.surface,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Serif',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: palette.heading,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: palette.heading,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Serif',
        fontSize: 18,
        height: 1.8,
        color: palette.ink,
      ),
    ),
    extensions: [palette],
  );
}

<div align="center">

<img src="assets/readme/banner.svg" alt="Animated Book — a 3D page-flipping reader built with Flutter" width="100%"/>

<a href="https://github.com/HammasT1/Animated_Book">
  <img src="https://readme-typing-svg.demolab.com?font=Playfair+Display&weight=600&size=24&duration=2600&pause=900&color=8B7355&center=true&vCenter=true&width=680&lines=Turn+the+page%2C+feel+the+paper.;Flick+fast+%E2%80%94+the+page+follows+your+finger.;Light%2C+sepia+or+candlelit+dark.;Your+size%2C+your+spacing%2C+your+typeface.;Close+the+book.+It+remembers+your+page.;Hand-crafted+motion+in+pure+Flutter." alt="Typing tagline"/>
</a>

<br/>

<img src="https://img.shields.io/badge/Flutter-3.x-6B4423?style=for-the-badge&logo=flutter&logoColor=FAF8F3&labelColor=2C2420"/>
<img src="https://img.shields.io/badge/Dart-3.9-8B7355?style=for-the-badge&logo=dart&logoColor=FAF8F3&labelColor=2C2420"/>
<img src="https://img.shields.io/badge/Material-3-CBB69B?style=for-the-badge&logo=materialdesign&logoColor=FAF8F3&labelColor=2C2420"/>
<img src="https://img.shields.io/badge/Android%20%C2%B7%20Web%20%C2%B7%20Windows-5D4037?style=for-the-badge&labelColor=2C2420"/>
<br/>
<img src="https://img.shields.io/badge/Saved%20with-shared__preferences-7A4E2A?style=for-the-badge&logo=databricks&logoColor=FAF8F3&labelColor=2C2420"/>
<img src="https://img.shields.io/github/stars/HammasT1/Animated_Book?style=for-the-badge&color=FFC107&labelColor=2C2420&logo=github"/>
<a href="https://github.com/HammasT1/Animated_Book/actions/workflows/build-apk.yml"><img src="https://img.shields.io/github/actions/workflow/status/HammasT1/Animated_Book/build-apk.yml?style=for-the-badge&label=APK%20Build&logo=githubactions&logoColor=FAF8F3&color=6B4423&labelColor=2C2420"/></a>

<br/><br/>

<b>
<a href="#-about">About</a> ·
<a href="#-whats-new">What's New</a> ·
<a href="#-preview">Preview</a> ·
<a href="#-features">Features</a> ·
<a href="#%EF%B8%8F-shortcuts">Shortcuts</a> ·
<a href="#-under-the-hood">Under the Hood</a> ·
<a href="#-getting-started">Getting Started</a> ·
<a href="#%EF%B8%8F-roadmap">Roadmap</a>
</b>

</div>

<img src="assets/readme/divider.svg" width="100%"/>

## 📖 About

**Animated Book** is a Flutter reading experience that treats every page like real paper.
Browse a swipeable shelf of leather-bound covers, tap one to watch it **expand into the reader through a Hero transition**, then **drag or flick to turn pages** with a perspective-correct 3D hinge that follows your finger.

Pick **light, sepia or candlelit dark** paper, set the **text size, line spacing and typeface** you like, and close the app whenever you want: your **page, bookmarks and settings are waiting** when you come back.

<img src="assets/readme/divider.svg" width="100%"/>

## 🆕 What's New

> [!TIP]
> **v1.1** is the reader's biggest update yet: a modular codebase, persistent state, a reading-settings panel, velocity-aware flicks and full keyboard & mouse support.

### 🌗 Paper & type, your way
Tap **Aa** in the reader to open the settings sheet. Every change applies live to the page behind it and cross-fades smoothly between themes.

<img src="assets/readme/themes.svg" width="100%" alt="Animated demo of the reading settings: the page switches between light, sepia and dark while the text grows"/>

### 👆 Flicks that feel physical
A short, fast swipe now turns the page, a quick flick back cancels it, and the turn **continues from the exact angle your finger let go** instead of restarting flat.

<img src="assets/readme/flick.svg" width="100%" alt="Animated comparison: a quick 40 px flick turns the page, a slow 40 px drag snaps back"/>

### 🔖 Pick up where you left off
Every cover shows how far through the book you are, and opening a book drops you on the sentence you were reading, even after changing the text size or rotating the screen. Bookmarks, theme and typography are saved the moment they change.

<img src="assets/readme/progress.svg" width="100%" alt="Animated covers showing Start reading, Continue · 67%, and Finished · Read again"/>

### ⌨️ Made for desktop & web too
Turn pages from the keyboard, bookmark with <kbd>B</kbd>, close with <kbd>Esc</kbd>. The scroll wheel reads long pages first and only turns the page at the edge.

<img src="assets/readme/keyboard.svg" width="100%" alt="Animated keyboard showing the reader shortcuts"/>

<img src="assets/readme/divider.svg" width="100%"/>

## 🎬 Preview

<div align="center">

<table>
  <tr>
    <td align="center" width="33%">
      <img src="assets/images/Home_Screen.png" width="240" alt="Library screen"/><br/>
      <sub><b>📚 My Library</b><br/>Swipeable book carousel</sub>
    </td>
    <td align="center" width="33%">
      <img src="assets/images/AnimatedBook-GIF.gif" width="240" alt="Animated demo"/><br/>
      <sub><b>🎞️ Live Demo</b><br/>Hero open &amp; page flip</sub>
    </td>
    <td align="center" width="33%">
      <img src="assets/images/Book_animation.png" width="240" alt="Reader screen"/><br/>
      <sub><b>📖 Reader</b><br/>3D page turn &amp; drop caps</sub>
    </td>
  </tr>
</table>

</div>

<img src="assets/readme/divider.svg" width="100%"/>

## ✨ Features

<table>
  <tr>
    <td width="50%" valign="top">

### 🎞️ Motion
- **3D page flip** built on `Matrix4` perspective transforms
- **Drag-to-flip** with a live preview that tracks your swipe
- **Velocity-aware flicks**: fast swipes turn, fast reverse swipes cancel
- **Seamless hand-off**: the release continues from the drag angle
- **Direction-aware hinge**: flips forward *and* backward
- **Hero cover transition** and a **staged reveal** of the reader chrome

    </td>
    <td width="50%" valign="top">

### 📚 Reading
- **Swipeable library** of book covers via `PageView`
- **Continue reading** with progress on every cover
- **Per-page bookmarks** with a ribbon on the page
- **Bookmarks list** with a preview of each page and one-flip jump-to-page
- **Illuminated drop caps** that scale with your text size
- **Pages that fit your screen**: the text re-flows into pages whenever the window, text size, spacing or typeface changes, and you stay on the same sentence
- **Page counter** (`Page x of y`) in the nav tray

    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">

### 🎨 Design
- **Light · Sepia · Dark** paper, cross-faded via `ThemeExtension`
- **Reader settings**: text size 14–28, line spacing 1.4–2.2
- **Serif or Sans** typeface, both bundled with the app
- Textured paper, layered shadows and gradients

    </td>
    <td width="50%" valign="top">

### 💾 Remembers everything
- Last page read in **every book**
- **Bookmarks**, paper style and typography
- Written through to `shared_preferences` instantly
- Survives the app being closed at any moment

    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">

### ⌨️ Keyboard & mouse
- Arrows, <kbd>Space</kbd>, <kbd>PgUp</kbd>/<kbd>PgDn</kbd> turn pages
- <kbd>B</kbd> bookmarks, <kbd>Esc</kbd> closes the book
- Scroll wheel turns pages
- Browse the shelf with <kbd>←</kbd>/<kbd>→</kbd>, open with <kbd>Enter</kbd>

    </td>
    <td width="50%" valign="top">

### ⚡ Performance & quality
- Pure Flutter, **zero third-party animation packages**
- Page text is built once per page, not once per frame
- Smooth on 60 Hz and 120 Hz displays
- Widget & unit tests for flips, flicks and persistence

    </td>
  </tr>
</table>

<img src="assets/readme/divider.svg" width="100%"/>

## ⌨️ Shortcuts

<div align="center">

| Where | Keys | Action |
|:--|:--|:--|
| 📖 Reader | <kbd>→</kbd> · <kbd>PgDn</kbd> · <kbd>Space</kbd> | Next page |
| 📖 Reader | <kbd>←</kbd> · <kbd>PgUp</kbd> · <kbd>Shift</kbd>+<kbd>Space</kbd> | Previous page |
| 📖 Reader | <kbd>B</kbd> | Toggle bookmark |
| 📖 Reader | <kbd>Shift</kbd>+<kbd>B</kbd> | Open the bookmarks list |
| 📖 Reader | <kbd>Esc</kbd> | Back to library |
| 📖 Reader | 🖱️ Scroll wheel | Turn the page |
| 📚 Library | <kbd>←</kbd> · <kbd>→</kbd> | Browse books |
| 📚 Library | <kbd>Enter</kbd> · <kbd>Space</kbd> | Open the selected book |

</div>

<img src="assets/readme/divider.svg" width="100%"/>

## 🎨 Colour Palette

<div align="center">
<img src="assets/readme/palette.svg" width="90%" alt="Leather #6B4423, Walnut #8B7355, Mocha #5D4037, Sand #CBB69B, Parchment #FAF8F3, Espresso #2C2420, Night #1A1613, Amber #FFC107"/>
</div>

| Token | Hex | Where it's used |
|:--|:--:|:--|
| ![](https://img.shields.io/badge/%20-6B4423?style=flat-square) **Leather** | `#6B4423` | Light theme seed, drop caps, icons |
| ![](https://img.shields.io/badge/%20-8B7355?style=flat-square) **Walnut** | `#8B7355` | Dark theme seed, secondary accents |
| ![](https://img.shields.io/badge/%20-CBB69B?style=flat-square) **Sand** | `#CBB69B` | Dark mode drop caps & highlights |
| ![](https://img.shields.io/badge/%20-FAF8F3?style=flat-square) **Parchment** | `#FAF8F3` | Light surface / paper |
| ![](https://img.shields.io/badge/%20-F6EEDC?style=flat-square) **Sepia** | `#F6EEDC` | Sepia paper |
| ![](https://img.shields.io/badge/%20-5B4636?style=flat-square) **Sepia Ink** | `#5B4636` | Sepia body text |
| ![](https://img.shields.io/badge/%20-2C2420?style=flat-square) **Espresso** | `#2C2420` | Headings (light) · paper (dark) |
| ![](https://img.shields.io/badge/%20-1A1613?style=flat-square) **Night** | `#1A1613` | Dark surface |
| ![](https://img.shields.io/badge/%20-FFC107?style=flat-square) **Amber** | `#FFC107` | Progress bars, sun icon in dark mode |

<img src="assets/readme/divider.svg" width="100%"/>

## 🧠 Under the Hood

```mermaid
flowchart LR
    P[("💾 shared_preferences")] <--> S["🧠 AppState<br/>ChangeNotifier"]
    S --> Q["AppStateScope<br/>InheritedNotifier"]
    Q --> M["🎨 MaterialApp<br/>ThemeExtension palette"]
    M --> L["📚 BookLibraryScreen<br/>PageView + progress"]
    L -- "tap cover · Hero" --> R["📖 BookReaderScreen"]
    R --> G["📐 paginate()<br/>TextPainter line metrics"]
    R --> F["🎞️ PageFlipWidget<br/>Matrix4 3D hinge"]
    R --> T["Aa ReaderSettingsSheet"]
    R -. "position · bookmark offsets" .-> S
    T -. "theme · size · font" .-> S

    classDef leather fill:#6B4423,stroke:#CBB69B,color:#FAF8F3
    classDef paper fill:#FAF8F3,stroke:#8B7355,color:#2C2420
    class L,R,F,G leather
    class P,S,Q,M,T paper
```

<details>
<summary><b>🔍 How the page flip works</b></summary>
<br/>

1. A horizontal drag accumulates `_dragOffset` (clamped to ±200 px) and tilts the page up to 0.3 rad as a live preview.
2. The sign of the offset sets `_isFlippingForward`, which moves the hinge to the left or right edge.
3. The rotation is applied with `Matrix4.identity()..setEntry(3, 2, 0.0009)..rotateY(angle)` for real perspective.
4. On release, the drag's tilt is converted into controller progress (`dragOffsetToFlipProgress`) so the animation **continues from where the finger left off**.
5. The page turns if the drag passed **70 px** *or* was flung faster than **600 px/s** in the same direction. A fast fling the other way cancels. Faster flings finish faster.
6. Otherwise the page eases back flat in 220 ms instead of snapping.
7. The page underneath (next or previous) is already rendered, so the reveal never stutters.

</details>

<details>
<summary><b>📐 How pages are cut to fit</b></summary>
<br/>

1. Each book is one continuous text. When the reader knows its page size (from a `LayoutBuilder`), `paginate()` lays the text out with a `TextPainter` in exactly the style the page will use.
2. `computeLineMetrics()` finds the last whole line that fits the page height, and `getLineBoundary()` turns it into a character offset. That offset ends the page, so pages break between words or after a hyphen.
3. Only about one page of text is laid out at a time, so the cost grows with the length of the book, not with the size of each layout.
4. A paragraph that carries over from the previous page doesn't get a second drop cap.
5. Progress and bookmarks are stored as **character offsets**, not page numbers. After a re-flow the reader opens whichever new page holds their offset, so they never lose their place.
6. Colours are left out of the pagination key, so a theme cross-fade doesn't re-paginate on every frame.

</details>

<details>
<summary><b>🖱️ How the scroll wheel knows when to turn</b></summary>
<br/>

Flutter's `PointerSignalResolver` gives a scroll event to the **first** widget that claims it, and a `Scrollable` only claims it when it can actually move. Pages are sized to fit, so the wheel normally turns the page straight away. If a page ever does overflow (for example while a font is still loading), the text scrolls first and the page turns at the edge. A 900 ms cooldown stops trackpad momentum from flipping several pages at once.

</details>

<details>
<summary><b>🧰 Flutter APIs used</b></summary>
<br/>

`AnimationController` · `Tween` · `CurvedAnimation` · `Interval` · `AnimatedBuilder` · `Transform` · `Matrix4` · `Hero` · `PageView.builder` · `GestureDetector` · `Listener` · `PointerSignalResolver` · `CallbackShortcuts` · `Focus` · `ChangeNotifier` · `InheritedNotifier` · `ListenableBuilder` · `ThemeExtension` · `SegmentedButton` · `Slider` · `showModalBottomSheet` · `Text.rich` · `TextPainter` · `LayoutBuilder` · `ColorScheme.fromSeed` · `shared_preferences`

</details>

<img src="assets/readme/divider.svg" width="100%"/>

## 📲 Download

Ready-to-install APKs are built automatically by GitHub Actions:

- **Stable:** grab the latest APK from [**Releases**](https://github.com/HammasT1/Animated_Book/releases/latest)
- **Latest build:** open the most recent [**Build APK** run](https://github.com/HammasT1/Animated_Book/actions/workflows/build-apk.yml) and download the `AnimatedBook-APKs` artifact

> [!NOTE]
> Not sure which file to pick? Use **`arm64-v8a`** for most modern phones, or **`universal`** if you're unsure.

## 🚀 Getting Started

> [!IMPORTANT]
> **Prerequisites:** Flutter 3.x (Dart ≥ 3.9) and Android Studio or VS Code. Run `flutter doctor` to check your setup.

```bash
# 1 · Clone
git clone https://github.com/HammasT1/Animated_Book.git
cd Animated_Book

# 2 · Install dependencies
flutter pub get

# 3 · Run
flutter run
```

<details>
<summary><b>📦 Build, test &amp; device commands</b></summary>
<br/>

| Task | Command |
|:--|:--|
| List devices | `flutter devices` |
| Run on a device | `flutter run -d <device_id>` |
| Analyze | `flutter analyze` |
| Run tests | `flutter test` |
| Debug APK | `flutter build apk` |
| Release APK | `flutter build apk --release` |
| Web build | `flutter build web` |
| Windows build | `flutter build windows` |

</details>

### 🗂️ Project Structure

```text
Animated_Book/
├── lib/
│   ├── main.dart                      # Loads saved state, builds MaterialApp
│   ├── models/book.dart               # Book model with a stable id
│   ├── data/library.dart              # The books on the shelf
│   ├── state/app_state.dart           # Settings, bookmarks & progress (persisted)
│   ├── theme/app_theme.dart           # Light / sepia / dark palettes & fonts
│   ├── screens/
│   │   ├── library_screen.dart        # Cover carousel + continue reading
│   │   └── reader_screen.dart         # Gestures, flicks, keyboard & wheel
│   └── widgets/
│       ├── page_flip.dart             # 3D hinge, paper texture, drop caps
│       ├── reader_settings_sheet.dart # The "Aa" panel
│       └── theme_toggle_button.dart   # Sun / moon toggle
├── test/widget_test.dart              # Flip, flick, resume & persistence tests
├── assets/
│   ├── fonts/                         # Serif & Sanseriffic typefaces
│   ├── images/                        # Covers, paper texture, screenshots
│   └── readme/                        # Animated SVGs for this README
└── pubspec.yaml
```

<img src="assets/readme/divider.svg" width="100%"/>

## 🗺️ Roadmap

- [x] Modular codebase with a single app state
- [x] Saved bookmarks, theme and reading progress
- [x] Continue reading from the library
- [x] Reader settings: paper, size, spacing, typeface
- [x] Velocity-aware flicks
- [x] Keyboard & mouse controls
- [x] Pages re-flow to fit the screen and your typography
- [ ] Two-page spread in landscape and on desktop
- [ ] Page-curl effect with a shadow along the fold
- [x] Bookmarks list with jump-to-page
- [ ] Load real books from files (`.txt` / `.epub`)
- [ ] Highlights and margin notes

## 🤝 Contributing

Contributions, ideas and bug reports are welcome.

1. **Fork** the repository
2. Create a branch: `git checkout -b feature/amazing-idea`
3. Check your change: `flutter analyze && flutter test`
4. Commit: `git commit -m "Add amazing idea"`
5. Push: `git push origin feature/amazing-idea`
6. Open a **Pull Request** 🎉

## ⭐ Support

If this project helped or inspired you, please give it a **star**. It helps others find it.

<div align="center">

<br/>

**Crafted with ☕ & 🤎 by [Muhammad Hammas Rasheed](https://github.com/HammasT1)**

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:1A1613,50:6B4423,100:CBB69B&height=120&section=footer" width="100%"/>

</div>

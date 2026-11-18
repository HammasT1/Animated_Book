<div align="center">

<img src="assets/readme/banner.svg" alt="Animated Book — a 3D page-flipping reader built with Flutter" width="100%"/>

<a href="https://github.com/HammasT1/Animated_Book">
  <img src="https://readme-typing-svg.demolab.com?font=Playfair+Display&weight=600&size=24&duration=2800&pause=900&color=8B7355&center=true&vCenter=true&width=640&lines=Turn+the+page%2C+feel+the+paper.;Drag-to-flip+with+a+live+3D+hinge.;Parchment+by+day%2C+candlelight+by+night.;Hand-crafted+motion+in+pure+Flutter." alt="Typing tagline"/>
</a>

<br/>

<img src="https://img.shields.io/badge/Flutter-3.x-6B4423?style=for-the-badge&logo=flutter&logoColor=FAF8F3&labelColor=2C2420"/>
<img src="https://img.shields.io/badge/Dart-3.9-8B7355?style=for-the-badge&logo=dart&logoColor=FAF8F3&labelColor=2C2420"/>
<img src="https://img.shields.io/badge/Material-3-CBB69B?style=for-the-badge&logo=materialdesign&logoColor=FAF8F3&labelColor=2C2420"/>
<img src="https://img.shields.io/badge/Android%20%C2%B7%20Web%20%C2%B7%20Windows-5D4037?style=for-the-badge&labelColor=2C2420"/>
<img src="https://img.shields.io/github/stars/HammasT1/Animated_Book?style=for-the-badge&color=FFC107&labelColor=2C2420&logo=github"/>
<a href="https://github.com/HammasT1/Animated_Book/actions/workflows/build-apk.yml"><img src="https://img.shields.io/github/actions/workflow/status/HammasT1/Animated_Book/build-apk.yml?style=for-the-badge&label=APK%20Build&logo=githubactions&logoColor=FAF8F3&color=6B4423&labelColor=2C2420"/></a>

<br/><br/>

<b>
<a href="#-preview">Preview</a> ·
<a href="#-features">Features</a> ·
<a href="#-colour-palette">Palette</a> ·
<a href="#-under-the-hood">Under the Hood</a> ·
<a href="#-getting-started">Getting Started</a> ·
<a href="#-contributing">Contributing</a>
</b>

</div>

<img src="assets/readme/divider.svg" width="100%"/>

## 📖 About

**Animated Book** is a Flutter reading experience that treats every page like real paper.
Browse a swipeable shelf of leather-bound covers, tap one to watch it **expand into the reader through a Hero transition**, then **drag to turn pages** with a perspective-correct 3D hinge that follows your finger.

The whole UI is dressed in a warm **leather-and-parchment palette** with an elegant serif type system, illuminated drop caps, and a candlelit dark mode.

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
- **Direction-aware hinge**: flips forward *and* backward
- **Hero cover transition** from shelf to reader
- **Staged reveal**: reader chrome rises and fades in once the cover lands

    </td>
    <td width="50%" valign="top">

### 📚 Reading
- **Swipeable library** of book covers via `PageView`
- **Per-page bookmarks** with instant toggle
- **Illuminated drop caps** on every paragraph
- **Page counter** (`Page x of y`) in the nav tray
- **Custom serif typography** for a printed-book feel

    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">

### 🎨 Design
- **Material 3** themes seeded from leather brown
- **Light ⇄ Dark** toggle: parchment by day, espresso by night
- Textured backgrounds, layered shadows and gradients

    </td>
    <td width="50%" valign="top">

### ⚡ Performance
- Pure Flutter, **zero third-party animation packages**
- `AnimatedBuilder` keeps rebuilds scoped to what moves
- Smooth on 60 Hz and 120 Hz displays

    </td>
  </tr>
</table>

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
| ![](https://img.shields.io/badge/%20-2C2420?style=flat-square) **Espresso** | `#2C2420` | Headings (light) · paper (dark) |
| ![](https://img.shields.io/badge/%20-1A1613?style=flat-square) **Night** | `#1A1613` | Dark surface |
| ![](https://img.shields.io/badge/%20-FFC107?style=flat-square) **Amber** | `#FFC107` | Sun icon in dark mode |

<img src="assets/readme/divider.svg" width="100%"/>

## 🧠 Under the Hood

```mermaid
flowchart LR
    A["📚 BookLibraryScreen<br/>PageView carousel"] -- "tap cover · Hero" --> B["📖 BookReaderScreen"]
    B --> C["🎞️ PageFlipWidget<br/>Matrix4 3D hinge"]
    B -. "drag offset" .-> C
    D["🌗 Theme toggle"] --> A
    E["🔖 Bookmarks map"] --> B

    classDef leather fill:#6B4423,stroke:#CBB69B,color:#FAF8F3
    classDef paper fill:#FAF8F3,stroke:#8B7355,color:#2C2420
    class A,B,C leather
    class D,E paper
```

<details>
<summary><b>🔍 How the page flip works</b></summary>
<br/>

1. A horizontal drag accumulates `_dragOffset` (clamped to ±200 px) and tilts the page as a live preview.
2. The sign of the offset sets `_isFlippingForward`, which moves the hinge to the left or right edge.
3. The rotation is applied with `Matrix4.identity()..setEntry(3, 2, 0.0009)..rotateY(angle)` for real perspective.
4. On release past a 70 px threshold, a 650 ms `AnimationController` with `Curves.easeInOutQuad` completes the turn; otherwise the page snaps back.
5. The page underneath (next or previous, depending on direction) is already rendered, so the reveal never stutters.

</details>

<details>
<summary><b>🧰 Flutter APIs used</b></summary>
<br/>

`AnimationController` · `Tween` · `CurvedAnimation` · `Interval` · `AnimatedBuilder` · `Transform` · `Matrix4` · `Hero` · `PageView.builder` · `GestureDetector` · `Stack` / `Positioned` · `RichText` / `WidgetSpan` · `ThemeData` (Material 3) · `ColorScheme.fromSeed`

</details>

<img src="assets/readme/divider.svg" width="100%"/>

## 📲 Download

Ready-to-install APKs are built automatically by GitHub Actions:

- **Stable:** grab the latest APK from [**Releases**](https://github.com/HammasT1/Animated_Book/releases/latest)
- **Latest build:** open the most recent [**Build APK** run](https://github.com/HammasT1/Animated_Book/actions/workflows/build-apk.yml) and download the `AnimatedBook-APKs` artifact

> Not sure which file to pick? Use **`arm64-v8a`** for most modern phones, or **`universal`** if you're unsure.

## 🚀 Getting Started

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
<summary><b>📦 Build &amp; device commands</b></summary>
<br/>

| Task | Command |
|:--|:--|
| List devices | `flutter devices` |
| Run on a device | `flutter run -d <device_id>` |
| Debug APK | `flutter build apk` |
| Release APK | `flutter build apk --release` |
| Web build | `flutter build web` |
| Windows build | `flutter build windows` |

</details>

### 🗂️ Project Structure

```text
Animated_Book/
├── lib/
│   └── main.dart          # App, themes, library, reader & page-flip widget
├── assets/
│   ├── fonts/             # Serif & Sanseriffic typefaces
│   ├── icons/             # Bookmark, sun, moon, type SVGs
│   ├── images/            # Covers, paper texture, screenshots
│   └── readme/            # Animated banner, palette & dividers for this README
└── pubspec.yaml
```

<img src="assets/readme/divider.svg" width="100%"/>

## 🤝 Contributing

Contributions, ideas and bug reports are welcome.

1. **Fork** the repository
2. Create a branch: `git checkout -b feature/amazing-idea`
3. Commit: `git commit -m "Add amazing idea"`
4. Push: `git push origin feature/amazing-idea`
5. Open a **Pull Request** 🎉

## ⭐ Support

If this project helped or inspired you, please give it a **star**. It helps others find it.

<div align="center">

<br/>

**Crafted with ☕ & 🤎 by [Muhammad Hammas Rasheed](https://github.com/HammasT1)**

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:1A1613,50:6B4423,100:CBB69B&height=120&section=footer" width="100%"/>

</div>

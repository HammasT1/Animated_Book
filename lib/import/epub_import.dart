import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'parsed_book.dart';

/// Reads an EPUB (2 or 3): title and author from the package metadata,
/// chapters in spine order as plain paragraphs, and the cover image.
///
/// DRM-protected books can't be read and are reported as such.
ParsedBook parseEpub(String fileName, Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const BookImportException("it isn't a valid EPUB file");
  }

  if (zip.findFile('META-INF/encryption.xml') != null && _isDrmProtected(zip)) {
    throw const BookImportException('it is protected with DRM');
  }

  final container = _xml(zip, 'META-INF/container.xml');
  final opfPath = container
      ?.findAllElements('rootfile', namespaceUri: '*')
      .map((e) => e.getAttribute('full-path'))
      .firstWhere((p) => p != null && p.isNotEmpty, orElse: () => null);
  if (opfPath == null) {
    throw const BookImportException("it isn't a valid EPUB file");
  }
  final opf = _xml(zip, opfPath);
  if (opf == null) {
    throw const BookImportException("it isn't a valid EPUB file");
  }
  final baseDir = opfPath.contains('/')
      ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
      : '';

  String? meta(String localName) {
    for (final e in opf.findAllElements(localName, namespaceUri: '*')) {
      final text = e.innerText.trim();
      if (text.isNotEmpty) return text.replaceAll(RegExp(r'\s+'), ' ');
    }
    return null;
  }

  // Manifest: id -> item.
  final items = <String, XmlElement>{
    for (final item in opf.findAllElements('item', namespaceUri: '*'))
      if (item.getAttribute('id') != null) item.getAttribute('id')!: item,
  };

  // Spine order, skipping anything that isn't a content document.
  final chapters = <String>[];
  for (final ref in opf.findAllElements('itemref', namespaceUri: '*')) {
    final item = items[ref.getAttribute('idref')];
    final href = item?.getAttribute('href');
    if (item == null || href == null) continue;
    final type = item.getAttribute('media-type') ?? '';
    if (!type.contains('html') && !type.contains('xml')) continue;
    final html = _text(zip, _resolve(baseDir, href));
    if (html == null) continue;
    final text = htmlToText(html);
    if (text.isNotEmpty) chapters.add(text);
  }
  if (chapters.isEmpty) {
    throw const BookImportException('it has no readable text');
  }

  return ParsedBook(
    title: meta('title') ?? titleFromFileName(fileName),
    author: meta('creator') ?? 'Unknown author',
    chapters: splitLongChapters(chapters),
    cover: _cover(zip, opf, items, baseDir),
  );
}

/// EPUB fonts are often "obfuscated" (listed in encryption.xml) without the
/// book itself being protected; only other algorithms mean real DRM.
bool _isDrmProtected(Archive zip) {
  final enc = _xml(zip, 'META-INF/encryption.xml');
  if (enc == null) return false;
  const fontObfuscation = {
    'http://www.idpf.org/2008/embedding',
    'http://ns.adobe.com/pdf/enc#RC',
  };
  return enc
      .findAllElements('EncryptionMethod', namespaceUri: '*')
      .map((e) => e.getAttribute('Algorithm'))
      .any((a) => a != null && !fontObfuscation.contains(a));
}

Uint8List? _cover(
  Archive zip,
  XmlDocument opf,
  Map<String, XmlElement> items,
  String baseDir,
) {
  bool isImage(XmlElement e) =>
      (e.getAttribute('media-type') ?? '').startsWith('image/');

  XmlElement? item;
  // EPUB 3: <item properties="cover-image">.
  for (final e in items.values) {
    if ((e.getAttribute('properties') ?? '')
        .split(' ')
        .contains('cover-image')) {
      item = e;
      break;
    }
  }
  // EPUB 2: <meta name="cover" content="item-id">.
  if (item == null) {
    for (final m in opf.findAllElements('meta', namespaceUri: '*')) {
      if (m.getAttribute('name') == 'cover') {
        final candidate = items[m.getAttribute('content')];
        if (candidate != null && isImage(candidate)) item = candidate;
        break;
      }
    }
  }
  // Otherwise an image whose id or file name says "cover".
  item ??= items.values
      .where(isImage)
      .cast<XmlElement?>()
      .firstWhere(
        (e) => '${e!.getAttribute('id')} ${e.getAttribute('href')}'
            .toLowerCase()
            .contains('cover'),
        orElse: () => null,
      );

  final href = item?.getAttribute('href');
  if (href == null) return null;
  return zip.findFile(_resolve(baseDir, href))?.readBytes();
}

String _resolve(String baseDir, String href) {
  final path = Uri.decodeFull(href.split('#').first);
  final parts = <String>[];
  for (final part in '$baseDir$path'.split('/')) {
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (part.isNotEmpty && part != '.') {
      parts.add(part);
    }
  }
  return parts.join('/');
}

String? _text(Archive zip, String path) {
  final bytes = zip.findFile(path)?.readBytes();
  if (bytes == null) return null;
  return utf8.decode(bytes, allowMalformed: true);
}

XmlDocument? _xml(Archive zip, String path) {
  final text = _text(zip, path);
  if (text == null) return null;
  try {
    return XmlDocument.parse(text);
  } on XmlException {
    return null;
  }
}

/// Turns an (X)HTML chapter into plain paragraphs.
///
/// Uses patterns rather than an XML parser on purpose: real-world EPUB
/// chapters often use HTML entities like `&nbsp;` that strict XML rejects.
String htmlToText(String html) {
  var s = html;
  final body = RegExp(
    r'<body[^>]*>([\s\S]*)</body>',
    caseSensitive: false,
  ).firstMatch(s);
  if (body != null) s = body.group(1)!;

  s = s
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
      .replaceAll(
        RegExp(
          r'<(script|style|head|title|svg)\b[^>]*>[\s\S]*?</\1>',
          caseSensitive: false,
        ),
        '',
      )
      // Source line breaks are just spaces in HTML.
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(
          r'</?(p|div|h[1-6]|li|ul|ol|dl|dt|dd|blockquote|section|article|'
          r'aside|header|footer|figure|figcaption|table|tr|hr|pre)\b[^>]*>',
          caseSensitive: false,
        ),
        '\n\n',
      )
      .replaceAll(RegExp(r'<[^>]*>'), '');

  return normalizeParagraphs(decodeEntities(s));
}

const Map<String, String> _entities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00A0',
  'mdash': '—',
  'ndash': '–',
  'hellip': '…',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
  'laquo': '«',
  'raquo': '»',
  'copy': '©',
  'shy': '',
};

/// Decodes named (common ones) and numeric character references.
String decodeEntities(String s) =>
    s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'), (m) {
      final ref = m.group(1)!;
      if (ref.startsWith('#')) {
        final code = ref.startsWith('#x') || ref.startsWith('#X')
            ? int.tryParse(ref.substring(2), radix: 16)
            : int.tryParse(ref.substring(1));
        if (code == null || code > 0x10FFFF) return m.group(0)!;
        return String.fromCharCode(code);
      }
      return _entities[ref] ?? m.group(0)!;
    });

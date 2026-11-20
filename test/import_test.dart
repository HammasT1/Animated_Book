import 'dart:convert';
import 'dart:typed_data';

import 'package:animated_book/data/book_storage.dart';
import 'package:animated_book/data/library.dart';
import 'package:animated_book/data/library_store.dart';
import 'package:animated_book/import/book_import.dart';
import 'package:animated_book/import/epub_import.dart';
import 'package:animated_book/import/parsed_book.dart';
import 'package:animated_book/models/book.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

/// A long, hard-wrapped prose paragraph (lines of ~60 characters).
String _wrapped(String seed, int lines) => List.generate(
  lines,
  (i) => '$seed line $i continues the sentence with some more words',
).join('\n');

Uint8List _epub({
  String title = 'The Test Book',
  String author = 'A. Writer',
  bool encrypted = false,
}) {
  final zip = Archive();
  void add(String name, String content) =>
      zip.addFile(ArchiveFile.bytes(name, utf8.encode(content)));

  add('mimetype', 'application/epub+zip');
  add('META-INF/container.xml', '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
  if (encrypted) {
    add('META-INF/encryption.xml', '''<?xml version="1.0"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container" xmlns:enc="http://www.w3.org/2001/04/xmlenc#">
  <enc:EncryptedData><enc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/></enc:EncryptedData>
</encryption>''');
  }
  add('OEBPS/content.opf', '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:creator>$author</dc:creator>
  </metadata>
  <manifest>
    <item id="cover" href="images/cover.png" media-type="image/png" properties="cover-image"/>
    <item id="c2" href="text/chapter%202.xhtml" media-type="application/xhtml+xml"/>
    <item id="c1" href="text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="css" href="style.css" media-type="text/css"/>
  </manifest>
  <spine><itemref idref="c1"/><itemref idref="c2"/></spine>
</package>''');
  add(
    'OEBPS/text/ch1.xhtml',
    '''<html><head><title>One</title><style>p{}</style></head>
<body><h1>Chapter One</h1>
<p>It was a bright&nbsp;cold day,
and the clocks were striking thirteen.</p>
<p>Line one<br/>Line two &amp; three &#8212; done</p>
<!-- a comment --></body></html>''',
  );
  add('OEBPS/text/chapter 2.xhtml', '''<html><body>
<div><p>Second <em>chapter</em> text.</p></div></body></html>''');
  zip.addFile(ArchiveFile.bytes('OEBPS/images/cover.png', [1, 2, 3, 4]));
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

void main() {
  group('.txt import', () {
    test('strips the Gutenberg licence and reads title and author', () {
      final file =
          '''
The Project Gutenberg eBook of The Time Machine

Title: The Time Machine
Author: H. G. Wells

*** START OF THE PROJECT GUTENBERG EBOOK THE TIME MACHINE ***

${_wrapped('First', 4)}

${_wrapped('Second', 3)}

*** END OF THE PROJECT GUTENBERG EBOOK THE TIME MACHINE ***

Licence text that must not appear.
''';
      final book = parseBookFile(('time_machine.txt', _utf8(file)));
      expect(book.title, 'The Time Machine');
      expect(book.author, 'H. G. Wells');
      final text = book.chapters.join('\n\n');
      expect(text, isNot(contains('Licence')));
      expect(text, isNot(contains('START OF')));
      // Hard-wrapped lines are joined into one paragraph each.
      expect(text.split('\n\n'), hasLength(2));
      expect(text, startsWith('First line 0 continues'));
      expect(text.split('\n\n').first, isNot(contains('\n')));
    });

    test('keeps the line breaks of verse', () {
      final book = parseBookFile((
        'poems.txt',
        _utf8('Roses are red,\nViolets are blue,\nSugar is sweet.\n\nEnd.'),
      ));
      expect(
        book.chapters.single,
        'Roses are red,\nViolets are blue,\n'
        'Sugar is sweet.\n\nEnd.',
      );
    });

    test('treats one line per paragraph files as such', () {
      final book = parseBookFile((
        'notes.txt',
        _utf8('First paragraph here.\nSecond one.\nThird one.\n'),
      ));
      expect(book.chapters.single.split('\n\n'), [
        'First paragraph here.',
        'Second one.',
        'Third one.',
      ]);
    });

    test('splits chapters at headings, but not inside a contents list', () {
      final body = _wrapped('Body', 14);
      final file = [
        'CONTENTS',
        'CHAPTER I',
        'CHAPTER II',
        'CHAPTER I',
        body,
        'CHAPTER II',
        body,
      ].join('\n\n');
      final book = parseBookFile(('novel.txt', _utf8(file)));
      expect(book.chapters, hasLength(2));
      expect(
        book.chapters[0],
        startsWith('CONTENTS\n\nCHAPTER I\n\nCHAPTER II'),
      );
      expect(book.chapters[1], startsWith('CHAPTER II'));
    });

    test('falls back to Latin-1 and uses the file name as the title', () {
      final bytes = Uint8List.fromList(latin1.encode('Café crème.'));
      final book = parseBookFile(('my_cafe-story.txt', bytes));
      expect(book.chapters.single, 'Café crème.');
      expect(book.title, 'my cafe story');
      expect(book.author, 'Unknown author');
    });

    test('rejects a file with no text', () {
      expect(
        () => parseBookFile(('blank.txt', _utf8('  \n\n  '))),
        throwsA(isA<BookImportException>()),
      );
    });
  });

  group('.epub import', () {
    test('reads metadata, chapters in spine order, and the cover', () {
      final book = parseBookFile(('ignored.epub', _epub()));
      expect(book.title, 'The Test Book');
      expect(book.author, 'A. Writer');
      expect(book.cover, [1, 2, 3, 4]);
      expect(book.chapters, [
        'Chapter One\n\n'
            'It was a bright cold day, and the clocks were striking '
            'thirteen.\n\n'
            'Line one\nLine two & three — done',
        'Second chapter text.',
      ]);
    });

    test('refuses DRM-protected books', () {
      expect(
        () => parseBookFile(('locked.epub', _epub(encrypted: true))),
        throwsA(
          isA<BookImportException>().having(
            (e) => e.message,
            'message',
            contains('DRM'),
          ),
        ),
      );
    });

    test('rejects a file that is not an EPUB', () {
      expect(
        () => parseBookFile(('fake.epub', _utf8('just text'))),
        throwsA(isA<BookImportException>()),
      );
    });

    test('decodes character references', () {
      expect(decodeEntities('&lt;a&gt; &#65;&#x42; &bogus;'), '<a> AB &bogus;');
    });
  });

  test('other file types are refused', () {
    expect(
      () => parseBookFile(('book.pdf', _utf8('%PDF'))),
      throwsA(isA<BookImportException>()),
    );
  });

  test('long chapters are split at paragraph breaks', () {
    final paragraph = 'x' * 900;
    final chapter = List.filled(10, paragraph).join('\n\n');
    final parts = splitLongChapters([chapter], maxLength: 2000);
    expect(parts, hasLength(5));
    for (final part in parts) {
      expect(part.length, lessThanOrEqualTo(2000));
    }
    expect(parts.join('\n\n'), chapter);
  });

  group('LibraryStore', () {
    test('adds a book once, keeps it in storage, and removes it', () async {
      final storage = MemoryBookStorage();
      final store = LibraryStore(storage, parseInBackground: false);
      await store.load();
      expect(store.books, kLibrary);

      final (book, again) = await store.importFile('b.epub', _epub());
      expect(again, isFalse);
      expect(book.isImported, isTrue);
      expect(book.sectionsAreChapters, isTrue);
      expect(store.books.last.id, book.id);

      final (same, duplicate) = await store.importFile('copy.epub', _epub());
      expect(duplicate, isTrue);
      expect(same.id, book.id);
      expect(store.books.length, kLibrary.length + 1);

      final reloaded = LibraryStore(storage, parseInBackground: false);
      await reloaded.load();
      expect(reloaded.books.last.title, 'The Test Book');

      await store.remove(book.id);
      expect(store.books, kLibrary);
      expect(await storage.loadAll(), isEmpty);
    });

    test('a failed import leaves the shelf unchanged', () async {
      final store = LibraryStore.inMemory();
      await expectLater(
        store.importFile('bad.epub', _utf8('nope')),
        throwsA(isA<BookImportException>()),
      );
      expect(store.books, kLibrary);
    });

    test('stored books round-trip through JSON', () {
      final cover = Uint8List.fromList([9, 8, 7]);
      final book = Book(
        id: 'import-1234abcd',
        title: 'T',
        author: 'A',
        sections: const ['One.\n\nTwo.', 'Three.'],
        coverImage: cover,
        sectionsAreChapters: true,
        isImported: true,
      );
      final (decoded, addedAt) = decodeBook(encodeBook(book), cover);
      expect(decoded.id, book.id);
      expect(decoded.title, 'T');
      expect(decoded.author, 'A');
      expect(decoded.sections, book.sections);
      expect(decoded.coverImage, cover);
      expect(decoded.sectionsAreChapters, isTrue);
      expect(decoded.isImported, isTrue);
      expect(addedAt, greaterThan(0));
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class Book {
  const Book({
    this.id = 0,
    this.remoteId = '',
    required this.title,
    required this.author,
    required this.category,
    this.subcategory = '',
    required this.color,
    this.description = '',
    this.year,
    this.pages,
    this.isbn = '',
    this.shelf = '',
    this.totalCopies = 1,
    this.copiesAvailable = 1,
    this.isNewArrival = false,
    this.isPopular = false,
    this.publisher = '',
    this.published,
    this.imageUrl = '',
    this.imageBytes,
  });

  final int id;
  final String remoteId; // server (MongoDB) id
  final String title;
  final String author;
  final String category;
  final String subcategory;
  final Color color;
  final String description;
  final int? year;
  final int? pages;
  final String isbn;
  final String shelf;
  final int totalCopies;
  final int copiesAvailable;
  final bool isNewArrival;
  final bool isPopular;
  final String publisher;
  final DateTime? published;
  final String imageUrl;
  final Uint8List? imageBytes;

  bool get available => copiesAvailable > 0;

  Book copyWith({
    int? id,
    String? remoteId,
    String? title,
    String? author,
    String? category,
    String? subcategory,
    String? description,
    String? publisher,
    DateTime? published,
    String? imageUrl,
    Uint8List? imageBytes,
    int? totalCopies,
    int? copiesAvailable,
    int? pages,
    String? isbn,
    String? shelf,
    bool clearImageBytes = false,
  }) =>
      Book(
        id: id ?? this.id,
        remoteId: remoteId ?? this.remoteId,
        title: title ?? this.title,
        author: author ?? this.author,
        category: category ?? this.category,
        subcategory: subcategory ?? this.subcategory,
        color: color,
        description: description ?? this.description,
        year: year,
        pages: pages ?? this.pages,
        isbn: isbn ?? this.isbn,
        shelf: shelf ?? this.shelf,
        totalCopies: totalCopies ?? this.totalCopies,
        copiesAvailable: copiesAvailable ?? this.copiesAvailable,
        isNewArrival: isNewArrival,
        isPopular: isPopular,
        publisher: publisher ?? this.publisher,
        published: published ?? this.published,
        imageUrl: imageUrl ?? this.imageUrl,
        imageBytes: clearImageBytes ? null : (imageBytes ?? this.imageBytes),
      );

  // Same fields the web uses: id, title, author, publisher, category,
  // published (YYYY-MM-DD), description, image, cover, copies.
  factory Book.fromServer(Map<String, dynamic> j, {required int localId}) {
    final img = (j['image'] as String?) ?? '';
    Uint8List? bytes;
    if (img.startsWith('data:')) {
      try {
        bytes = base64Decode(img.substring(img.indexOf(',') + 1));
      } catch (_) {}
    }
    var color = const Color(0xFF55161D);
    final cover = j['cover'];
    if (cover is List && cover.isNotEmpty) {
      try {
        color = _hexToColor(cover.first as String);
      } catch (_) {}
    }
    final copies = (j['copies'] as num?)?.toInt() ?? 1;
    return Book(
      id: localId,
      remoteId: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '') as String,
      author: (j['author'] ?? '') as String,
      category: (j['category'] ?? '') as String,
      subcategory: (j['subcategory'] ?? '').toString(),
      color: color,
      description: (j['description'] ?? '') as String,
      publisher: (j['publisher'] ?? '') as String,
      published: DateTime.tryParse((j['published'] ?? '') as String),
      totalCopies: copies,
      copiesAvailable: copies,
      isbn: (j['isbn'] ?? '').toString(),
      pages: (j['pages'] as num?)?.toInt(),
      shelf: (j['shelf'] ?? '').toString(),
      imageUrl: bytes == null && !img.startsWith('data:') ? img : '',
      imageBytes: bytes,
    );
  }

  Map<String, dynamic> toServer() {
    String two(int n) => n.toString().padLeft(2, '0');
    final p = published;
    return {
      'title': title,
      'author': author,
      'publisher': publisher,
      'category': category,
      'subcategory': subcategory,
      'published': p == null ? '' : '${p.year}-${two(p.month)}-${two(p.day)}',
      'description': description,
      'image': imageBytes != null
          ? 'data:image/jpeg;base64,${base64Encode(imageBytes!)}'
          : imageUrl,
      'copies': totalCopies,
      'isbn': isbn,
      'pages': pages,
      'shelf': shelf,
    };
  }

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as int,
        title: json['title'] as String,
        author: json['author'] as String,
        category: json['category'] as String,
        subcategory: (json['subcategory'] ?? '').toString(),
        color: _hexToColor(json['color'] as String),
        description: json['description'] as String? ?? '',
        year: json['year'] as int?,
        pages: json['pages'] as int?,
        totalCopies: json['totalCopies'] as int? ?? 1,
        copiesAvailable: json['copiesAvailable'] as int? ?? 1,
        isNewArrival: json['isNewArrival'] as bool? ?? false,
        isPopular: json['isPopular'] as bool? ?? false,
        publisher: json['publisher'] as String? ?? '',
        published: DateTime.tryParse(json['published'] as String? ?? ''),
        imageUrl: json['imageUrl'] as String? ?? '',
      );
}

Color _hexToColor(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

class BookRepository {
  static Future<List<Book>> loadBooks() async {
    final raw = await rootBundle.loadString('assets/books.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    return (data['books'] as List)
        .map((e) => Book.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

List<String> categoriesOf(List<Book> books) {
  final set = <String>{
    for (final b in books)
      if (b.category.trim().isNotEmpty) b.category.trim(),
  };
  final sorted = set.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return ['All', ...sorted];
}

const _knownCategoryColors = <String, Color>{
  'All': Color(0xFF55161D),
  'Fiction': Color(0xFF0A3D91),
  'Science': Color(0xFF0B7A3E),
  'History': Color(0xFFB36A0B),
  'Mystery': Color(0xFF6B3F23),
  'Fantasy': Color(0xFF5B2A86),
  'Romance': Color(0xFFC2185B),
};

const _fallbackCategoryColors = <Color>[
  Color(0xFF2F5D62),
  Color(0xFF7C4D6E),
  Color(0xFF1B2A41),
  Color(0xFFD40000),
  Color(0xFF4E6E2A),
];

Color categoryChipColor(String category) {
  final known = _knownCategoryColors[category];
  if (known != null) return known;

  final hash = category.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return _fallbackCategoryColors[hash % _fallbackCategoryColors.length];
}
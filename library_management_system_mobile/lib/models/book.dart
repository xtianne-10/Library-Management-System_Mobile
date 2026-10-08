import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class Book {
  const Book({
    this.id = 0,
    required this.title,
    required this.author,
    required this.category,
    required this.color,
    this.description = '',
    this.year,
    this.pages,
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
  final String title;
  final String author;
  final String category;
  final Color color;
  final String description;
  final int? year;
  final int? pages;
  final int totalCopies;
  final int copiesAvailable;
  final bool isNewArrival;
  final bool isPopular;
  final String publisher;
  final DateTime? published;
  final String imageUrl;
  final Uint8List? imageBytes; // picked from gallery

  bool get available => copiesAvailable > 0;

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? category,
    String? description,
    String? publisher,
    DateTime? published,
    String? imageUrl,
    Uint8List? imageBytes,
    bool clearImageBytes = false,
  }) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        category: category ?? this.category,
        color: color,
        description: description ?? this.description,
        year: year,
        pages: pages,
        totalCopies: totalCopies,
        copiesAvailable: copiesAvailable,
        isNewArrival: isNewArrival,
        isPopular: isPopular,
        publisher: publisher ?? this.publisher,
        published: published ?? this.published,
        imageUrl: imageUrl ?? this.imageUrl,
        imageBytes: clearImageBytes ? null : (imageBytes ?? this.imageBytes),
      );

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as int,
        title: json['title'] as String,
        author: json['author'] as String,
        category: json['category'] as String,
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
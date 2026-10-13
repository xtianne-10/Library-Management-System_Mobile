import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:library_management_system_mobile/models/book.dart';

/// Same idea as <Cover> in HomeStudent.jsx: real image if the book has one,
/// otherwise a gradient generated from the title.
/// Leave width/height null to fill whatever space the parent gives it.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.width, this.height});

  final Book book;
  final double? width;
  final double? height;

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(3),
    bottomLeft: Radius.circular(3),
    topRight: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  Widget _fallback() {
    final hue = book.title.codeUnits.fold<int>(0, (n, c) => n + c) % 360;
    final top = HSLColor.fromAHSL(1, hue.toDouble(), 0.45, 0.32).toColor();
    final bottom =
        HSLColor.fromAHSL(1, ((hue + 40) % 360).toDouble(), 0.5, 0.14)
            .toColor();

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : 120.0;
      return Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(w * 0.08),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [top, bottom],
          ),
        ),
        child: Text(
          book.title,
          textAlign: TextAlign.center,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['serif'],
            fontWeight: FontWeight.w700,
            fontSize: (w * 0.12).clamp(10.0, 20.0),
            height: 1.2,
          ),
        ),
      );
    });
  }

  Widget _image() {
    final bytes = book.imageBytes;
    if (bytes != null) {
      return Image.memory(bytes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback());
    }

    final url = book.imageUrl.trim();

    // The web can store uploaded covers as data: URLs
    if (url.startsWith('data:image')) {
      try {
        return Image.memory(base64Decode(url.substring(url.indexOf(',') + 1)),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback());
      } catch (_) {
        return _fallback();
      }
    }

    if (url.isNotEmpty) {
      return Image.network(url,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _fallback());
    }

    return _fallback();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: _radius,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: _radius, child: _image()),
      ),
    );
  }
}
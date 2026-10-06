import 'package:flutter/material.dart';

// Palette

class Palette {
  // Core brand
  static const burgundy = Color(0xFF55161D); // navbar / login background
  static const burgundyDark = Color(0xFF3B0E14);
  static const cream = Color(0xFFFFDDC1); // sign up button
  static const creamLight = Color(0xFFFFF1E6); // hero headline text
  static const creamMuted = Color(0xFFC9A18F); // placeholder / hint text
  static const amber = Color(0xFFD97B21); // "Explore Collection" CTA
  static const gold = Color(0xFFE8C170); // book title lettering

  // House colors
  static const gryffindor = Color(0xFFD40000);
  static const hufflepuff = Color(0xFFF29A0A);
  static const ravenclaw = Color(0xFF0A3D91);
  static const slytherin = Color(0xFF0B7A3E);

  // BG & Text
  static const page = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFF6EF);
  static const textDark = Color(0xFF2B1215);
  static const textMuted = Color(0xFF7A5A55);
}

Color categoryColor(String category) {
  switch (category) {
    case 'Fiction':
      return Palette.gryffindor;
    case 'Science':
      return Palette.ravenclaw;
    case 'History':
      return Palette.hufflepuff;
    case 'Mystery':
      return Palette.slytherin;
    default:
      return Palette.burgundy;
  }
}
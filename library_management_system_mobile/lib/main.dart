import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const LibraryApp());
}

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

// BOOKS

class Book {
  const Book({
    required this.title,
    required this.author,
    required this.category,
    required this.color,
    this.available = true,
  });

  final String title;
  final String author;
  final String category;
  final Color color;
  final bool available;
}

const _categories = ['All', 'Fiction', 'Science', 'History', 'Mystery'];

const _newArrivals = [
  Book(
    title: 'Frankenstein',
    author: 'Mary Shelley',
    category: 'Fiction',
    color: Palette.slytherin,
  ),
  Book(
    title: 'The Time Machine',
    author: 'H. G. Wells',
    category: 'Science',
    color: Palette.ravenclaw,
  ),
  Book(
    title: 'Dracula',
    author: 'Bram Stoker',
    category: 'Fiction',
    color: Palette.burgundy,
    available: false,
  ),
  Book(
    title: 'Moby-Dick',
    author: 'Herman Melville',
    category: 'Fiction',
    color: Color(0xFF1B2A41),
  ),
];

const _popular = [
  Book(
    title: 'Jane Eyre',
    author: 'Charlotte Brontë',
    category: 'Fiction',
    color: Palette.gryffindor,
  ),
  Book(
    title: 'The Hound of the Baskervilles',
    author: 'Arthur Conan Doyle',
    category: 'Mystery',
    color: Palette.slytherin,
  ),
  Book(
    title: 'On the Origin of Species',
    author: 'Charles Darwin',
    category: 'Science',
    color: Palette.ravenclaw,
    available: false,
  ),
  Book(
    title: 'The Histories',
    author: 'Herodotus',
    category: 'History',
    color: Color(0xFFB36A0B),
  ),
  Book(
    title: 'Emma',
    author: 'Jane Austen',
    category: 'Fiction',
    color: Palette.burgundy,
  ),
];


class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.burgundy,
      brightness: Brightness.light,
    ).copyWith(
      primary: Palette.burgundy,
      onPrimary: Palette.creamLight,
      primaryContainer: Palette.cream,
      onPrimaryContainer: Palette.burgundy,
      secondary: Palette.amber,
      onSecondary: Colors.white,
      surface: Palette.page,
      onSurface: Palette.textDark,
    );

    return MaterialApp(
      title: 'Hogwarts Library',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: Palette.page,
        fontFamily: 'Georgia',
        fontFamilyFallback: const ['serif'],
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: Palette.textDark,
              displayColor: Palette.textDark,
              fontFamily: 'Georgia',
            ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Palette.burgundy,
          indicatorColor: Palette.cream,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Palette.burgundy
                  : Palette.creamMuted,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              fontFamily: 'Georgia',
              fontSize: 12,
              color: states.contains(WidgetState.selected)
                  ? Palette.creamLight
                  : Palette.creamMuted,
            );
          }),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Palette.amber),
        ),
      ),
      home: const LibraryHomePage(),
    );
  }
}

// Home

class LibraryHomePage extends StatefulWidget {
  const LibraryHomePage({super.key});

  @override
  State<LibraryHomePage> createState() => _LibraryHomePageState();
}

class _LibraryHomePageState extends State<LibraryHomePage> {
  String _selectedCategory = 'All';
  int _navIndex = 0;

  List<Book> get _filteredPopular => _selectedCategory == 'All'
      ? _popular
      : _popular.where((b) => b.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // light status bar icons on burgundy
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Burgundy header (greeting + search)
            Container(
              padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 24),
              decoration: const BoxDecoration(
                color: Palette.burgundy,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Good morning, User',
                                style: text.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Palette.creamLight,
                                )),
                            const SizedBox(height: 2),
                            Text('Knowledge is the truest magic.',
                                style: text.bodyMedium?.copyWith(
                                  color: Palette.creamMuted,
                                )),
                          ],
                        ),
                      ),
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Palette.cream,
                        child: Text(
                          'U',
                          style: TextStyle(
                            color: Palette.burgundy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const SearchBar(
                    hintText: 'Search titles, authors, or topics',
                    hintStyle: WidgetStatePropertyAll(
                      TextStyle(color: Palette.textMuted),
                    ),
                    textStyle: WidgetStatePropertyAll(
                      TextStyle(color: Palette.textDark),
                    ),
                    leading: Icon(Icons.search, color: Palette.burgundy),
                    backgroundColor: WidgetStatePropertyAll(Palette.cream),
                    elevation: WidgetStatePropertyAll(0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Due soon
            const _SectionTitle('Due soon'),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _DueSoonCard(
                book: Book(
                  title: 'The Great Gatsby',
                  author: 'F. Scott Fitzgerald',
                  category: 'Fiction',
                  color: Palette.ravenclaw,
                ),
                daysLeft: 3,
              ),
            ),
            const SizedBox(height: 28),

            // Categories
            const _SectionTitle('Browse by category'),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = _categories[i];
                  final color = categoryColor(c);
                  final selected = c == _selectedCategory;
                  return ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    showCheckmark: false,
                    backgroundColor: Palette.page,
                    selectedColor: color,
                    side: BorderSide(color: color, width: 1.2),
                    labelStyle: TextStyle(
                      fontFamily: 'Georgia',
                      color: selected ? Colors.white : color,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = c),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // New arrivals
            const _SectionTitle('New arrivals'),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _newArrivals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) =>
                    _BookTile(book: _newArrivals[i]),
              ),
            ),
            const SizedBox(height: 28),

            // Popular
            _SectionTitle(
              _selectedCategory == 'All'
                  ? 'Popular this week'
                  : 'Popular in $_selectedCategory',
            ),
            const SizedBox(height: 12),
            if (_filteredPopular.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('No popular books in this category yet.'),
              )
            else
              for (final book in _filteredPopular)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: _BookRow(book: book),
                ),
            const SizedBox(height: 24),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _navIndex,
          onDestinationSelected: (i) => setState(() => _navIndex = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Explore'),
            NavigationDestination(
                icon: Icon(Icons.bookmark_border),
                selectedIcon: Icon(Icons.bookmark),
                label: 'My books'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Account'),
          ],
        ),
      ),
    );
  }
}

// Widgets

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Palette.burgundy,
                  ),
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('See all')),
        ],
      ),
    );
  }
}

// Book Cover

class _BookCover extends StatelessWidget {
  const _BookCover({required this.book, this.width = 120, this.height = 170});

  final Book book;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(book.color);
    final spine = hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0));

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: book.color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3),
          bottomLeft: Radius.circular(3),
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(width: width * 0.08, color: spine.toColor()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  book.title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Palette.gold,
                    fontFamily: 'Georgia',
                    fontFamilyFallback: const ['serif'],
                    fontWeight: FontWeight.w700,
                    fontSize: width * 0.13,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// New Arrivals

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 120,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookCover(book: book),
            const SizedBox(height: 10),
            Text(book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Palette.textDark,
                )),
            Text(book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: Palette.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Popular List
class _BookRow extends StatelessWidget {
  const _BookRow({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x2655161D)),
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _BookCover(book: book, width: 56, height: 80),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Palette.textDark,
                        )),
                    const SizedBox(height: 2),
                    Text(book.author,
                        style: text.bodyMedium
                            ?.copyWith(color: Palette.textMuted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          book.available
                              ? Icons.check_circle
                              : Icons.schedule,
                          size: 16,
                          color: book.available
                              ? Palette.slytherin
                              : Palette.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          book.available ? 'Available' : 'On hold',
                          style: text.bodySmall
                              ?.copyWith(color: Palette.textDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                tooltip: 'Save for later',
                color: Palette.burgundy,
                icon: const Icon(Icons.bookmark_add_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Due Soon Card

class _DueSoonCard extends StatelessWidget {
  const _DueSoonCard({required this.book, required this.daysLeft});

  final Book book;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.burgundy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _BookCover(book: book, width: 64, height: 92),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Palette.creamLight,
                    )),
                Text(book.author,
                    style: text.bodyMedium
                        ?.copyWith(color: Palette.creamMuted)),
                const SizedBox(height: 8),
                Text('Due in $daysLeft days',
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Palette.cream,
                    )),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.amber,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {},
                  child: const Text('Renew'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
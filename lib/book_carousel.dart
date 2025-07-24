import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/book_response.dart';
import '../../widget/BookDetailScreen.dart';

class BookCarousel extends StatefulWidget {
  final List<BookResponse> books;
  final Function(String?) onCategorySelected;

  const BookCarousel({
    Key? key,
    required this.books,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  _BookCarouselState createState() => _BookCarouselState();
}

class _BookCarouselState extends State<BookCarousel> {
  late PageController _pageController;
  double _currentPage = 0.0;
  Timer? _autoScrollTimer;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.6);
    _pageController.addListener(() {
      setState(() => _currentPage = _pageController.page ?? 0.0);
    });
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_pageController.hasClients) return;
      if (_currentPage < widget.books.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(BookResponse book) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favoriteBookIds') ?? [];
    final bookId = book.biblioId.toString();
    if (favs.contains(bookId)) {
      favs.remove(bookId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('removed_from_favorites'.tr())),
      );
    } else {
      favs.add(bookId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('added_to_favorites'.tr())),
      );
    }
    await prefs.setStringList('favoriteBookIds', favs);
  }

  @override
  Widget build(BuildContext context) {
    // Sample categories (replace with dynamic data if available)
    final categories = ['All', 'Fiction', 'Non-Fiction', 'Science', 'History'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: categories.map((category) {
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(category.tr()),
                  selected: isSelected,
                  selectedColor: Colors.blueAccent,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = category);
                      widget.onCategorySelected(category == 'All' ? null : category);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        // Carousel
        SizedBox(
          height: 300,
          child: widget.books.isEmpty
              ? Center(child: Text('no_books_found'.tr()))
              : PageView.builder(
            controller: _pageController,
            itemCount: widget.books.length,
            onPageChanged: (_) => _autoScrollTimer?.cancel(),
            itemBuilder: (context, index) {
              final book = widget.books[index];
              final double offset = (_currentPage - index).abs();

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double scale = (1 - offset * 0.3).clamp(0.7, 1.0);
                  double angle = offset * 0.1;

                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle)
                      ..scale(scale),
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () {
                        _autoScrollTimer?.cancel();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookDetailScreen(biblioId: book.biblioId),
                          ),
                        );
                      },
                      onLongPress: () => _toggleFavorite(book),
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                              child: CachedNetworkImage(
                                imageUrl: book.imageUrl ?? '',
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) =>
                                const Icon(Icons.broken_image, size: 50),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    book.author ?? 'Unknown Author',
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
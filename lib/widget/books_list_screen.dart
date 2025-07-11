import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book_response.dart';
import '../services/KohaApiService.dart';
import 'BookDetailScreen.dart';

class BooksListScreen extends StatefulWidget {
  @override
  _BooksListScreenState createState() => _BooksListScreenState();
}

class _BooksListScreenState extends State<BooksListScreen> {
  final ScrollController _scrollController = ScrollController();
  List<BookResponse> books = [];
  int currentPage = 1;
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  String currentQuery = '';

  // Store favorite book IDs here
  Set<String> favoriteBookIds = {};

  bool showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _fetchBooks();

    _scrollController.addListener(() {
      if (_scrollController.position.atEdge &&
          _scrollController.position.pixels != 0 &&
          !isLoading &&
          !showFavoritesOnly) {
        _fetchBooks(reset: false);
      }
    });

    _searchController.addListener(() {
      _onSearchChanged(_searchController.text);
      setState(() {}); // to show/hide clear icon
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchBooks(reset: true, query: query.trim());
    });
  }

  void _fetchBooks({bool reset = false, String? query}) {
    if (reset) {
      books.clear();
      currentPage = 1;
      currentQuery = query ?? '';
    }

    setState(() => isLoading = true);

    KohaApiService().fetchBooks(currentPage, query: currentQuery).then((newBooks) {
      setState(() {
        books.addAll(newBooks);
        isLoading = false;
        if (newBooks.isNotEmpty) currentPage++;
      });
    }).catchError((error) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching books: $error')),
      );
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favoriteBookIds') ?? [];
    setState(() {
      favoriteBookIds = favs.toSet();
    });
  }

  Future<void> _toggleFavorite(dynamic bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookIdStr = bookId.toString(); // <-- convert here
    setState(() {
      if (favoriteBookIds.contains(bookIdStr)) {
        favoriteBookIds.remove(bookIdStr);
      } else {
        favoriteBookIds.add(bookIdStr);
      }
    });
    await prefs.setStringList('favoriteBookIds', favoriteBookIds.toList());
  }

  // Returns filtered books when showing favorites only
  List<BookResponse> get _displayedBooks {
    if (showFavoritesOnly) {
      return books.where((book) => favoriteBookIds.contains(book.biblioId.toString())).toList();
    } else {
      return books;
    }
  }

  @override
  Widget build(BuildContext context) {
    const double imageSize = 80.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Books'),
        actions: [
          IconButton(
            icon: Icon(showFavoritesOnly ? Icons.favorite : Icons.favorite_border),
            tooltip: showFavoritesOnly ? 'Show All Books' : 'Show Favorites',
            onPressed: () {
              setState(() {
                showFavoritesOnly = !showFavoritesOnly;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for books',
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _fetchBooks(reset: true);
                  },
                )
                    : const Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                _fetchBooks(reset: true, query: value.trim());
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _displayedBooks.length + (isLoading && !showFavoritesOnly ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _displayedBooks.length) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  final book = _displayedBooks[index];
                  final isFavorite = favoriteBookIds.contains(book.biblioId.toString());
                  return Card(
                    child: ListTile(
                      leading: Semantics(
                        label: 'Cover image of ${book.title}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: book.imageUrl ?? '',
                            placeholder: (context, url) => SizedBox(
                              width: imageSize,
                              height: imageSize,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image, size: imageSize),
                            width: imageSize,
                            height: imageSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Text(book.title),
                      subtitle: Text(book.author),
                      trailing: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : null,
                        ),
                        onPressed: () {
                          _toggleFavorite(book.biblioId);
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookDetailScreen(biblioId: book.biblioId),
                          ),
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

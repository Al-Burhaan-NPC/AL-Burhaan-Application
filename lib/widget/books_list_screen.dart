import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  void _fetchBooks({String? query}) {
    if (query != null) {
      books.clear();   // Clear existing books for a new search
      currentPage = 1; // Reset pagination
    }

    setState(() => isLoading = true);
    KohaApiService().fetchBooks(currentPage, query: query).then((newBooks) {
      setState(() {
        books.addAll(newBooks);
        isLoading = false;
        if (newBooks.isNotEmpty) currentPage++;
      });
    }).catchError((error) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching books: $error')));
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchBooks();
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge && _scrollController.position.pixels != 0 && !isLoading) {
        _fetchBooks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Books'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                books.clear();
                currentPage = 1; // Reset page count to fetch from the first page
                _fetchBooks(query: _searchController.text);
              }
            },
          )
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
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    // Clear current book list, reset page counter, and fetch books based on the search query
                    books.clear();
                    currentPage = 1;
                    _fetchBooks(query: _searchController.text.trim());  // Ensure we trim the text to remove any leading/trailing whitespaces
                  },
                ),
              ),
              onSubmitted: (value) {
                // Also initiate search when keyboard search is pressed
                books.clear();
                currentPage = 1;
                _fetchBooks(query: value.trim());  // Same trim here
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: books.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == books.length) {
                  return Center(child: CircularProgressIndicator());
                } else {
                  final book = books[index];
                  return Card(
                    child: ListTile(
                      leading: CachedNetworkImage(
                        imageUrl: book.imageUrl!,
                        placeholder: (context, url) => CircularProgressIndicator(),
                        errorWidget: (context, url, error) => Icon(Icons.error),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                      title: Text(book.title),
                      subtitle: Text(book.author),
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => BookDetailScreen(biblioId: book.biblioId)
                            )
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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;

import '../models/book_response.dart';
import '../services/KohaApiService.dart';
import 'BookDetailScreen.dart';

class BooksListScreen extends StatefulWidget {
  @override
  _BooksListScreenState createState() => _BooksListScreenState();
}

class _BooksListScreenState extends State<BooksListScreen> {
  final ScrollController _scrollController = ScrollController();
  bool showScrollToTopButton = false;

  List<BookResponse> books = [];
  int currentPage = 1;
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  String currentQuery = '';
  Set<String> favoriteBookIds = {};
  bool showFavoritesOnly = false;
  Map<String, String> readingStatus = {};
  String selectedStatusFilter = 'All';

  final List<String> statuses = ['Reading', 'Completed', 'Want to Read'];
  final Map<String, Color> statusColors = {
    'Reading': Colors.orange,
    'Completed': Colors.green,
    'Want to Read': Colors.blue,
    'None': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadReadingStatuses();
    _fetchBooks();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels > 300) {
        if (!showScrollToTopButton) {
          setState(() => showScrollToTopButton = true);
        }
      } else {
        if (showScrollToTopButton) {
          setState(() => showScrollToTopButton = false);
        }
      }

      if (_scrollController.position.atEdge &&
          _scrollController.position.pixels != 0 &&
          !isLoading &&
          !showFavoritesOnly) {
        _fetchBooks(reset: false);
      }
    });

    _searchController.addListener(() {
      _onSearchChanged(_searchController.text);
      setState(() {});
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
        SnackBar(content: Text('error_fetching_books'.tr(args: [error.toString()]))),
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

  Future<void> _loadReadingStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('readingStatusMap');
    if (stored != null) {
      final Map<String, dynamic> decoded = json.decode(stored);
      setState(() {
        readingStatus = decoded.map((key, value) => MapEntry(key, value.toString()));
      });
    }
  }

  Future<void> _updateReadingStatus(String biblioId, String status) async {
    setState(() {
      readingStatus[biblioId] = status;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('readingStatusMap', json.encode(readingStatus));

    Fluttertoast.showToast(
      msg: tr('marked_as', args: [status]),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: statusColors[status] ?? Colors.blueAccent,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _toggleFavorite(dynamic bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookIdStr = bookId.toString();
    final isRemoving = favoriteBookIds.contains(bookIdStr);

    setState(() {
      if (isRemoving) {
        favoriteBookIds.remove(bookIdStr);
      } else {
        favoriteBookIds.add(bookIdStr);
      }
    });

    await prefs.setStringList('favoriteBookIds', favoriteBookIds.toList());

    Fluttertoast.showToast(
      msg: isRemoving ? tr('removed_from_favorites') : tr('added_to_favorites'),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  List<BookResponse> get _displayedBooks {
    List<BookResponse> filtered = books;

    if (showFavoritesOnly) {
      filtered = filtered.where((book) => favoriteBookIds.contains(book.biblioId.toString())).toList();
    }

    if (selectedStatusFilter != 'All') {
      filtered = filtered
          .where((book) => readingStatus[book.biblioId.toString()] == selectedStatusFilter)
          .toList();
    }

    return filtered;
  }

  void _showStatusFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ['All'.tr(), ...statuses].map((status) {
                return ListTile(
                  title: Text(status),
                  leading: Icon(
                    selectedStatusFilter == status ? Icons.check_circle : Icons.circle_outlined,
                    color: selectedStatusFilter == status
                        ? const Color(0xFF00AFFF)
                        : Colors.grey,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      selectedStatusFilter = status;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showReadingStatusSheet(String biblioId) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: statuses.map((status) {
              return ListTile(
                title: Text(status),
                leading: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColors[status],
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _updateReadingStatus(biblioId, status);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Updated _addToKart method using Koha book bags (virtual shelves)
  Future<void> _addToKart(int biblioitemnumber) async {
    final prefs = await SharedPreferences.getInstance();
    final cardnumber = prefs.getString('cardnumber') ?? '';
    final password = prefs.getString('password') ?? '';

    if (cardnumber.isEmpty || password.isEmpty) {
      Fluttertoast.showToast(
        msg: tr('login_required_to_add_to_kart'),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    final String basicAuth = base64Encode(utf8.encode('$cardnumber:$password'));

    // First, get the user’s default or first virtual shelf (book bag)
    final shelfUrl = Uri.parse('https://library.al-burhaan.org/api/v1/patrons/$cardnumber/virtualshelves');
    final shelfHeaders = {
      'Authorization': 'Basic $basicAuth',
      'Accept': 'application/json',
    };

    try {
      final shelfResponse = await http.get(shelfUrl, headers: shelfHeaders);
      if (shelfResponse.statusCode == 200) {
        final shelves = jsonDecode(shelfResponse.body);
        if (shelves.isEmpty) {
          Fluttertoast.showToast(
            msg: tr('no_virtual_shelf_found'),
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          return;
        }

        final shelfId = shelves[0]['shelfnumber'];

        final addUrl = Uri.parse(
            'https://library.al-burhaan.org/api/v1/virtualshelves/$shelfId/items');
        final addHeaders = {
          'Authorization': 'Basic $basicAuth',
          'Content-Type': 'application/json',
        };
        final addBody = jsonEncode({'biblioitemnumber': biblioitemnumber});

        final addResponse = await http.post(addUrl, headers: addHeaders, body: addBody);

        if (addResponse.statusCode == 200 || addResponse.statusCode == 201) {
          Fluttertoast.showToast(
            msg: tr('added_to_kart'),
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        } else {
          Fluttertoast.showToast(
            msg: tr('failed_to_add_to_kart'),
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: tr('failed_to_retrieve_shelves'),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '${tr('error')}: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const double imageSize = 80.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('books'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'filter_by_status'.tr(),
            onPressed: _showStatusFilterSheet,
          ),
          IconButton(
            icon: Icon(showFavoritesOnly ? Icons.favorite : Icons.favorite_border),
            tooltip: showFavoritesOnly ? 'show_all_books'.tr() : 'show_favorites'.tr(),
            onPressed: () {
              setState(() {
                showFavoritesOnly = !showFavoritesOnly;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: tr('view_cart'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'search_for_books'.tr(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: InputBorder.none,
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
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _displayedBooks.length + (isLoading && !showFavoritesOnly ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _displayedBooks.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else {
                      final book = _displayedBooks[index];
                      final isFavorite = favoriteBookIds.contains(book.biblioId.toString());
                      final currentStatus = readingStatus[book.biblioId.toString()] ?? 'no_status_set'.tr();

                      return TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: ClipRRect(
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
                                  fit: BoxFit.contain, // This makes image fit on list.
                                ),
                              ),
                              title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(book.author),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => _showReadingStatusSheet(book.biblioId.toString()),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: statusColors[currentStatus] ?? Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          currentStatus == 'None' ? 'no_status_set'.tr() : currentStatus,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const Icon(Icons.arrow_drop_down),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isFavorite ? Icons.favorite : Icons.favorite_border,
                                      color: isFavorite ? Colors.blueAccent : null,
                                    ),
                                    onPressed: () => _toggleFavorite(book.biblioId),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_shopping_cart),
                                    tooltip: tr('add_to_kart'),
                                    onPressed: () {
                                      if (book.biblionumber != null) {
                                        _addToKart(book.biblionumber!);
                                      } else {
                                        Fluttertoast.showToast(msg: tr('no_item_number_available'));
                                      }
                                    },
                                  ),
                                ],
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
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          // Floating Scroll to Top Button
          Positioned(
            bottom: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: showScrollToTopButton ? 1.0 : 0.0,
              child: FloatingActionButton(
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  );
                },
                backgroundColor: Colors.blueAccent,
                child: const Icon(Icons.arrow_upward),
                tooltip: 'scroll_to_top'.tr(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Placeholder CartScreen to avoid errors, implement as needed
class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('cart')),
      ),
      body: Center(
        child: Text(tr('cart_is_empty')),
      ),
    );
  }
}

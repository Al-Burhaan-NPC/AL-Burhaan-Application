import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/book_response.dart';
import '../models/BookDetail.dart';
import '../services/KohaApiService.dart';

// Bottom sheet class for displaying book details
class BookDetailBottomSheet {
  static Widget detailSection(String titleKey, String? content) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              titleKey.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              content,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _launchURL(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('could_not_open_link'.tr())),
      );
    }
  }

  static void showBookDetailsBottomSheet(BuildContext context, int biblioId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              color: Theme.of(context).canvasColor,
              child: FutureBuilder<BookDetail>(
                future: KohaApiService().fetchBookDetail(biblioId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    final book = snapshot.data!;
                    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                    return SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                          if (book.imageUrl != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 20.0),
                              child: Image.network(
                                book.imageUrl!,
                                width: MediaQuery.of(context).size.width,
                                height: 200,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                const Center(child: Icon(Icons.image_not_supported, size: 100)),
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.shadow,
                                  offset: Offset(4, 4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                                  offset: Offset(-4, -4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  detailSection("title", book.title),
                                  detailSection("author", book.author),
                                  detailSection("isbn", book.isbn),
                                  detailSection("publisher", book.publisher),
                                  detailSection("publication_year", book.publicationYear),
                                  detailSection("shelf_number", book.shelfNumber),
                                  detailSection("call_number", book.callNumber),
                                  detailSection("language", book.language),
                                  detailSection("physical_description", book.physicalDescription),
                                  detailSection("series", book.series),
                                  detailSection("notes", book.notes),
                                  if (book.ebookUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16.0),
                                      child: ElevatedButton.icon(
                                        onPressed: () => _launchURL(book.ebookUrl!, context),
                                        icon: const Icon(Icons.open_in_new),
                                        label: Text('read_ebook'.tr()),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueAccent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'error'.tr() + ': ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            );
          },
        );
      },
    );
  }
}

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

  Future<void> _fetchBooks({bool reset = false, String? query}) {
    return Future(() async {
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

  Future<void> _savePendingHold(BookResponse book) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingHolds = prefs.getStringList('pendingHolds') ?? [];
    final holdData = json.encode({
      'biblioId': book.biblioId,
      'title': book.title,
      'author': book.author ?? 'Unknown',
      'timestamp': DateTime.now().toIso8601String(),
    });
    pendingHolds.add(holdData);
    await prefs.setStringList('pendingHolds', pendingHolds);
  }

  Future<void> _placeHold(BookResponse book) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = prefs.getString('auth') ?? '';
    final patronId = prefs.getString('patron_id') ?? '74';

    if (auth.isEmpty) {
      Fluttertoast.showToast(
        msg: tr('login_required_to_place_hold'),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    final headers = {
      'Authorization': 'Basic $auth',
      'x-koha-session': prefs.getString('session_token') ?? '',
      'Accept': 'application/json',
    };
    final holdsUrl = Uri.parse('https://library.al-burhaan.org/api/v1/patrons/$patronId/holds');
    final response = await http.get(holdsUrl, headers: headers).timeout(const Duration(seconds: 10));
    List<dynamic> currentHolds = [];
    if (response.statusCode == 200) {
      currentHolds = jsonDecode(response.body);
    }

    final currentHoldsCount = currentHolds.length + (prefs.getStringList('pendingHolds')?.length ?? 0);
    if (currentHoldsCount >= 5) {
      Fluttertoast.showToast(
        msg: tr('hold_limit_reached', args: ['5']),
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    if (book.biblioId <= 0) {
      Fluttertoast.showToast(
        msg: tr('invalid_biblio_id'),
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('confirm_hold_request')),
        content: Text(tr('place_hold_for', args: [book.title])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);

    try {
      final headers = {
        'Authorization': 'Basic $auth',
        'x-koha-session': prefs.getString('session_token') ?? '',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      final expiryDate = DateTime.now().add(const Duration(days: 3)).toIso8601String().split('T')[0];
      final body = json.encode({
        'patron_id': patronId,
        'biblio_id': book.biblioId,
        'pickup_library_id': 'AlB',
        'expiration_date': expiryDate,
      });

      final response = await http.post(
        Uri.parse('https://library.al-burhaan.org/api/v1/holds'),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        Fluttertoast.showToast(
          msg: tr('hold_placed_successfully'),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        String errorMsg = tr('failed_to_place_hold');
        if (response.statusCode == 401) {
          errorMsg = tr('authentication_failed');
        } else if (response.statusCode == 400) {
          errorMsg = tr('invalid_hold_request');
        } else if (response.statusCode == 403) {
          errorMsg = tr('no_permission_to_place_hold');
        }

        if (response.statusCode >= 500 || response.statusCode == 0) {
          await _savePendingHold(book);
          errorMsg = tr('hold_saved_offline');
        }

        Fluttertoast.showToast(
          msg: '$errorMsg: ${response.statusCode} - ${response.body}',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      await _savePendingHold(book);
      Fluttertoast.showToast(
        msg: tr('error_placing_hold', args: [e.toString()]),
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    const double imageSize = 80.0;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
            icon: const Icon(Icons.bookmark),
            tooltip: tr('view_holds'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HoldsScreen()),
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
                  color: Theme.of(context).colorScheme.surface,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.identity()..scale(_searchController.text.isEmpty ? 1.0 : 1.02),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'search_for_books'.tr(),
                        hintStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color:Colors.blueAccent),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.blueAccent),
                          onPressed: () {
                            _searchController.clear();
                            _fetchBooks(reset: true);
                          },
                        )
                            : null,
                      ),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        _fetchBooks(reset: true, query: value.trim());
                      },
                    ),
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
                          child: GestureDetector(
                            onTapDown: (_) {
                              setState(() => _scaleAnimation = 0.95);
                            },
                            onTapUp: (_) {
                              setState(() => _scaleAnimation = 1.0);
                              BookDetailBottomSheet.showBookDetailsBottomSheet(context, book.biblioId);
                            },
                            onTapCancel: () {
                              setState(() => _scaleAnimation = 1.0);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              transform: Matrix4.identity()..scale(_scaleAnimation),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.shadow,
                                      offset: Offset(4, 4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                    BoxShadow(
                                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                                      offset: Offset(-4, -4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
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
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  title: Text(
                                    book.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.author,
                                        style: TextStyle(
                                          color: Theme.of(context).textTheme.bodyMedium?.color,
                                          fontSize: 13,
                                        ),
                                      ),
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
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Theme.of(context).textTheme.bodyMedium?.color,
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_drop_down,
                                              color: Theme.of(context).iconTheme.color,
                                            ),
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
                                          color: isFavorite ? Colors.blueAccent : Theme.of(context).iconTheme.color,
                                        ),
                                        onPressed: () => _toggleFavorite(book.biblioId),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.bookmark_add,
                                          color: Theme.of(context).iconTheme.color,
                                        ),
                                        tooltip: tr('place_hold'),
                                        onPressed: () {
                                          if (book.biblioId != null) {
                                            _placeHold(book);
                                          } else {
                                            Fluttertoast.showToast(msg: tr('no_biblio_id_available'));
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
          Positioned(
            bottom: 85,
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

  double _scaleAnimation = 1.0;
}

class HoldsScreen extends StatefulWidget {
  const HoldsScreen({Key? key}) : super(key: key);

  @override
  _HoldsScreenState createState() => _HoldsScreenState();
}

class _HoldsScreenState extends State<HoldsScreen> {
  List<dynamic> holds = [];
  List<Map<String, dynamic>> pendingHolds = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHolds();
    _loadPendingHolds();
  }

  Future<void> _loadPendingHolds() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingHoldsList = prefs.getStringList('pendingHolds') ?? [];
    setState(() {
      pendingHolds = pendingHoldsList
          .map((hold) => json.decode(hold) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _fetchHolds() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = prefs.getString('auth') ?? '';
    final patronId = prefs.getString('patron_id') ?? '74';

    if (auth.isEmpty) {
      Fluttertoast.showToast(
        msg: tr('login_required_to_view_holds'),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      setState(() => isLoading = false);
      return;
    }

    final headers = {
      'Authorization': 'Basic $auth',
      'x-koha-session': prefs.getString('session_token') ?? '',
      'Accept': 'application/json',
    };

    final holdsUrl = Uri.parse('https://library.al-burhaan.org/api/v1/patrons/$patronId/holds');

    try {
      final response = await http.get(holdsUrl, headers: headers).timeout(const Duration(seconds: 10));
      print('Holds Fetch Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          holds = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        Fluttertoast.showToast(
          msg: '${tr('error_fetching_holds')}: ${response.statusCode} - ${response.body}',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        setState(() => isLoading = false);
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
      setState(() => isLoading = false);
    }
  }

  Future<void> _cancelHold(int holdId) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = prefs.getString('auth') ?? '';

    if (auth.isEmpty) {
      Fluttertoast.showToast(
        msg: tr('login_required_to_cancel_hold'),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    final headers = {
      'Authorization': 'Basic $auth',
      'x-koha-session': prefs.getString('session_token') ?? '',
      'Accept': 'application/json',
    };

    final cancelUrl = Uri.parse('https://library.al-burhaan.org/api/v1/holds/$holdId');
    try {
      final response = await http.delete(cancelUrl, headers: headers);
      if (response.statusCode == 204) {
        Fluttertoast.showToast(
          msg: tr('hold_cancelled_successfully'),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        await _fetchHolds();
      } else {
        Fluttertoast.showToast(
          msg: '${tr('failed_to_cancel_hold')}: ${response.statusCode} - ${response.body}',
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

  Future<void> _cancelPendingHold(String biblioId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingHoldsList = prefs.getStringList('pendingHolds') ?? [];
    pendingHoldsList.removeWhere((hold) {
      final holdData = json.decode(hold) as Map<String, dynamic>;
      return holdData['biblioId'].toString() == biblioId;
    });
    await prefs.setStringList('pendingHolds', pendingHoldsList);
    await _loadPendingHolds();
    Fluttertoast.showToast(
      msg: tr('pending_hold_cancelled'),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allHolds = [
      ...pendingHolds.map((hold) => {
        'biblioId': hold['biblioId'],
        'isPending': true,
      }),
      ...holds.map((hold) => {
        'biblioId': hold['biblio_id'] ?? hold['biblioId'],
        'hold_id': hold['hold_id'],
      }),
    ];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('holds'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : allHolds.isEmpty
          ? Center(child: Text(tr('no_holds')))
          : ListView.builder(
        itemCount: allHolds.length,
        itemBuilder: (context, index) {
          final hold = allHolds[index];
          final isPending = hold['isPending'] == true;
          final biblioId = hold['biblioId'] as int;

          return FutureBuilder<BookDetail>(
            future: KohaApiService().fetchBookDetail(biblioId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                final book = snapshot.data!;
                final currentStatus = isPending ? tr('pending_email') : (hold['status'] ?? 'Pending');
                final isFavorite = false;

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
                    child: GestureDetector(
                      onTapDown: (_) {
                        setState(() => _scaleAnimation = 0.95);
                      },
                      onTapUp: (_) {
                        setState(() => _scaleAnimation = 1.0);
                        BookDetailBottomSheet.showBookDetailsBottomSheet(context, biblioId);
                      },
                      onTapCancel: () {
                        setState(() => _scaleAnimation = 1.0);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform: Matrix4.identity()..scale(_scaleAnimation),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.shadow,
                                offset: Offset(4, 4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                                offset: Offset(-4, -4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: book.imageUrl ?? '',
                                placeholder: (context, url) => SizedBox(
                                  width: 80.0,
                                  height: 80.0,
                                  child: const Center(child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) =>
                                const Icon(Icons.broken_image, size: 80.0),
                                width: 80.0,
                                height: 80.0,
                                fit: BoxFit.contain,
                              ),
                            ),
                            title: Text(
                              book.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.author ?? 'Unknown Author',
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isPending ? Colors.grey : Colors.green,
                                      ),
                                    ),
                                    Text(
                                      currentStatus,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context).textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.cancel,
                                    color: Theme.of(context).iconTheme.color,
                                  ),
                                  tooltip: tr(isPending ? 'cancel_pending_hold' : 'cancel_hold'),
                                  onPressed: () => isPending
                                      ? _cancelPendingHold(biblioId.toString())
                                      : _cancelHold(hold['hold_id']),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
            },
          );
        },
      ),
    );
  }

  double _scaleAnimation = 1.0;
}
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
    final cardnumber = prefs.getString('cardnumber') ?? '';

    if (cardnumber.isEmpty) {
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
        content: Text(tr('send_hold_email_confirmation', args: [book.title])),
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

    final libraryEmail = 'library@al-burhaan.org'; // Change to our email.
    final result = await _sendHoldEmail(
      cardnumber: cardnumber,
      book: book,
      libraryEmail: libraryEmail,
    );

    if (result) {
      await _savePendingHold(book);
      Fluttertoast.showToast(
        msg: tr('hold_email_sent'),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } else {
      Fluttertoast.showToast(
        msg: tr('failed_to_open_email'),
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<bool> _sendHoldEmail({
    required String cardnumber,
    required BookResponse book,
    required String libraryEmail,
  }) async {
    try {
      final subject = Uri.encodeComponent('Hold Request for Book: ${book.title}');
      final body = Uri.encodeComponent('''
Hold Request Details:
Patron Card Number: $cardnumber
Book Title: ${book.title}
Author: ${book.author ?? 'Unknown'}
Biblio ID: ${book.biblioId}
Please process this hold request for the patron.
''');
      final mailtoUri = Uri.parse('mailto:$libraryEmail?subject=$subject&body=$body');
      return await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      return false;
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
                                  fit: BoxFit.contain,
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
                                    icon: const Icon(Icons.bookmark_add),
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
    final cardnumber = prefs.getString('cardnumber') ?? '';
    final password = prefs.getString('password') ?? '';

    if (cardnumber.isEmpty || password.isEmpty) {
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

    final String basicAuth = base64Encode(utf8.encode('$cardnumber:$password'));

    final holdsUrl = Uri.parse('https://library.al-burhaan.org/api/v1/patrons/$cardnumber/holds');
    final headers = {
      'Authorization': 'Basic $basicAuth',
      'Accept': 'application/json',
    };

    try {
      final response = await http.get(holdsUrl, headers: headers);
      if (response.statusCode == 200) {
        setState(() {
          holds = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        Fluttertoast.showToast(
          msg: tr('viewing_holds'),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
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
    final cardnumber = prefs.getString('cardnumber') ?? '';
    final password = prefs.getString('password') ?? '';

    final String basicAuth = base64Encode(utf8.encode('$cardnumber:$password'));

    final cancelUrl = Uri.parse('https://library.al-burhaan.org/api/v1/holds/$holdId');
    final headers = {
      'Authorization': 'Basic $basicAuth',
      'Accept': 'application/json',
    };

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
          msg: tr('failed_to_cancel_hold'),
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
        'biblio': {
          'title': hold['title'],
          'author': hold['author'],
        },
        'status': tr('pending_email'),
        'pickup_library_id': 'MAIN',
        'biblioId': hold['biblioId'],
        'isPending': true,
      }),
      ...holds,
    ];

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
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(hold['biblio']['title'] ?? 'Unknown Title'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hold['biblio']['author'] ?? 'Unknown Author'),
                  Text('Status: ${hold['status'] ?? 'Pending'}'),
                  Text('Pickup Library: ${hold['pickup_library_id'] ?? 'MAIN'}'),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.cancel),
                tooltip: tr(isPending ? 'cancel_pending_hold' : 'cancel_hold'),
                onPressed: () => isPending
                    ? _cancelPendingHold(hold['biblioId'].toString())
                    : _cancelHold(hold['hold_id']),
              ),
            ),
          );
        },
      ),
    );
  }
}
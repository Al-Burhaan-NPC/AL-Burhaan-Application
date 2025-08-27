import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/book_response.dart';
import '../../models/BookDetail.dart';
import '../../services/KohaApiService.dart';
import '../../widget/books_list_screen.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

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
        SnackBar(
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow,
                  offset: Offset(4, 4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade700
                      : Colors.grey.shade200,
                  offset: Offset(-4, -4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              'could_not_open_link'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
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
            return FutureBuilder<BookDetail>(
              future: KohaApiService().fetchBookDetail(biblioId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  final book = snapshot.data!;
                  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    color: Theme.of(context).canvasColor,
                    child: SingleChildScrollView(
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
            );
          },
        );
      },
    );
  }
}

class PublicHomePage extends StatefulWidget {
  const PublicHomePage({Key? key}) : super(key: key);

  @override
  State<PublicHomePage> createState() => _PublicHomePageState();
}

class _PublicHomePageState extends State<PublicHomePage> {
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    const _LibraryDashboard(),
    BooksListScreen(),
    const ProfilePage(),
    SettingsPage(),
  ];

  List<String> get _titles =>
      [
        "dashboard".tr(),
        "",
        "profile".tr(),
        "settings".tr(),
      ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 1
          ? null
          : AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
        physics: const BouncingScrollPhysics(),
      ),
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Container(
          decoration: ShapeDecoration(
            color: Colors.grey.shade900.withOpacity(0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            shadows: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onTabTapped,
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: false,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_filled, size: 30),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.book_rounded, size: 30),
                label: 'Books',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded, size: 30),
                label: 'Profile',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_rounded, size: 30),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryDashboard extends StatefulWidget {
  const _LibraryDashboard({Key? key}) : super(key: key);

  @override
  State<_LibraryDashboard> createState() => _LibraryDashboardState();
}

class _LibraryDashboardState extends State<_LibraryDashboard>
    with SingleTickerProviderStateMixin {
  List<BookResponse> allBooks = [];
  List<BookResponse> favoriteBooks = [];
  Set<String> favoriteIds = {};
  bool isLoading = true;
  bool isLoggedIn = false;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _checkLoginStatus();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _logoAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    });
  }

  Future<void> _loadDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('favoriteBookIds') ?? [];

    try {
      final books = await KohaApiService().fetchBooks(1);
      setState(() {
        allBooks = books;
        favoriteIds = favs.toSet();
        favoriteBooks = books
            .where((b) => favoriteIds.contains(b.biblioId.toString()))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow,
                  offset: Offset(4, 4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade700
                      : Colors.grey.shade200,
                  offset: Offset(-4, -4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              'failed_load_dashboard'.tr(args: [e.toString()]),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
      );
    }
  }

  Widget _buildAnimatedTile(String text, IconData icon, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 600),
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            onTap();
          },
          onTapCancel: () => _controller.reverse(),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 0.95).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 160,
              height: 160,
              margin: const EdgeInsets.all(8),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Theme.of(context).iconTheme.color, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ).tr(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              alignment: WrapAlignment.start,
              children: [
                _buildAnimatedTile('favorites'.tr(), Icons.favorite, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookListPage(
                        title: 'favorites'.tr(),
                        books: favoriteBooks,
                      ),
                    ),
                  );
                }),
                _buildAnimatedTile('recommended'.tr(), Icons.thumb_up, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookListPage(
                        title: 'recommended'.tr(),
                        books: allBooks,
                      ),
                    ),
                  );
                }),
                _buildAnimatedTile('new_arrivals'.tr(), Icons.new_releases, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
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
                        child: Text(
                          'coming_soon'.tr(),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.transparent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  );
                }),
                _buildAnimatedTile('categories'.tr(), Icons.category, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
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
                        child: Text(
                          'coming_soon'.tr(),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.transparent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookListPage extends StatefulWidget {
  final String title;
  final List<BookResponse> books;

  const BookListPage({Key? key, required this.title, required this.books})
      : super(key: key);

  @override
  _BookListPageState createState() => _BookListPageState();
}

class _BookListPageState extends State<BookListPage> {
  double _scaleAnimation = 1.0;

  Widget _buildBookItem(BuildContext context, BookResponse book) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
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
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => SizedBox(
                    width: 80,
                    height: 80,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const SizedBox(
                    width: 80,
                    height: 80,
                    child: Icon(Icons.broken_image, size: 80),
                  ),
                ),
              ),
              title: Text(
                book.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              subtitle: Text(
                book.author,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: widget.books.isEmpty
          ? Center(child: Text('no_books_found'.tr()))
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.books.length,
        itemBuilder: (context, index) {
          return _buildBookItem(context, widget.books[index]);
        },
      ),
    );
  }
}
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
            return FutureBuilder<BookDetail>(
              future: KohaApiService().fetchBookDetail(biblioId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  final book = snapshot.data!;
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
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.6),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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

  List<String> get _titles => [
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: 'home'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book),
            label: 'books'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: 'profile'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: 'settings'.tr(),
          ),
        ],
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
        SnackBar(content: Text('failed_load_dashboard'.tr(args: [e.toString()]))),
      );
    }
  }

  Widget _buildAnimatedTile(String text, IconData icon, VoidCallback onTap) {
    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 600),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            width: 160,
            height: 160,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  text,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ).tr(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
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
            ],
          ),
        ),
      ],
    );
  }
}

class BookListPage extends StatelessWidget {
  final String title;
  final List<BookResponse> books;

  const BookListPage({Key? key, required this.title, required this.books})
      : super(key: key);

  Widget _buildBookItem(BuildContext context, BookResponse book) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: book.imageUrl ?? '',
          width: 50,
          height: 70,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) => const Icon(Icons.broken_image),
        ),
      ),
      title: Text(book.title),
      subtitle: Text(book.author),
      onTap: () {
        // Show bottom sheet instead of navigating to BookDetailScreen
        BookDetailBottomSheet.showBookDetailsBottomSheet(context, book.biblioId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: books.isEmpty
          ? Center(child: Text('no_books_found'.tr()))
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: books.length,
        itemBuilder: (context, index) {
          return _buildBookItem(context, books[index]);
        },
      ),
    );
  }
}
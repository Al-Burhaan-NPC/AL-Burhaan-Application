import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../widget/books_list_screen.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/book_response.dart';
import '../../services/KohaApiService.dart';
import '../../widget/BookDetailScreen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

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
        if (!isLoggedIn)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                // Navigate to LoginScreen and wait for result
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                // Check if login was successful
                if (result == true) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isLoggedIn', true);
                  setState(() {
                    isLoggedIn = true;
                  });
                }
              },
              icon: const Icon(Icons.login, color: Colors.white),
              label: Text(
                'login'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
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
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BookDetailScreen(biblioId: book.biblioId)),
        );
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
          )),
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
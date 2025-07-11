import 'package:flutter/material.dart';
import '../../widget/books_list_screen.dart';
import 'settings_page.dart';
import 'profile_page.dart';  // Import ProfilePage

class PublicHomePage extends StatefulWidget {
  const PublicHomePage({Key? key}) : super(key: key);

  @override
  State<PublicHomePage> createState() => _PublicHomePageState();
}

class _PublicHomePageState extends State<PublicHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const Center(child: Text("Welcome to Al-Burhaan Library!")),
    BooksListScreen(),
    const ProfilePage(),  // Use the real ProfilePage here
    const SettingsPage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<String> _titles = ["Home", "", "Profile", "Settings"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 1
          ? null // Hides AppBar for Books tab
          : AppBar(title: Text(_titles[_selectedIndex])),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Books',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

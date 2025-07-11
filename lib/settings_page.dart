import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // Assuming you define themeNotifier globally here

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  void _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedTheme = value ? ThemeMode.dark : ThemeMode.light;

    themeNotifier.value = selectedTheme;
    await prefs.setString('themeMode', value ? 'dark' : 'light');
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clears all saved data (auth, cardnumber, etc.)

    // Navigate to login screen
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, currentMode, _) {
          final isDarkMode = currentMode == ThemeMode.dark;

          return ListView(
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: isDarkMode,
                onChanged: _toggleTheme,
                activeColor: Colors.blueAccent,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

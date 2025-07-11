import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';
import 'login_screen.dart';

// Global theme notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Load saved theme
  final savedTheme = prefs.getString('themeMode');
  if (savedTheme == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  } else {
    themeNotifier.value = ThemeMode.light;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: 'Koha Books Viewer',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(), // Always show splash first
          routes: {
            '/home': (_) => const SplashScreen(), // You can replace with your actual home
            '/login': (_) => const LoginScreen(),
          },
        );
      },
    );
  }
}

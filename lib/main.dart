import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'splash_screen.dart';
import 'login_screen.dart';

// Global theme notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// Global locale notifier
final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Load saved theme
  final savedTheme = prefs.getString('themeMode');
  if (savedTheme == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  } else {
    themeNotifier.value = ThemeMode.light;
  }

  // Load saved locale or default to English
  final savedLocaleCode = prefs.getString('localeCode') ?? 'en';
  localeNotifier.value = Locale(savedLocaleCode);

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
        Locale('ar'),
        Locale('zu'),
        Locale('af'),
      ],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder2<ThemeMode, Locale>(
      first: themeNotifier,
      second: localeNotifier,
      builder: (context, currentMode, currentLocale, _) {
        return MaterialApp(
          key: ValueKey(currentLocale.languageCode),
          title: 'Koha Books Viewer',
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueAccent,
              brightness: Brightness.light,
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: Colors.blueAccent,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black, // True black for Scaffold
            cardColor: Colors.black, // True black for Cards
            primarySwatch: Colors.blue,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueAccent,
              brightness: Brightness.dark,
              background: Colors.black, // True black for background
              surface: Colors.black, // True black for surfaces
              onBackground: Colors.white, // Text/icon color for contrast
              onSurface: Colors.white, // Text/icon color for contrast
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black, // True black for AppBar
              foregroundColor: Colors.white, // Text/icon color for contrast
            ),
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: Colors.blueAccent,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
          ),
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
          routes: {
            '/home': (_) => const SplashScreen(),
            '/login': (_) => const LoginScreen(),
          },
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: currentLocale,
        );
      },
    );
  }
}

// Helper widget to listen to two ValueNotifiers simultaneously
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueNotifier<A> first;
  final ValueNotifier<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  const ValueListenableBuilder2({
    Key? key,
    required this.first,
    required this.second,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, valueA, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, valueB, __) {
            return builder(context, valueA, valueB, null);
          },
        );
      },
    );
  }
}
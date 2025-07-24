import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cardNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;

  static const String kohaBaseUrl = 'https://library.al-burhaan.org';

  Future<void> _login() async {
    final cardnumber = _cardNumberController.text.trim();
    final password = _passwordController.text;

    if (cardnumber.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('enter_card_password'.tr())),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final authString = base64Encode(utf8.encode('$cardnumber:$password'));
      final headers = {'Authorization': 'Basic $authString'};

      final authResponse = await http.get(
        Uri.parse('$kohaBaseUrl/api/v1/patrons?me=1'),
        headers: headers,
      );

      if (authResponse.statusCode == 200) {
        final data = jsonDecode(authResponse.body);
        if (data['cardnumber'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth', authString);
          await prefs.setString('cardnumber', cardnumber);
          await prefs.setString('password', password);
          await prefs.setString('userid', data['userid'] ?? '');
          await prefs.setString('firstname', data['firstname'] ?? '');
          await prefs.setString('surname', data['surname'] ?? '');
          await prefs.setString('email', data['email'] ?? '');

          Navigator.pushReplacementNamed(context, '/home');
        } else {
          throw Exception('invalid_credentials'.tr());
        }
      } else {
        throw Exception('invalid_credentials'.tr());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('login_failed'.tr(args: [e.toString()]))),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('forgot_password_not_implemented'.tr())),
    );
  }

  void _registerAccount() async {
    final url = Uri.parse('https://library.al-burhaan.org/cgi-bin/koha/opac-memberentry.pl');

    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) throw 'Launch blocked';
    } catch (e) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebViewScreen(
            title: 'register_account'.tr(),
            url: url.toString(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('koha_login'.tr())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/logo1.png',
                      height: 225,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'login_to_alburhaan'.tr(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _cardNumberController,
                decoration: InputDecoration(
                  labelText: 'library_card_number'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'password'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text('login'.tr(), style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _forgotPassword,
                child: Text(
                  'forgot_password'.tr(),
                  style: const TextStyle(color: Colors.blueAccent),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('dont_have_account'.tr()),
                  TextButton(
                    onPressed: _registerAccount,
                    child: Text(
                      'register'.tr(),
                      style: const TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(seconds: 2),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Koha Version 25',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const WebViewScreen({Key? key, required this.title, required this.url}) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    final params = const PlatformWebViewControllerCreationParams();
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          setState(() => _isLoading = false);
        },
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:html/parser.dart' show parse;

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

    if (cardnumber.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('invalid_card_number'.tr())),
      );
      return;
    }

    setState(() => isLoading = true);

    final client = http.Client();
    try {
      final authString = base64Encode(utf8.encode('$cardnumber:$password'));
      print('Auth String: $authString'); // Debug
      final headers = {
        'Authorization': 'Basic $authString',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      // Try GET request to /api/v1/patrons/$cardnumber
      final authResponse = await client.get(
        Uri.parse('$kohaBaseUrl/api/v1/patrons/$cardnumber'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      print('GET Status Code: ${authResponse.statusCode}'); // Debug
      print('GET Response Body: ${authResponse.body}'); // Debug
      print('GET Response Headers: ${authResponse.headers}'); // Debug

      if (authResponse.statusCode == 200) {
        try {
          final responseData = jsonDecode(authResponse.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth', authString);
          await prefs.setString('cardnumber', cardnumber);
          await prefs.setString('patron_id', responseData['patron_id']?.toString() ?? '');

          final sessionToken = authResponse.headers['x-koha-session'] ?? '';
          if (sessionToken.isNotEmpty) {
            await prefs.setString('session_token', sessionToken);
          }

          Navigator.pushReplacementNamed(context, '/home');
        } on FormatException {
          throw Exception('invalid_response_format'.tr());
        }
      } else if (authResponse.statusCode == 401) {
        print('API login failed: Invalid credentials'); // Debug
        // Proceed to OPAC login
      } else if (authResponse.statusCode == 403) {
        print('API login failed: Missing permissions'); // Debug
        // Proceed to OPAC login
      } else if (authResponse.statusCode == 404) {
        print('API login failed: Endpoint not found'); // Debug
        // Proceed to OPAC login
      } else {
        throw Exception('server_error'.tr(args: [authResponse.statusCode.toString(), authResponse.body]));
      }

      // Fallback to OPAC login
      final opacPageResponse = await client.get(
        Uri.parse('$kohaBaseUrl/cgi-bin/koha/opac-user.pl'),
      ).timeout(const Duration(seconds: 10));

      print('OPAC Page Status Code: ${opacPageResponse.statusCode}'); // Debug
      print('OPAC Page Response Headers: ${opacPageResponse.headers}'); // Debug

      final cookies = opacPageResponse.headers['set-cookie'] ?? '';
      final opacHeaders = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': cookies,
      };

      String? csrfToken;
      final document = parse(opacPageResponse.body);
      final form = document.querySelector('form[action="/cgi-bin/koha/opac-user.pl"]');
      final hiddenInputs = form?.querySelectorAll('input[type="hidden"]') ?? [];
      final body = <String, String>{
        'password': password,
      };

      for (var input in hiddenInputs) {
        final name = input.attributes['name'];
        final value = input.attributes['value'];
        if (name != null && value != null) {
          body[name] = value;
          if (name == 'csrf_token') {
            csrfToken = value;
            print('CSRF Token: $csrfToken'); // Debug
          }
        }
      }

      final fieldNames = ['userid', 'username', 'login'];
      http.Response? opacResponse;
      String? usedFieldName;

      for (final fieldName in fieldNames) {
        body[fieldName] = cardnumber;

        final encodedBody = body.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');

        opacResponse = await client.post(
          Uri.parse('$kohaBaseUrl/cgi-bin/koha/opac-user.pl'),
          headers: opacHeaders,
          body: encodedBody,
        ).timeout(const Duration(seconds: 10));

        if (opacResponse == null) {
          print('OPAC $fieldName: Response is null'); // Debug
          continue;
        }

        print('OPAC $fieldName Status Code: ${opacResponse.statusCode}'); // Debug
        print('OPAC $fieldName Response Headers: ${opacResponse.headers}'); // Debug
        print('OPAC $fieldName Response Body (excerpt): ${opacResponse.body.length > 500 ? opacResponse.body.substring(0, 500) : opacResponse.body}'); // Debug

        final location = opacResponse.headers['location'] ?? '';
        print('OPAC $fieldName Redirect Location: $location'); // Debug

        String finalResponseBody = opacResponse.body;
        http.Response? redirectResponse;

        if (location.isNotEmpty && location.contains('opac-')) {
          redirectResponse = await client.get(
            Uri.parse(location.startsWith('http') ? location : '$kohaBaseUrl$location'),
            headers: {'Cookie': cookies},
          ).timeout(const Duration(seconds: 10));
          print('OPAC $fieldName Redirect Status Code: ${redirectResponse.statusCode}'); // Debug
          print('OPAC $fieldName Redirect Response Body (excerpt): ${redirectResponse.body.length > 500 ? redirectResponse.body.substring(0, 500) : redirectResponse.body}'); // Debug
          finalResponseBody = redirectResponse.body;
        }

        final errorMessages = [
          'Invalid username or password',
          'Login failed',
          'The username or password you entered is incorrect',
          'Please enter a valid username and password',
          'incorrect',
          'invalid login',
          'authentication failed',
          'error-message',
        ];
        final hasError = finalResponseBody.isNotEmpty && errorMessages.any((msg) => finalResponseBody.toLowerCase().contains(msg.toLowerCase()));
        final hasUserContent = finalResponseBody.isNotEmpty &&
            (finalResponseBody.contains('userdetails') ||
                finalResponseBody.contains('My Summary') ||
                finalResponseBody.contains('My Fines') ||
                finalResponseBody.contains('My Holds') ||
                finalResponseBody.contains(cardnumber));
        final isRedirected = location.contains('opac-account.pl') ||
            location.contains('opac-main.pl') ||
            location.contains('opac-user.pl?opac-user');

        print('OPAC $fieldName Has Error: $hasError'); // Debug
        print('OPAC $fieldName Has User Content: $hasUserContent'); // Debug
        print('OPAC $fieldName Is Redirected: $isRedirected'); // Debug

        if (opacResponse.statusCode == 200 && !hasError && (hasUserContent || isRedirected)) {
          if (redirectResponse != null && redirectResponse.statusCode == 200) {
            final redirectDoc = parse(redirectResponse.body);
            if (redirectDoc.querySelector('#userdetails') != null ||
                redirectDoc.querySelector('.patroninfo') != null) {
              usedFieldName = fieldName;
              break;
            }
          } else if (hasUserContent) {
            usedFieldName = fieldName;
            break;
          }
        }
      }

      if (opacResponse != null && opacResponse.statusCode == 200 && usedFieldName != null) {
        final sessionCookies = opacResponse.headers['set-cookie'] ?? '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth', authString);
        await prefs.setString('cardnumber', cardnumber);
        await prefs.setString('session_cookies', sessionCookies);

        final document = parse(opacResponse.body);
        final patronIdElement = document.querySelector('[data-patron-id]');
        if (patronIdElement != null) {
          await prefs.setString('patron_id', patronIdElement.attributes['data-patron-id'] ?? '');
        }

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        throw Exception('invalid_credentials'.tr());
      }
    } on http.ClientException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('network_error'.tr())),
      );
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('timeout_error'.tr())),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('login_failed'.tr(args: [
              e.toString().contains('invalid_credentials')
                  ? 'Invalid credentials. Please verify your card number and password or try logging in via the library website.'
                  : e.toString()
            ])),
          ),
        );
      }
    } finally {
      client.close();
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
            url: 'https://library.al-burhaan.org/cgi-bin/koha/opac-memberentry.pl',
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
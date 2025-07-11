import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cardNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLoading = false;

  static const String kohaBaseUrl = 'https://library.al-burhaan.org';

  Future<void> _login() async {
    final cardnumber = _cardNumberController.text.trim();
    final password = _passwordController.text;

    if (cardnumber.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter cardnumber and password')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final authString = base64Encode(utf8.encode('$cardnumber:$password'));
      final headers = {'Authorization': 'Basic $authString'};

      final authResponse = await http.get(
        Uri.parse('$kohaBaseUrl/api/v1/'),
        headers: headers,
      );

      if (authResponse.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth', authString);
        await prefs.setString('cardnumber', cardnumber);

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        throw Exception('Invalid credentials. Please check your cardnumber or password.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Koha Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _cardNumberController,
              decoration: const InputDecoration(labelText: 'Library Card Number'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

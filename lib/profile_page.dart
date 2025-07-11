import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _cardnumber;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCardNumber();
  }

  Future<void> _loadCardNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cardnumber = prefs.getString('cardnumber') ?? 'N/A';
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 16),
            Text(
              'Card Number:',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _cardnumber ?? 'N/A',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

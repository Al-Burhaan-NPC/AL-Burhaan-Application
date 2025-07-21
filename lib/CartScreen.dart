import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<dynamic> cartItems = [];
  bool isLoading = true;
  String shelfId = '';
  String cardnumber = '';
  String password = '';

  @override
  void initState() {
    super.initState();
    _loadCredentialsAndFetchCart();
  }

  Future<void> _loadCredentialsAndFetchCart() async {
    final prefs = await SharedPreferences.getInstance();
    cardnumber = prefs.getString('cardnumber') ?? '';
    password = prefs.getString('password') ?? '';

    if (cardnumber.isEmpty || password.isEmpty) {
      Fluttertoast.showToast(msg: 'Please login first to view your cart.');
      Navigator.pop(context);
      return;
    }

    await _fetchShelfIdAndItems();
  }

  Future<void> _fetchShelfIdAndItems() async {
    final basicAuth = base64Encode(utf8.encode('$cardnumber:$password'));
    final shelvesUrl = Uri.parse('https://library.al-burhaan.org/api/v1/patrons/$cardnumber/virtualshelves');
    final shelfResponse = await http.get(shelvesUrl, headers: {
      'Authorization': 'Basic $basicAuth',
      'Accept': 'application/json',
    });

    if (shelfResponse.statusCode == 200) {
      final shelves = jsonDecode(shelfResponse.body);
      if (shelves.isEmpty) {
        Fluttertoast.showToast(msg: 'No virtual shelves found.');
        setState(() {
          isLoading = false;
        });
        return;
      }

      shelfId = shelves[0]['shelfnumber'].toString();

      final itemsUrl = Uri.parse('https://library.al-burhaan.org/api/v1/virtualshelves/$shelfId/items');
      final itemsResponse = await http.get(itemsUrl, headers: {
        'Authorization': 'Basic $basicAuth',
        'Accept': 'application/json',
      });

      if (itemsResponse.statusCode == 200) {
        setState(() {
          cartItems = jsonDecode(itemsResponse.body);
          isLoading = false;
        });
      } else {
        Fluttertoast.showToast(msg: 'Failed to load cart items.');
        setState(() => isLoading = false);
      }
    } else {
      Fluttertoast.showToast(msg: 'Failed to load virtual shelves.');
      setState(() => isLoading = false);
    }
  }

  Future<void> _removeFromCart(int itemNumber) async {
    final basicAuth = base64Encode(utf8.encode('$cardnumber:$password'));
    final removeUrl = Uri.parse('https://library.al-burhaan.org/api/v1/virtualshelves/$shelfId/items/$itemNumber');
    final response = await http.delete(removeUrl, headers: {
      'Authorization': 'Basic $basicAuth',
      'Accept': 'application/json',
    });

    if (response.statusCode == 200 || response.statusCode == 204) {
      Fluttertoast.showToast(msg: 'Item removed from cart.');
      _fetchShelfIdAndItems(); // Refresh list
    } else {
      Fluttertoast.showToast(msg: 'Failed to remove item.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('cart'.tr()),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : cartItems.isEmpty
          ? Center(child: Text('cart_empty'.tr()))
          : ListView.builder(
        itemCount: cartItems.length,
        itemBuilder: (context, index) {
          final item = cartItems[index];
          final biblioItemNumber = item['itemnumber'];
          final title = item['title'] ?? 'No title';
          final author = item['author'] ?? 'Unknown author';

          return ListTile(
            title: Text(title),
            subtitle: Text(author),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _removeFromCart(biblioItemNumber),
            ),
          );
        },
      ),
    );
  }
}

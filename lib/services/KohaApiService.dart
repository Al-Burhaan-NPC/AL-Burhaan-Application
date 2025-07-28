import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_response.dart';
import '../models/BookDetail.dart';

class KohaApiService {
  final String baseUrl = "https://library.al-burhaan.org/api/v1/";
  final String fallbackUsername = 'AlburhaanApp.App';
  final String fallbackPassword = 'Alburhaan1';

  Future<String> _getAuthHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = prefs.getString('auth');
    if (auth != null) {
      return 'Basic $auth';
    }
    return 'Basic ${base64Encode(utf8.encode('$fallbackUsername:$fallbackPassword'))}';
  }

  Future<List<BookResponse>> fetchBooks(int page, {String? query}) async {
    final basicAuth = await _getAuthHeader();
    String url = "${baseUrl}biblios?_page=$page&_per_page=10";
    if (query != null && query.isNotEmpty) {
      var queryJson = jsonEncode({"title": {"-like": "%$query%"}});
      url += "&q=${Uri.encodeComponent(queryJson)}";
    }
    var response = await http.get(Uri.parse(url), headers: {
      'Authorization': basicAuth,
      'Accept': 'application/json; charset=utf-8'
    });

    print("Requesting URL: $url");
    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      print("API Response: $responseBody");
      List<dynamic> booksJson = jsonDecode(responseBody);
      return booksJson.map((data) => BookResponse.fromJson(data)).toList();
    } else {
      print("Failed to fetch books. Status code: ${response.statusCode}, Response: ${response.body}");
      throw Exception('Failed to load books. Status code: ${response.statusCode}');
    }
  }

  Future<BookDetail> fetchBookDetail(int biblioId) async {
    final basicAuth = await _getAuthHeader();
    String url = "$baseUrl/biblios/$biblioId";

    var response = await http.get(Uri.parse(url), headers: {
      'Authorization': basicAuth,
      'Accept': 'application/json; charset=utf-8'
    });

    if (response.statusCode == 200) {
      var decodedData = utf8.decode(response.bodyBytes);
      return BookDetail.fromJson(json.decode(decodedData));
    } else {
      throw Exception('Failed to load book detail. Status code: ${response.statusCode}');
    }
  }
}
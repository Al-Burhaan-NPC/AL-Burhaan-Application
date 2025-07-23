import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/book_response.dart';
import 'package:alburhaan/models/BookDetail.dart';

class KohaApiService {
  final String baseUrl = "https://library.al-burhaan.org/api/v1/";

  // Fetch a list of books (public access)
  Future<List<BookResponse>> fetchBooks(int page, {String? query}) async {
    String url = "${baseUrl}biblios?_page=$page&_per_page=10";

    if (query != null && query.isNotEmpty) {
      var queryJson = jsonEncode({
        "title": {"-like": "%$query%"}
      });
      url += "&q=${Uri.encodeComponent(queryJson)}";
    }

    var response = await http.get(Uri.parse(url));

    print("Requesting URL: $url");
    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      print("API Response: $responseBody");
      List<dynamic> booksJson = jsonDecode(responseBody);
      return booksJson.map((data) => BookResponse.fromJson(data)).toList();
    } else {
      print(
          "Failed to fetch books. Status code: ${response.statusCode}, Response: ${response.body}");
      throw Exception(
          'Failed to load books. Status code: ${response.statusCode}');
    }
  }

  // Fetch detailed info for a specific book (public access)
  Future<BookDetail> fetchBookDetail(int biblioId) async {
    String url = "$baseUrl/biblios/$biblioId";

    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var decodedData = utf8.decode(response.bodyBytes);
      return BookDetail.fromJson(json.decode(decodedData));
    } else {
      throw Exception(
          'Failed to load book detail. Status code: ${response.statusCode}');
    }
  }
}

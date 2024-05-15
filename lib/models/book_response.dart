import 'package:json_annotation/json_annotation.dart';

part 'book_response.g.dart'; // Ensures the generated file is correctly linked

@JsonSerializable()
class BookResponse {
  final int biblioId;
  final String title;
  final String author;
  final String? isbn;
  final String? publicationYear;
  final String? publisher;
  final String? imageUrl;

  BookResponse({
    required this.biblioId,
    required this.title,
    required this.author,
    this.isbn,
    this.publicationYear,
    this.publisher,
    this.imageUrl,
  });


  // Links the generated code
  factory BookResponse.fromJson(Map<String, dynamic> json) {
    return BookResponse(
      biblioId: json['biblio_id'],
      title: json['title'],
      author: json['author'],
      imageUrl: json['image_url'] = "https://library.al-burhaan.org/cgi-bin/koha/opac-image.pl?thumbnail=1&biblionumber=${json['biblio_id']}&filetype=image",
    );
  }
}
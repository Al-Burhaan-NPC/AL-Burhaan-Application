import 'package:json_annotation/json_annotation.dart';

part 'book_response.g.dart';

@JsonSerializable()
class BookResponse {
  final int biblioId;
  final int? biblionumber;
  final String title;
  final String author;
  final String? isbn;
  final String? publicationYear;
  final String? publisher;
  final String? imageUrl;

  BookResponse({
    required this.biblioId,
    this.biblionumber,
    required this.title,
    required this.author,
    this.isbn,
    this.publicationYear,
    this.publisher,
    this.imageUrl,
  });

  factory BookResponse.fromJson(Map<String, dynamic> json) {
    final biblioIdFromJson = json['biblio_id'] as int;

    // Safely extract itemnumber from items array
    int? extractedItemNumber;
    if (json['items'] != null &&
        json['items'] is List &&
        (json['items'] as List).isNotEmpty &&
        json['items'][0]['itemnumber'] != null) {
      extractedItemNumber = json['items'][0]['itemnumber'] as int;
    }

    final imageUrlFromJson = json['image_url'] as String?;

    return BookResponse(
      biblioId: biblioIdFromJson,
      biblionumber: extractedItemNumber,
      title: json['title'] as String,
      author: json['author'] as String,
      isbn: json['isbn'] as String?,
      publicationYear: json['publication_year'] as String?,
      publisher: json['publisher'] as String?,
      imageUrl: imageUrlFromJson != null && imageUrlFromJson.isNotEmpty
          ? imageUrlFromJson
          : "https://library.al-burhaan.org/cgi-bin/koha/opac-image.pl?thumbnail=1&biblionumber=$biblioIdFromJson&filetype=image",
    );
  }

  Map<String, dynamic> toJson() => _$BookResponseToJson(this);
}

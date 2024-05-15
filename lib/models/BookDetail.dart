import 'dart:convert';

class BookDetail {
  final int biblioId;
  final String title;
  final String author;
  final String? isbn;
  final String? publicationYear;
  final String? publisher;
  final String? imageUrl;
  final String? ebookUrl;
  final String? shelfNumber;
  final String? callNumber;
  final String? language;
  final String? physicalDescription;
  final List<String>? subjects;
  final String? series;
  final String? notes;
  final String? youtubeUrl; // For YouTube links or other video content
  final List<String>? urls; // Additional URLs or resources

  BookDetail({
    required this.biblioId,
    required this.title,
    required this.author,
    this.isbn,
    this.publicationYear,
    this.publisher,
    this.imageUrl,
    this.ebookUrl,
    this.shelfNumber,
    this.callNumber,
    this.language,
    this.physicalDescription,
    this.subjects,
    this.series,
    this.notes,
    this.youtubeUrl,
    this.urls,
  });

  factory BookDetail.fromJson(Map<String, dynamic> json) {
    return BookDetail(
      biblioId: json['biblio_id'],
      title: json['title'],
      author: json['author'],
      isbn: json['isbn'],
      publicationYear: json['publication_year'],
      publisher: json['publisher'],
      imageUrl: json['image_url'] = "https://library.al-burhaan.org/cgi-bin/koha/opac-image.pl?thumbnail=1&biblionumber=${json['biblio_id']}&filetype=image",
      ebookUrl: json['ebook_url'],
      shelfNumber: json['shelf_number'],
      callNumber: json['call_number'],
      language: json['language'],
      physicalDescription: json['physical_description'],
      subjects: (json['subjects'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      series: json['series'],
      notes: json['notes'],
      youtubeUrl: json['youtube_url'],
      urls: (json['urls'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'biblio_id': biblioId,
      'title': title,
      'author': author,
      'isbn': isbn,
      'publication_year': publicationYear,
      'publisher': publisher,
      'image_url': imageUrl,
      'ebook_url': ebookUrl,
      'shelf_number': shelfNumber,
      'call_number': callNumber,
      'language': language,
      'physical_description': physicalDescription,
      'subjects': subjects?.map((e) => e.toString()).toList(),
      'series': series,
      'notes': notes,
      'youtube_url': youtubeUrl,
      'urls': urls?.map((e) => e.toString()).toList(),
    };
  }
}

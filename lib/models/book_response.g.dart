// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookResponse _$BookResponseFromJson(Map<String, dynamic> json) => BookResponse(
      biblioId: (json['biblioId'] as num).toInt(),
      title: json['title'] as String,
      author: json['author'] as String,
      isbn: json['isbn'] as String?,
      publicationYear: json['publicationYear'] as String?,
      publisher: json['publisher'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );

Map<String, dynamic> _$BookResponseToJson(BookResponse instance) =>
    <String, dynamic>{
      'biblioId': instance.biblioId,
      'title': instance.title,
      'author': instance.author,
      'isbn': instance.isbn,
      'publicationYear': instance.publicationYear,
      'publisher': instance.publisher,
      'imageUrl': instance.imageUrl,
    };

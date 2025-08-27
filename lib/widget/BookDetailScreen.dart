import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/BookDetail.dart';
import '../services/KohaApiService.dart';

class BookDetailBottomSheet {
  // Reusable method to create a detail section
  static Widget detailSection(String titleKey, String? content) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              titleKey.tr(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reusable method to launch URLs
  static Future<void> _launchURL(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('could_not_open_link'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Function to show the bottom sheet with book details
  static void showBookDetailsBottomSheet(BuildContext context, int biblioId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.black, // Changed to black
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<BookDetail>(
              future: KohaApiService().fetchBookDetail(biblioId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  final book = snapshot.data!;
                  return SingleChildScrollView(
                    controller: scrollController,
                    physics: const ClampingScrollPhysics(), // Disable glow effect
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        // Book image
                        if (book.imageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                book.imageUrl!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 200,
                                  color: Colors.grey[100],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 60,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Book details
                        detailSection("title", book.title),
                        detailSection("author", book.author),
                        detailSection("isbn", book.isbn),
                        detailSection("publisher", book.publisher),
                        detailSection("publication_year", book.publicationYear),
                        // Optional fields only shown if present
                        if (book.language != null && book.language!.isNotEmpty)
                          detailSection("language", book.language),
                        if (book.shelfNumber != null && book.shelfNumber!.isNotEmpty)
                          detailSection("shelf_number", book.shelfNumber),
                        if (book.callNumber != null && book.callNumber!.isNotEmpty)
                          detailSection("call_number", book.callNumber),
                        if (book.physicalDescription != null && book.physicalDescription!.isNotEmpty)
                          detailSection("physical_description", book.physicalDescription),
                        if (book.series != null && book.series!.isNotEmpty)
                          detailSection("series", book.series),
                        if (book.notes != null && book.notes!.isNotEmpty)
                          detailSection("notes", book.notes),
                        if (book.ebookUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: ElevatedButton.icon(
                              onPressed: () => _launchURL(book.ebookUrl!, context),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: Text(
                                'read_ebook'.tr(),
                                style: const TextStyle(fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                                shadowColor: Colors.black26,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'error'.tr() + ': ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            );
          },
        );
      },
    );
  }
}
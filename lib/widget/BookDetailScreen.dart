import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/BookDetail.dart';
import '../services/KohaApiService.dart';

class BookDetailScreen extends StatelessWidget {
  final int biblioId;

  const BookDetailScreen({Key? key, required this.biblioId}) : super(key: key);

  Widget detailSection(String title, String? content) {
    if (content == null || content.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Expanded(flex: 3, child: Text(content, style: TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open link.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Book Details')),
      body: FutureBuilder<BookDetail>(
        future: KohaApiService().fetchBookDetail(biblioId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (snapshot.data!.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 20.0),
                      child: Image.network(
                        snapshot.data!.imageUrl!,
                        width: MediaQuery.of(context).size.width,
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.image_not_supported, size: 200)),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        detailSection("Title", snapshot.data!.title),
                        detailSection("Author", snapshot.data!.author),
                        detailSection("ISBN", snapshot.data!.isbn),
                        detailSection("Publisher", snapshot.data!.publisher),
                        detailSection("Publication Year", snapshot.data!.publicationYear),
                        detailSection("Shelf Number", snapshot.data!.shelfNumber),
                        detailSection("Call Number", snapshot.data!.callNumber),
                        detailSection("Language", snapshot.data!.language),
                        detailSection("Physical Description", snapshot.data!.physicalDescription),
                        detailSection("Series", snapshot.data!.series),
                        detailSection("Notes", snapshot.data!.notes),
                        if (snapshot.data!.ebookUrl != null)
                          ElevatedButton(
                            onPressed: () => _launchURL(snapshot.data!.ebookUrl!, context),
                            child: Text('Read eBook'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)),
            );
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

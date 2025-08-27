import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({Key? key}) : super(key: key);

  final String _locationUrl =
      'https://www.google.com/maps?q=16+Hibiscus+Pl,+Sydenham,+Durban,+4091';
  final String _email = 'info@al-burhaan.org';
  final String _phone = '0310300600';

  void _launchMaps() async {
    final uri = Uri.parse(_locationUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $_locationUrl';
    }
  }

  void _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _email,
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      throw 'Could not launch email app';
    }
  }

  void _launchPhone() async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: _phone,
    );
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      throw 'Could not launch phone dialer';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('contact_us'.tr()),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow,
                    offset: Offset(4, 4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                    offset: Offset(-4, -4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.contact_mail, color: Colors.blueAccent, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'get_in_touch'.tr(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30, color: Colors.white24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.email_outlined, color: Theme.of(context).iconTheme.color),
                      title: Text(
                        _email,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      onTap: _launchEmail,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.phone_outlined, color: Theme.of(context).iconTheme.color),
                      title: Text(
                        'phone_number'.tr(args: [_phone]),
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      onTap: _launchPhone,
                    ),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
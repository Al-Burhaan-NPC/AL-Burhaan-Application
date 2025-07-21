import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../main.dart';
import 'about_page.dart';
import 'contact_page.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({Key? key}) : super(key: key);

  final AudioPlayer _audioPlayer = AudioPlayer();

  void _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedTheme = value ? ThemeMode.dark : ThemeMode.light;

    themeNotifier.value = selectedTheme;
    await prefs.setString('themeMode', value ? 'dark' : 'light');
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('cardnumber');

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _changeLanguage(BuildContext context, Locale newLocale) async {
    await context.setLocale(newLocale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('localeCode', newLocale.languageCode);

    localeNotifier.value = newLocale;
  }

  Future<void> _scanNfc(BuildContext context) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      await _audioPlayer.play(AssetSource('sounds/Failed.mp3'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC is not available on this device')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Waiting for NFC tag...'),
        duration: Duration(seconds: 2),
      ),
    );

    bool tagFound = false;

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        tagFound = true;
        NfcManager.instance.stopSession();
        await _audioPlayer.play(AssetSource('sounds/Success.mp3'));

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('NFC Tag Detected'),
            content: Text(tag.data.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );

    // Wait 10 seconds to check if a tag was found
    Future.delayed(const Duration(seconds: 10), () async {
      if (!tagFound) {
        NfcManager.instance.stopSession();
        await _audioPlayer.play(AssetSource('sounds/Failed.mp3'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No NFC tag detected'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, currentMode, _) {
          final isDarkMode = currentMode == ThemeMode.dark;

          return ListView(
            children: [
              SwitchListTile(
                title: Text('dark_mode').tr(),
                value: isDarkMode,
                onChanged: _toggleTheme,
                activeColor: Colors.blueAccent,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text('language').tr(),
                trailing: DropdownButton<Locale>(
                  value: context.locale,
                  onChanged: (Locale? newLocale) {
                    if (newLocale != null) {
                      _changeLanguage(context, newLocale);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: Locale('en'), child: Text('English')),
                    DropdownMenuItem(value: Locale('ur'), child: Text('اردو')),
                    DropdownMenuItem(value: Locale('ar'), child: Text('العربية')),
                    DropdownMenuItem(value: Locale('af'), child: Text('Afrikaans')),
                    DropdownMenuItem(value: Locale('zu'), child: Text('Zulu')),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('about').tr(),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.contact_mail),
                title: Text('contact_us').tr(),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()));
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _scanNfc(context),
                icon: const Icon(Icons.nfc),
                label: const Text('Scan NFC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: Text('logout').tr(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

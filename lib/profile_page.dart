import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:http/http.dart' as http;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  String? _cardnumber;
  String? _username;
  String? _profileImagePath;
  bool isLoading = true;
  bool _isEditing = false;
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final GlobalKey barcodeKey = GlobalKey();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Koha API configuration
  final String kohaApiBaseUrl = 'https://library.al-burhaan.org/api/v1';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadProfile() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final auth = prefs.getString('auth');
    final sessionToken = prefs.getString('session_token');
    // Hardcoded patron_id for testing
    const testPatronId = '100000000004'; // Replace with a valid patron_id from your Koha instance
    print('Loading profile - Auth: $auth, Test Patron ID: $testPatronId, Session Token: $sessionToken'); // Debug

    try {
      Map<String, dynamic>? patronData;
      if (auth != null) {
        patronData = await _fetchKohaProfile(auth, testPatronId, sessionToken);
        print('Raw API Response: ${jsonEncode(patronData)}'); // Debug full response
      } else {
        print('Missing auth, using cached data');
      }

      setState(() {
        _cardnumber = patronData?['cardnumber'] ??
            patronData?['cardNumber'] ??
            patronData?['borrowernumber'] ?? // Alternative field
            prefs.getString('cardnumber') ?? 'N/A';
        _username = patronData != null
            ? '${patronData['firstname'] ?? patronData['first_name'] ?? patronData['givenname'] ?? ''} '
            '${patronData['surname'] ?? patronData['last_name'] ?? patronData['family_name'] ?? ''}'.trim()
            : prefs.getString('username') ?? '';
        _profileImagePath = prefs.getString('profileImagePath');
        _nameController.text = _username ?? '';
        _isEditing = _username?.isEmpty ?? true;
        isLoading = false;
        print('Updated - Cardnumber: $_cardnumber, Username: $_username'); // Debug UI data
      });

      if (patronData != null) {
        await prefs.setString('cardnumber', _cardnumber ?? 'N/A');
        await prefs.setString('username', _username ?? '');
      }
    } catch (e) {
      print('Error in _loadProfile: $e'); // Debug
      setState(() {
        _cardnumber = prefs.getString('cardnumber') ?? 'N/A';
        _username = prefs.getString('username') ?? '';
        _profileImagePath = prefs.getString('profileImagePath');
        _nameController.text = _username ?? '';
        _isEditing = _username?.isEmpty ?? true;
        isLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load Koha profile: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _fetchKohaProfile(String auth, String patronId, String? sessionToken) async {
    final headers = {
      'Authorization': 'Basic $auth',
      'Accept': 'application/json',
      'koha-authorization': '{"permissions":[{"borrowers":"list_borrowers"}]}',
      if (sessionToken != null && sessionToken.isNotEmpty) 'x-koha-session': sessionToken,
    };
    final queryParams = {'patron_id': patronId};
    print('Fetching from: $kohaApiBaseUrl/patrons with params: $queryParams, headers: $headers'); // Debug

    try {
      final response = await http.get(
        Uri.parse('$kohaApiBaseUrl/patrons').replace(queryParameters: queryParams),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      print('Response Status: ${response.statusCode}, Body: ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final List<dynamic> patrons = jsonDecode(response.body);
        if (patrons.isNotEmpty) {
          final patron = patrons[0] as Map<String, dynamic>;
          print('Extracted Patron Data Keys: ${patron.keys.join(', ')}'); // Debug available fields
          return patron;
        } else {
          print('No patrons found in response for patron_id: $patronId');
          return {};
        }
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Network Error: $e'); // Debug
      throw Exception('Network error: $e');
    }
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', newName);
    setState(() {
      _username = newName;
      _isEditing = false;
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow,
                  offset: Offset(4, 4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade700
                      : Colors.grey.shade200,
                  offset: Offset(-4, -4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              'save_name'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
      );
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profileImagePath', image.path);
      setState(() {
        _profileImagePath = image.path;
      });
    }
  }

  int calculateEAN13Checksum(String code12) {
    if (code12.length != 12) throw Exception('Input must be 12 digits');
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(code12[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int mod = sum % 10;
    return (mod == 0) ? 0 : 10 - mod;
  }

  String get sanitizedCardNumber {
    return _cardnumber ?? 'N/A';
  }

  Future<void> _shareBarcode() async {
    try {
      final boundary = barcodeKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/barcode.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'My Library Barcode');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow,
                    offset: Offset(4, 4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade700
                        : Colors.grey.shade200,
                    offset: Offset(-4, -4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                'share_barcode_failed'.tr(),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.transparent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickProfileImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _profileImagePath != null
                              ? FileImage(File(_profileImagePath!))
                              : null,
                          child: _profileImagePath == null
                              ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isEditing) ...[
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: 'your_name'.tr(),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTapDown: (_) => _animationController.forward(),
                            onTapUp: (_) => _animationController.reverse(),
                            onTapCancel: () => _animationController.reverse(),
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: ElevatedButton(
                                onPressed: _saveName,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).cardColor,
                                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'save_name'.tr(),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            _username?.isNotEmpty ?? false ? _username! : 'your_name'.tr(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTapDown: (_) => _animationController.forward(),
                            onTapUp: (_) => _animationController.reverse(),
                            onTapCancel: () => _animationController.reverse(),
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).cardColor,
                                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'edit_profile'.tr(),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'card_number'.tr(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _cardnumber ?? 'N/A',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (_cardnumber != null && _cardnumber != 'N/A') ...[
                    const SizedBox(height: 20),
                    Text(
                      'your_barcode'.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: RepaintBoundary(
                        key: barcodeKey,
                        child: BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: sanitizedCardNumber,
                          width: 250,
                          height: 80,
                          drawText: true,
                          backgroundColor: Colors.white,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTapDown: (_) => _animationController.forward(),
                        onTapUp: (_) => _animationController.reverse(),
                        onTapCancel: () => _animationController.reverse(),
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: ElevatedButton.icon(
                            onPressed: _shareBarcode,
                            icon: Icon(Icons.share, color: Theme.of(context).colorScheme.onSurface, size: 18),
                            label: Text(
                              'share_barcode'.tr(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).cardColor,
                              foregroundColor: Theme.of(context).colorScheme.onSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
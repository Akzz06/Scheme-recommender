import 'package:flutter/material.dart';
import 'package:my_app/screens/main_screen.dart'; // Ensure this path is correct

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  void _onLanguageSelected(BuildContext context, String language) {
    // Use push instead of pushReplacement
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MainScreen(selectedLanguage: language),
      ),
    );
  }

  // Helper widget for building language list tiles
  Widget _buildLanguageTile({
    required BuildContext context,
    required String languageName,
    required String languageCode,
    required IconData icon, // Added icon
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.green[700], size: 30), // Language icon
        title: Text(
          languageName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () => _onLanguageSelected(context, languageCode),
        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Language / மொழி / भाषा'),
        backgroundColor: Colors.green[50], // Consistent light green AppBar
        elevation: 1,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch, // Make cards stretch
            children: [
              const Text(
                'Choose your preferred language:', // Added instruction text
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
              const SizedBox(height: 30),

              _buildLanguageTile(
                context: context,
                languageName: 'English',
                languageCode: 'en',
                icon: Icons.language_rounded, // Generic language icon
              ),
              const SizedBox(height: 10),

              _buildLanguageTile(
                context: context,
                languageName: 'தமிழ் (Tamil)', // Include English name for clarity
                languageCode: 'ta',
                icon: Icons.translate_rounded, // Translate icon
              ),
              const SizedBox(height: 10),

              _buildLanguageTile(
                context: context,
                languageName: 'हिन्दी (Hindi)', // Include English name for clarity
                languageCode: 'hi',
                icon: Icons.g_translate_rounded, // Google translate icon
              ),
            ],
          ),
        ),
      ),
    );
  }
}
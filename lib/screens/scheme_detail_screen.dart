import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

class SchemeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> scheme;
  final String selectedLanguage;

  const SchemeDetailScreen({
    super.key,
    required this.scheme,
    required this.selectedLanguage,
  });

  @override
  State<SchemeDetailScreen> createState() => _SchemeDetailScreenState();
}

class _SchemeDetailScreenState extends State<SchemeDetailScreen> {
  late FlutterTts flutterTts;
  String? _currentlySpeakingId;

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  // --- 1. EDITED FUNCTION ---
  void _initializeTts() {
     flutterTts = FlutterTts();
     
     // Set the language based on the widget's selectedLanguage
    String ttsLanguage = "en-US"; // Default to English
    if (widget.selectedLanguage == 'hi') {
      ttsLanguage = "hi-IN";
    } else if (widget.selectedLanguage == 'ta') {
      ttsLanguage = "ta-IN";
    }
    flutterTts.setLanguage(ttsLanguage);

     flutterTts.setCompletionHandler(() {
       if (mounted) setState(() => _currentlySpeakingId = null);
     });
   }

   @override
   void dispose() {
     flutterTts.stop();
     super.dispose();
   }

   // **FIX: This is the complete, working _speak function**
   Future<void> _speak(String label, String value) async {
     final String uniqueId = label; // Use the label as the unique ID
     if (_currentlySpeakingId == uniqueId) {
       await flutterTts.stop();
       if (mounted) setState(() => _currentlySpeakingId = null);
     } else {
       await flutterTts.stop(); // Stop any previous speech
       if (mounted) setState(() => _currentlySpeakingId = uniqueId);
       // Speak the label and then the value if it exists
       await flutterTts.speak(value.isNotEmpty && value != 'N/A' ? '$label. $value' : label);
     }
   }

  // --- 2. EDITED FUNCTION ---
  String _getLocalizedValue(String key) {
    String langCode = widget.selectedLanguage; // 'en', 'hi', 'ta'
    
    // 1. Try to find the language-specific key (e.g., "benefits_ta")
    String langKey = "${key}_${langCode}";
    var value = widget.scheme[langKey];

    // 2. If not found, fall back to English (e.g., "benefits_en")
    if (value == null) {
      String fallbackKey = "${key}_en";
      value = widget.scheme[fallbackKey];
    }

    // 3. If still not found, try the base key (for non-translated fields like "scheme_link")
    if (value == null) {
      value = widget.scheme[key];
    }

    // 4. Now, process the 'value' we found
    if (value == null) {
      return 'N/A';
    }
    if (value is String) {
      return value.isNotEmpty ? value : 'N/A';
    }
    if (value is List) {
      return value.join(', '); // For tags
    }
    return value.toString(); // For numbers, etc.
  }

  Future<void> _launchSchemeUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Could not launch $urlString')),
         );
       }
    }
  }

  Widget _buildDetailRow(BuildContext context, {required String label, required String value}) {
    if (value.isEmpty || value == 'N/A') {
      return const SizedBox.shrink();
    }
    final bool isSpeaking = _currentlySpeakingId == label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                onPressed: () => _speak(label, value), // This now works
                color: Colors.green[700],
                tooltip: 'Read this section',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black87, height: 1.4),
          ),
          const Divider(height: 24, thickness: 0.5),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
final Map<String, String> labels = {
      'details': 'Details',
      'benefits': 'Benefits',
      'eligibility': 'Eligibility Criteria',   // <-- This is your fixed code
      'docs': 'Documents Required',            // <-- This is your fixed code
      'how_to_apply': 'Application Process',   // <-- This is your fixed code
      'faqs': 'FAQs',
      'tags': 'Tags'
    };
    final schemeLink = _getLocalizedValue('scheme_link');

    return Scaffold(
      appBar: AppBar(
        title: Text(_getLocalizedValue('scheme_name')),
         backgroundColor: Colors.green[50],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 3. EDITED KEY ---
            _buildDetailRow(context, label: labels['details']!, value: _getLocalizedValue('description')), // <-- WAS 'details'
            _buildDetailRow(context, label: labels['benefits']!, value: _getLocalizedValue('benefits')),
            _buildDetailRow(context, label: labels['eligibility']!, value: _getLocalizedValue('eligibility_criteria')),
            _buildDetailRow(context, label: labels['docs']!, value: _getLocalizedValue('documents_required')),
            _buildDetailRow(context, label: labels['how_to_apply']!, value: _getLocalizedValue('application_process')),
            _buildDetailRow(context, label: labels['faqs']!, value: _getLocalizedValue('faqs')),
            _buildDetailRow(context, label: labels['tags']!, value: _getLocalizedValue('tags')),

            if (schemeLink.isNotEmpty && schemeLink != 'N/A')
             Padding(
               padding: const EdgeInsets.only(top: 20.0),
               child: ElevatedButton.icon(
                 icon: const Icon(Icons.open_in_browser),
                 label: const Text('Visit Scheme Website'),
                 onPressed: () => _launchSchemeUrl(schemeLink),
                 style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(vertical: 12),
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }
}
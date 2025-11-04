import 'package:flutter/material.dart';
import 'package:my_app/services/scheme_service.dart';
import 'package:my_app/services/bookmark_service.dart';
import 'package:my_app/screens/scheme_detail_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SavedSchemesTab extends StatefulWidget {
  final String selectedLanguage;
  const SavedSchemesTab({Key? key, required this.selectedLanguage}) : super(key: key);

  @override
  _SavedSchemesTabState createState() => _SavedSchemesTabState();
}

class _SavedSchemesTabState extends State<SavedSchemesTab> {
  List<Map<String, dynamic>> _savedSchemes = [];
  bool _isLoading = true;

  late FlutterTts flutterTts;
  String? _currentlySpeakingSchemeId;
  
  final BookmarkService _bookmarkService = BookmarkService();
  // We only need this set to show the icon correctly (as 'filled')
  Set<String> _bookmarkedIds = {};

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadSavedSchemes();
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  void _initializeTts() {
    flutterTts = FlutterTts();
    String ttsLanguage = "en-US";
    if (widget.selectedLanguage == 'hi') {
      ttsLanguage = "hi-IN";
    } else if (widget.selectedLanguage == 'ta') {
      ttsLanguage = "ta-IN";
    }
    flutterTts.setLanguage(ttsLanguage);
    flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _currentlySpeakingSchemeId = null);
    });
  }

  Future<void> _loadSavedSchemes() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      // 1. Load all schemes from the service
      final allSchemes = await SchemeService.fetchAllSchemes();
      
      // 2. Load the bookmarked IDs
      final bookmarkIds = await _bookmarkService.getBookmarkedIds();
      
      if (mounted) {
        setState(() {
          // 3. Filter all schemes to find the saved ones
          _savedSchemes = allSchemes.where((scheme) {
            final schemeId = scheme['id'] as String? ?? '';
            return bookmarkIds.contains(schemeId);
          }).toList();
          
          _bookmarkedIds = bookmarkIds.toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading saved schemes: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBookmark(String schemeId) async {
    // On this screen, toggling ALWAYS means removing.
    await _bookmarkService.toggleBookmark(schemeId);
    
    setState(() {
      // Remove from the local list for instant UI update
      _savedSchemes.removeWhere((scheme) => scheme['id'] == schemeId);
      _bookmarkedIds.remove(schemeId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheme removed from saved.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _speak(String text, String schemeId) async {
    if (_currentlySpeakingSchemeId == schemeId) {
      await flutterTts.stop();
      if (mounted) setState(() => _currentlySpeakingSchemeId = null);
    } else {
      await flutterTts.stop();
      if (mounted) setState(() => _currentlySpeakingSchemeId = schemeId);
      await flutterTts.speak(text.isNotEmpty ? text : "Summary not available");
    }
  }

  String _getLocalizedValue(Map<String, dynamic> data, String key) {
    String langCode = widget.selectedLanguage;
    String langKey = "${key}_${langCode}";
    var value = data[langKey];

    if (value == null) {
      String fallbackKey = "${key}_en";
      value = data[fallbackKey];
    }
    if (value == null) {
      value = data[key];
    }

    if (value == null) return 'N/A';
    if (value is String) return value.isNotEmpty ? value : 'N/A';
    if (value is List) return value.join(', ');
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Schemes'),
      ),
      body: _buildSchemeList(),
    );
  }

  Widget _buildSchemeList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_savedSchemes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "You haven't saved any schemes yet. Tap the bookmark icon on a scheme to save it here.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _savedSchemes.length,
      itemBuilder: (context, index) {
        final scheme = _savedSchemes[index];
        final schemeId = scheme['id'] as String? ?? 'scheme_$index';
        final schemeNameText = _getLocalizedValue(scheme, 'scheme_name');
        final summaryText = _getLocalizedValue(scheme, 'description');
        final bool isSpeaking = _currentlySpeakingSchemeId == schemeId;
        // Icon will always be filled on this screen
        final bool isBookmarked = _bookmarkedIds.contains(schemeId);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          elevation: 2.0,
          child: ListTile(
            title: Text(schemeNameText, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                summaryText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                  color: Colors.green[700],
                  tooltip: 'Remove from saved',
                  onPressed: () => _toggleBookmark(schemeId),
                ),
                IconButton(
                  icon: Icon(isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                  color: Colors.green[700],
                  tooltip: 'Read details',
                  onPressed: () => _speak(summaryText, schemeId),
                ),
              ],
            ),
            onTap: () {
              flutterTts.stop();
              setState(() => _currentlySpeakingSchemeId = null);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SchemeDetailScreen(
                    scheme: scheme,
                    selectedLanguage: widget.selectedLanguage,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
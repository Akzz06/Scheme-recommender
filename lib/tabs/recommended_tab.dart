import 'package:flutter/material.dart';
import 'package:my_app/screens/profile.dart';
import 'package:my_app/services/scheme_service.dart';
import 'package:my_app/screens/scheme_detail_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/services/caching_service.dart';
import 'package:my_app/services/bookmark_service.dart';

class RecommendedTab extends StatefulWidget {
  final String selectedLanguage;
  const RecommendedTab({Key? key, required this.selectedLanguage}) : super(key: key);
  @override
  _RecommendedTabState createState() => _RecommendedTabState();
}

class _RecommendedTabState extends State<RecommendedTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _allSchemes = [];
  List<Map<String, dynamic>> _fullFilteredList = []; // Full list after recommendation & language filter
  List<Map<String, dynamic>> _schemesToShow = []; // Paginated list

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _profileExists = false;
  bool _isOffline = false;

  late FlutterTts flutterTts;
  String? _currentlySpeakingSchemeId;

  final ScrollController _scrollController = ScrollController();
  final int _schemesPerPage = 10;
  int _currentPage = 1;

  final BookmarkService _bookmarkService = BookmarkService();
  Set<String> _bookmarkedIds = {};

  @override
  bool get wantKeepAlive => true;

  final Map<String, List<String>> occupationTags = {
      'Farmer': ['farmer', 'agriculture', 'kisan', 'farming', 'rural', 'fisheries'],
      'Student': ['student', 'scholarship', 'education', 'fellowship', 'internship', 'phd', 'post matric', 'pre matric', 'degree', 'diploma'],
      'Ex Servicemen': ['ex-servicemen', 'pension', 'defence', 'widow of ex-servicemen'],
      'Journalist': ['journalist', 'media'],
      'Women': ['women', 'girl child', 'pregnant', 'mother', 'widow'],
      'Entrepreneur': ['entrepreneur', 'business', 'loan', 'mudra', 'start-up', 'artisan'],
      'Unorganized Worker': ['unorganized worker', 'labour', 'shg', 'bpl', 'below poverty line', 'construction worker', 'building worker'],
      'Person With Disability': ['disability', 'pwd', 'differently abled', 'disabled'],
    };


  @override
  void initState() {
    super.initState();
    _initializeTts();
    _checkProfileAndLoadSchemes();
    _loadBookmarks();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _schemesToShow.length < _fullFilteredList.length) {
        _loadMoreSchemes();
      }
    });
  }

   @override
  void dispose() {
    _scrollController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    final ids = await _bookmarkService.getBookmarkedIds();
    if (mounted) {
      setState(() {
        _bookmarkedIds = ids.toSet();
      });
    }
  }

  Future<void> _checkProfileAndLoadSchemes() async {
    if (mounted) setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _loadBookmarks();

    if (prefs.getString('profile_state') != null && prefs.getString('profile_dob') != null) {
      _profileExists = true;
      try {
        _allSchemes = await SchemeService.fetchAllSchemes();
         if(_allSchemes.isEmpty && mounted) {
           final cached = await CachingService().loadSchemes();
           if(cached == null || cached.isEmpty){
               setState(() => _isOffline = true);
           } else {
             _allSchemes = cached;
             setState(() => _isOffline = true);
           }
         } else if(mounted) {
              setState(() => _isOffline = false);
         }
        await _applyFilters();
      } catch (e) {
        print("Error loading schemes: $e");
         if (mounted) setState(() => _isOffline = true);
         final cached = await CachingService().loadSchemes();
         if (cached != null && cached.isNotEmpty) {
            _allSchemes = cached;
            await _applyFilters();
         }
      }
    } else {
      _profileExists = false;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // --- ** UPDATED FILTER FUNCTION ** ---
  Future<void> _applyFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final state = prefs.getString('profile_state');
    final gender = prefs.getString('profile_gender');
    final caste = prefs.getString('profile_caste');
    final occupation = prefs.getString('profile_occupation');
    final dobString = prefs.getString('profile_dob');

    if (state == null || gender == null || caste == null || occupation == null || dobString == null) {
        if (mounted) setState(() => _fullFilteredList = []);
        return;
    }

    final age = (DateTime.now().difference(DateTime.parse(dobString)).inDays / 365).floor();
    final relevantTags = occupationTags[occupation] ?? [occupation.toLowerCase()];

    // Step 1: Filter by recommendation criteria
    List<Map<String, dynamic>> recommendedFilteredList = _allSchemes.where((scheme) {
      // Always use English text for filtering logic
      String eligibilityTextEn = _getLocalizedValue(scheme, 'eligibility_criteria', forceLanguage: 'en').toLowerCase();
      List<String> tagsEn = List<String>.from(scheme['tags_en'] ?? []).map((t) => t.toLowerCase()).toList();

      // Age Check
      bool isAgeMaybeEligible = true;
      int? minAge = scheme['min_age'] is int ? scheme['min_age'] : null;
      int? maxAge = scheme['max_age'] is int ? scheme['max_age'] : null;
      if (minAge != null && age < minAge) { isAgeMaybeEligible = false; }
      else if (maxAge != null && age > maxAge) { isAgeMaybeEligible = false; }
      else if (minAge == null && maxAge == null) {
          final ageMentions = RegExp(r'(\d+)\s*years').allMatches(eligibilityTextEn);
          List<int> agesFound = ageMentions.map((m) => int.tryParse(m.group(1) ?? '') ?? -1).where((a) => a != -1).toList();
          if (agesFound.isNotEmpty) {
              int minMentionedAge = agesFound.reduce((a, b) => a < b ? a : b);
              int maxMentionedAge = agesFound.reduce((a, b) => a > b ? a : b);
              if (agesFound.length == 1) {
                  if (eligibilityTextEn.contains('above') || eligibilityTextEn.contains('minimum')) { isAgeMaybeEligible = age >= minMentionedAge; }
                  else if (eligibilityTextEn.contains('below') || eligibilityTextEn.contains('maximum') || eligibilityTextEn.contains('up to')) { isAgeMaybeEligible = age <= minMentionedAge; }
              } else if (agesFound.length > 1) { isAgeMaybeEligible = age >= minMentionedAge && age <= maxMentionedAge; }
          }
      }

      // Gender Check
      bool isGenderMaybeEligible = true;
      String? targetGender = scheme['target_gender'] as String?;
      if (targetGender != null && targetGender != 'All' && targetGender != gender) { isGenderMaybeEligible = false; }
      else if (targetGender == null) {
          if ((eligibilityTextEn.contains(' female') || eligibilityTextEn.contains(' women') || eligibilityTextEn.contains(' girl')) && gender != 'Female') { isGenderMaybeEligible = false; }
          else if (eligibilityTextEn.contains(' male') && gender != 'Male') { isGenderMaybeEligible = false; }
      }

      // Caste Check
      bool isCasteMaybeEligible = true;
      List<String> targetCaste = List<String>.from(scheme['target_caste'] ?? []);
      if (targetCaste.isNotEmpty && !targetCaste.contains('All') && !targetCaste.contains(caste)) { isCasteMaybeEligible = false; }
      else if (targetCaste.isEmpty) {
          if ((eligibilityTextEn.contains('scheduled caste') || eligibilityTextEn.contains(' sc')) && caste != 'SC') { isCasteMaybeEligible = false; }
          else if ((eligibilityTextEn.contains('scheduled tribe') || eligibilityTextEn.contains(' st')) && caste != 'ST') { isCasteMaybeEligible = false; }
          else if ((eligibilityTextEn.contains('backward class') || eligibilityTextEn.contains(' obc')) && caste != 'OBC') { isCasteMaybeEligible = false; }
      }

      // State Check
      final targetStates = List<String>.from(scheme['target_state'] ?? []);
      final isStateEligible = targetStates.isEmpty || targetStates.contains('All') || targetStates.any((ts) => ts.toLowerCase().contains('ministry')) || targetStates.contains(state);

      // Occupation Check
      final isOccupationEligible = relevantTags.any((userTag) => tagsEn.contains(userTag));

      return isAgeMaybeEligible && isGenderMaybeEligible && isCasteMaybeEligible && isStateEligible && isOccupationEligible;
    }).toList();

    // ** Step 2: Filter out schemes MISSING the required language text **
    List<Map<String, dynamic>> displayableSchemes;
    final selectedLang = widget.selectedLanguage; // 'en', 'ta', or 'hi'

    if (selectedLang == 'en') {
      // For English, only filter out if English name/description is truly N/A (missing/empty)
      displayableSchemes = recommendedFilteredList.where((scheme) {
         final nameEn = _getLocalizedValue(scheme, 'scheme_name', forceLanguage: 'en');
         final descEn = _getLocalizedValue(scheme, 'description', forceLanguage: 'en');
         return nameEn != 'N/A' && descEn != 'N/A';
      }).toList();
    } else {
      // For Tamil/Hindi, filter out if the SPECIFIC language name OR description is missing/empty
      displayableSchemes = recommendedFilteredList.where((scheme) {
          final nameKey = 'scheme_name_$selectedLang';
          final descKey = 'description_$selectedLang';
          // Check if the keys exist and their values are non-empty strings
          bool hasLangName = scheme.containsKey(nameKey) &&
                             scheme[nameKey] is String &&
                             (scheme[nameKey] as String).isNotEmpty;
          bool hasLangDesc = scheme.containsKey(descKey) &&
                             scheme[descKey] is String &&
                             (scheme[descKey] as String).isNotEmpty;
          // Only keep if BOTH name and description exist for the selected language
          return hasLangName && hasLangDesc;
      }).toList();
    }

    // Update the final lists using the displayable schemes
    _fullFilteredList = displayableSchemes; // Use the final filtered list
    _currentPage = 1;
    _schemesToShow = _fullFilteredList.take(_schemesPerPage).toList();

    if (_scrollController.hasClients) { // Scroll to top after filtering
        _scrollController.jumpTo(0);
    }

    if (mounted) setState(() {}); // Update the UI
  }
  // --- ** END OF UPDATE ** ---

  void _loadMoreSchemes() {
     if (_isLoading || _isLoadingMore) return;

    if (_schemesToShow.length < _fullFilteredList.length) {
      if (mounted) setState(() => _isLoadingMore = true);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        int nextPageIndex = _currentPage * _schemesPerPage;
        int endPageIndex = nextPageIndex + _schemesPerPage;

        if (endPageIndex > _fullFilteredList.length) {
          endPageIndex = _fullFilteredList.length;
        }

        if (nextPageIndex < _fullFilteredList.length) {
          setState(() {
            _schemesToShow.addAll(_fullFilteredList.getRange(nextPageIndex, endPageIndex));
            _currentPage++;
          });
        }
        if (mounted) setState(() => _isLoadingMore = false);
      });
    }
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

  Future<void> _toggleBookmark(String schemeId) async {
    bool isNowBookmarked = await _bookmarkService.toggleBookmark(schemeId);
    setState(() {
      if (isNowBookmarked) {
        _bookmarkedIds.add(schemeId);
      } else {
        _bookmarkedIds.remove(schemeId);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNowBookmarked ? 'Scheme saved!' : 'Scheme removed.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

 String _getLocalizedValue(Map<String, dynamic> data, String key, {String? forceLanguage}) {
    String langCode = forceLanguage ?? widget.selectedLanguage;
    String langKey = "${key}_${langCode}";
    var value = data[langKey];

    // Fallback logic adjusted to prioritize English ONLY if the forced/selected lang is missing/empty
    if (value == null || (value is String && value.isEmpty)) {
      if (langCode != 'en') { // Only fallback to English if not already English
         String fallbackKey = "${key}_en";
         value = data[fallbackKey];
      }
    }
    // If still null/empty after potential fallback, try the base key
    if (value == null || (value is String && value.isEmpty)) {
      value = data[key];
    }
    // Final check: if everything is null/empty, return 'N/A'
    if (value == null || (value is String && value.isEmpty)) return 'N/A';


    if (value is String) return value; // Already checked for empty
    if (value is List) {
         if (key == 'tags') {
             return value.join(', ');
         } else {
             // For filtering lists like target_state, return something filter can use
             // For display, might need more specific handling depending on the key
             return value.toString(); // Or handle specific lists differently
         }
     }
    return value.toString();
  }


  void _navigateToProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
    if (result == true && mounted) {
      await _checkProfileAndLoadSchemes();
    }
  }

  @override
  Widget build(BuildContext context) {
     super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommended For You'), // Needs translation
        actions: [
          if (_profileExists)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: 'Edit Profile', // Needs translation
              onPressed: _navigateToProfile,
            )
        ],
      ),
       body: Column(
         children: [
            if (_isOffline && !_isLoading)
                Container(
                   width: double.infinity,
                   color: Colors.orange.shade700,
                   padding: const EdgeInsets.all(8.0),
                   child: const Text( // Needs translation
                     "Offline Mode: Recommendations based on cached data.",
                     textAlign: TextAlign.center,
                     style: TextStyle(color: Colors.white),
                   ),
                ),
            Expanded(child: _buildBody()),
          ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_profileExists) {
      return Center(
         child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_search_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text( // Needs translation
                'Create a profile to get personalized scheme recommendations.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Create Profile', style: TextStyle(fontSize: 16)), // Needs translation
                 style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                onPressed: _navigateToProfile,
              ),
            ],
          ),
        ),
      );
    }

    if (_schemesToShow.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text( // Needs translation
            "No schemes found matching your current profile. Try adjusting your details by tapping the edit icon ✏️.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _schemesToShow.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
          if (index == _schemesToShow.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final scheme = _schemesToShow[index];
          final schemeId = scheme['id'] as String? ?? 'scheme_$index';
          final schemeNameText = _getLocalizedValue(scheme, 'scheme_name'); // Uses selected lang
          final summaryText = _getLocalizedValue(scheme, 'description'); // Uses selected lang
          final bool isSpeaking = _currentlySpeakingSchemeId == schemeId;
          final bool isBookmarked = _bookmarkedIds.contains(schemeId);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            elevation: 2.0,
            child: ListTile(
              title: Text(schemeNameText),
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
                    tooltip: 'Save scheme', // Needs translation
                    onPressed: () => _toggleBookmark(schemeId),
                  ),
                  IconButton(
                    icon: Icon(isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
                    color: Colors.green[700],
                    tooltip: 'Read details', // Needs translation
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
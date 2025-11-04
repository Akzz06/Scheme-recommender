import 'package:flutter/material.dart';
import 'package:my_app/services/scheme_service.dart';
import 'package:my_app/screens/scheme_detail_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:my_app/services/caching_service.dart';
import 'package:my_app/services/bookmark_service.dart';

class AllSchemesTab extends StatefulWidget {
  final String selectedLanguage;
  const AllSchemesTab({Key? key, required this.selectedLanguage}) : super(key: key);
  @override
  _AllSchemesTabState createState() => _AllSchemesTabState();
}

class _AllSchemesTabState extends State<AllSchemesTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _allSchemes = []; // Holds all schemes
  List<Map<String, dynamic>> _fullFilteredList = []; // Holds the full list after category & search & N/A filter
  List<Map<String, dynamic>> _schemesToShow = []; // Holds only the items to display (paginated)

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isOffline = false;

  late FlutterTts flutterTts;
  String? _currentlySpeakingSchemeId;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final ScrollController _scrollController = ScrollController();
  final int _schemesPerPage = 10;
  int _currentPage = 1;

  final BookmarkService _bookmarkService = BookmarkService();
  Set<String> _bookmarkedIds = {};

  String _selectedCategory = 'All';
  Map<String, int> _categoryCounts = {};
  Map<String, List<String>> _categories = {};
  final Map<String, IconData> _categoryIcons = {
     'All': Icons.list_alt_rounded,
     'Agriculture': Icons.agriculture_rounded,
     'Student': Icons.school_rounded,
     'Loan': Icons.account_balance_wallet_rounded,
     'Women': Icons.woman_rounded,
     'Business': Icons.business_center_rounded,
     'Health': Icons.local_hospital_rounded,
     'Pension': Icons.elderly_rounded,
     'Disability': Icons.accessible_rounded,
     'Housing': Icons.house_rounded,
     'Transport': Icons.directions_bus_rounded,
     'Sports': Icons.sports_soccer_rounded,
     'Travel & Tourism': Icons.flight_takeoff_rounded,
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeCategories();
    _initializeTts();
    _loadSchemes();
    _loadBookmarks();

    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
         setState(() {
            _searchQuery = _searchController.text;
            _applySearchFilter();
         });
      }
    });

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
    flutterTts.stop();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeCategories() {
     _categories = {
       'All': [],
       'Agriculture': ['farmer', 'agriculture', 'kisan', 'farming', 'rural', 'fisheries', 'crop', 'irrigation', 'soil', 'livestock'],
       'Student': ['student', 'scholarship', 'education', 'fellowship', 'internship', 'phd', 'post matric', 'pre matric', 'degree', 'diploma', 'school', 'college', 'university'],
       'Loan': ['loan', 'credit', 'finance', 'financial assistance', 'mudra', 'subsidy', 'interest subvention'],
       'Women': ['women', 'girl child', 'pregnant', 'mother', 'widow', 'female'],
       'Business': ['entrepreneur', 'business', 'start-up', 'artisan', 'msme', 'trade', 'skill development', 'employment'],
       'Health': ['health', 'medical', 'insurance', 'hospital', 'treatment', 'ayushman bharat'],
       'Pension': ['pension', 'old age', 'social security', 'senior citizen'],
       'Disability': ['disability', 'pwd', 'differently abled', 'disabled'],
       'Housing': ['housing', 'house', 'awas yojana', 'shelter'],
       'Transport': ['transport', 'vehicle', 'bus', 'driving', 'road'],
       'Sports': ['sports', 'athlete', 'khelo india', 'stadium'],
       'Travel & Tourism': ['travel', 'tourism', 'pilgrimage', 'tourist'],
     };
     _categoryCounts = { for (var cat in _categories.keys) cat : 0 };
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

  Future<void> _loadBookmarks() async {
    final ids = await _bookmarkService.getBookmarkedIds();
    if (mounted) {
      setState(() {
        _bookmarkedIds = ids.toSet();
      });
    }
  }

  Future<void> _loadSchemes() async {
    if (mounted) setState(() => _isLoading = true);
    _allSchemes = [];
    _schemesToShow = [];
    _currentPage = 1;
    _loadBookmarks();

    try {
      _allSchemes = await SchemeService.fetchAllSchemes();
      if (_allSchemes.isEmpty && mounted) {
        final cached = await CachingService().loadSchemes();
        if (cached == null || cached.isEmpty) {
          setState(() => _isOffline = true);
        } else {
          _allSchemes = cached;
          setState(() => _isOffline = true);
        }
      } else if (mounted) {
        setState(() => _isOffline = false);
      }
      _calculateCategoryCounts();
    } catch (e) {
      print("Error loading schemes: $e");
      if (mounted) {
         final cached = await CachingService().loadSchemes();
          if(cached != null && cached.isNotEmpty){
               _allSchemes = cached;
               setState(() => _isOffline = true);
               _calculateCategoryCounts();
          } else {
               setState(() => _isOffline = true);
          }
      }
    }

    _applySearchFilter();
    if (mounted) setState(() => _isLoading = false);
  }

  void _calculateCategoryCounts() {
     final counts = { for (var cat in _categories.keys) cat : 0 };
     counts['All'] = _allSchemes.length;

     for (final scheme in _allSchemes) {
       final tags = List<String>.from(scheme['tags_${widget.selectedLanguage}'] ?? scheme['tags_en'] ?? []).map((t) => t.toLowerCase()).toList();
       final name = _getLocalizedValue(scheme, 'scheme_name').toLowerCase();
       final description = _getLocalizedValue(scheme, 'description').toLowerCase();
       // Check if scheme has valid data before counting for categories
       if (name == 'n/a' || description == 'n/a') {
            counts['All'] = (counts['All'] ?? 1) - 1; // Decrement 'All' count
            continue; // Skip this scheme for category counts
       }
       final combinedText = '$name $description ${tags.join(' ')}';

       for (final category in _categories.keys) {
         if (category == 'All') continue;

         final keywords = _categories[category]!;
         if (keywords.any((keyword) => combinedText.contains(keyword.toLowerCase()))) {
           counts[category] = (counts[category] ?? 0) + 1;
         }
       }
     }

     if (mounted) {
       setState(() {
         _categoryCounts = counts;
       });
     }
  }

  // --- ** UPDATED FILTER FUNCTION ** ---
  void _applySearchFilter() {
    List<Map<String, dynamic>> categoryFilteredList;

    // Step 1: Filter by Category
    if (_selectedCategory == 'All') {
      categoryFilteredList = List.from(_allSchemes);
    } else {
      final keywords = _categories[_selectedCategory] ?? [];
      if (keywords.isEmpty) {
         categoryFilteredList = List.from(_allSchemes);
      } else {
        categoryFilteredList = _allSchemes.where((scheme) {
          final tags = List<String>.from(scheme['tags_${widget.selectedLanguage}'] ?? scheme['tags_en'] ?? []).map((t) => t.toLowerCase()).toList();
          final name = _getLocalizedValue(scheme, 'scheme_name').toLowerCase();
          final description = _getLocalizedValue(scheme, 'description').toLowerCase();
          final combinedText = '$name $description ${tags.join(' ')}';

          return keywords.any((keyword) => combinedText.contains(keyword.toLowerCase()));
        }).toList();
      }
    }

    // Step 2: Filter by Search Query
    List<Map<String, dynamic>> searchFilteredList;
    if (_searchQuery.isEmpty) {
      searchFilteredList = categoryFilteredList;
    } else {
      final query = _searchQuery.toLowerCase();
      searchFilteredList = categoryFilteredList.where((scheme) {
        final name = _getLocalizedValue(scheme, 'scheme_name').toLowerCase();
        final details = _getLocalizedValue(scheme, 'description').toLowerCase();
        final tagsList = List<String>.from(scheme['tags_${widget.selectedLanguage}'] ?? scheme['tags_en'] ?? []);
        final tags = tagsList.join(' ').toLowerCase();

        return name.contains(query) || details.contains(query) || tags.contains(query);
      }).toList();
    }

    // ** Step 3: Filter out schemes with N/A name or description **
    List<Map<String, dynamic>> displayableSchemes = searchFilteredList.where((scheme) {
      final name = _getLocalizedValue(scheme, 'scheme_name');
      final description = _getLocalizedValue(scheme, 'description');
      // Ensure BOTH name and description are valid
      return name != 'N/A' && description != 'N/A';
    }).toList();

    // Update the final lists using the displayable schemes
    _fullFilteredList = displayableSchemes; // Use the final filtered list
    _currentPage = 1;
    _schemesToShow = _fullFilteredList.take(_schemesPerPage).toList();

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    if(mounted) setState(() {});
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

  String _getLocalizedValue(Map<String, dynamic> data, String key) {
    String langCode = widget.selectedLanguage;
    String langKey = "${key}_${langCode}";
    var value = data[langKey];

    if (value == null || (value is String && value.isEmpty)) { // Check if empty string too
      String fallbackKey = "${key}_en";
      value = data[fallbackKey];
    }
    if (value == null || (value is String && value.isEmpty)) { // Check fallback if empty
      value = data[key];
    }
     // Final check if base key is empty
    if (value == null || (value is String && value.isEmpty)) return 'N/A';

    if (value is String) return value; // Already checked for empty
    if (value is List) return value.join(', ');
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
     super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Schemes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search within "${_selectedCategory}"...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor.withAlpha(230),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                 suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                           _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildCategoryChips(),
          if (_isOffline && !_isLoading)
            Container(
              width: double.infinity,
              color: Colors.orange.shade700,
              padding: const EdgeInsets.all(8.0),
              child: const Text(
                "Offline Mode: Showing cached data.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          Expanded(child: _buildSchemeList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadSchemes,
        tooltip: 'Refresh Schemes',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildCategoryChips() {
     if (_isLoading) return const SizedBox(height: 50);

     List<String> categoryNames = _categories.keys.toList();
     categoryNames.remove('All');
     categoryNames.sort();
     categoryNames.insert(0, 'All');

     return Container(
       height: 50,
       padding: const EdgeInsets.symmetric(vertical: 8.0),
       child: ListView.separated(
         scrollDirection: Axis.horizontal,
         padding: const EdgeInsets.symmetric(horizontal: 16.0),
         itemCount: categoryNames.length,
         separatorBuilder: (context, index) => const SizedBox(width: 8),
         itemBuilder: (context, index) {
           final category = categoryNames[index];
           final count = _categoryCounts[category] ?? 0;
           final isSelected = _selectedCategory == category;
           final iconData = _categoryIcons[category] ?? Icons.category_rounded;

           if (count == 0 && category != 'All') {
              return const SizedBox.shrink();
           }

           return FilterChip(
             avatar: Icon(
                iconData,
                size: 18,
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : Colors.grey[700],
             ),
             label: Text('$category ($count)'),
             selected: isSelected,
             onSelected: (selected) {
               if (selected) {
                 setState(() {
                   _selectedCategory = category;
                   _applySearchFilter();
                 });
               }
             },
             checkmarkColor: Theme.of(context).colorScheme.onPrimary,
             selectedColor: Theme.of(context).colorScheme.primary,
             labelStyle: TextStyle(
               fontWeight: FontWeight.w500,
               color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).textTheme.bodyLarge?.color,
             ),
             backgroundColor: Colors.grey[200],
             shape: StadiumBorder(side: BorderSide(color: Colors.grey[400]!)),
             showCheckmark: false,
           );
         },
       ),
     );
  }

  Widget _buildSchemeList() {
     if (_isLoading && _schemesToShow.isEmpty) {
      return const Center(child: CircularProgressIndicator());
     }
    if (_schemesToShow.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'No schemes found for "$_searchQuery" in $_selectedCategory.'
                  : 'No schemes found in the "$_selectedCategory" category.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
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
          final schemeNameText = _getLocalizedValue(scheme, 'scheme_name');
          final summaryText = _getLocalizedValue(scheme, 'description');
          final bool isSpeaking = _currentlySpeakingSchemeId == schemeId;
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
                    tooltip: 'Save scheme',
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
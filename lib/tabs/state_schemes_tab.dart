import 'package:flutter/material.dart';
import 'package:my_app/services/scheme_service.dart';
import 'package:my_app/screens/scheme_detail_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:my_app/services/caching_service.dart';
import 'package:my_app/services/bookmark_service.dart';

class StateSchemesTab extends StatefulWidget {
  final String selectedLanguage;
  const StateSchemesTab({Key? key, required this.selectedLanguage}) : super(key: key);
  @override
  _StateSchemesTabState createState() => _StateSchemesTabState();
}

class _StateSchemesTabState extends State<StateSchemesTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _allSchemes = [];
  List<Map<String, dynamic>> _fullFilteredList = []; // Full list after state & N/A filter
  List<Map<String, dynamic>> _schemesToShow = []; // Paginated list to display

  List<String> _availableStates = ['All', 'Central Schemes'];
  String _selectedState = 'All';
  bool _isLoading = true;
  bool _isLoadingMore = false;
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

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadSchemesAndStates();
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

  Future<void> _loadSchemesAndStates() async {
    if (mounted) setState(() => _isLoading = true);
    _loadBookmarks();

    try {
      _allSchemes = await SchemeService.fetchAllSchemes();

      if (_allSchemes.isNotEmpty && mounted) {
        final statesSet = <String>{};
        for (final scheme in _allSchemes) {
          final stateList = scheme['target_state'];
          if (stateList is List) {
            for (final state in stateList) {
              if (state is String &&
                  state.isNotEmpty &&
                  !state.toLowerCase().contains('ministry') &&
                  state.toLowerCase() != 'all') {
                statesSet.add(state);
              }
            }
          }
        }
        final states = statesSet.toList();
        states.sort();

        setState(() {
          _availableStates = ['All', 'Central Schemes', ...states];
          _isOffline = false;
        });
      } else if (mounted) {
        final cached = await CachingService().loadSchemes();
        if (cached != null && cached.isNotEmpty) {
          _allSchemes = cached;
           final statesSet = <String>{};
           for (final scheme in _allSchemes) {
             final stateList = scheme['target_state'];
             if (stateList is List) {
               for (final state in stateList) {
                 if (state is String &&
                     state.isNotEmpty &&
                     !state.toLowerCase().contains('ministry') &&
                     state.toLowerCase() != 'all') {
                   statesSet.add(state);
                 }
               }
             }
           }
           final states = statesSet.toList();
          states.sort();
          setState(() {
            _availableStates = ['All', 'Central Schemes', ...states];
            _isOffline = true;
          });
        } else {
           setState(() => _isOffline = true);
        }
      }
      _applyStateFilter(); // Apply filter after loading
    } catch (e) {
      print("Error loading schemes/states: $e");
      if (mounted) {
         final cached = await CachingService().loadSchemes();
         if(cached != null && cached.isNotEmpty){
             _allSchemes = cached;
             final statesSet = <String>{};
             for (final scheme in _allSchemes) {
               final stateList = scheme['target_state'];
               if (stateList is List) {
                 for (final state in stateList) {
                   if (state is String &&
                       state.isNotEmpty &&
                       !state.toLowerCase().contains('ministry') &&
                       state.toLowerCase() != 'all') {
                     statesSet.add(state);
                   }
                 }
               }
             }
             final states = statesSet.toList();
             states.sort();
             setState(() {
                _availableStates = ['All', 'Central Schemes', ...states];
                _isOffline = true;
             });
             _applyStateFilter(); // Apply filter after loading cache
         } else {
              setState(() => _isOffline = true);
         }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // --- ** UPDATED FILTER FUNCTION ** ---
  void _applyStateFilter() {
    List<Map<String, dynamic>> stateFilteredList; // Temporary list after state filter

    // Step 1: Filter by State
    if (_selectedState == 'All') {
      stateFilteredList = List.from(_allSchemes);

    } else if (_selectedState == 'Central Schemes') {
      stateFilteredList = _allSchemes.where((scheme) {
        final stateList = scheme['target_state'];
        if (stateList is List) {
          return stateList.isEmpty ||
                 stateList.any((state) => state is String && state.toLowerCase() == 'all') ||
                 stateList.any((state) => state is String && state.toLowerCase().contains('ministry'));
        }
        return false;
      }).toList();

    } else { // Filter for specific state
      stateFilteredList = _allSchemes.where((scheme) {
        final stateList = scheme['target_state'];
        if (stateList is List) {
          // **Strict Check:** Only include if the list explicitly contains the selected state
          return stateList.contains(_selectedState); // <-- Only this check remains
        }
        return false;
      }).toList();
    }
    // --- ** END OF STRICT STATE CHECK ** ---


    // Step 2: Filter out schemes with N/A name or description
    List<Map<String, dynamic>> displayableSchemes = stateFilteredList.where((scheme) {
      final name = _getLocalizedValue(scheme, 'scheme_name');
      final description = _getLocalizedValue(scheme, 'description');
      return name != 'N/A' && description != 'N/A';
    }).toList();

    // Update the final lists using the displayable schemes
    _fullFilteredList = displayableSchemes;
    _currentPage = 1;
    _schemesToShow = _fullFilteredList.take(_schemesPerPage).toList();

    if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
    }

    if (mounted) setState(() {});
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

    if (value == null || (value is String && value.isEmpty)) {
      String fallbackKey = "${key}_en";
      value = data[fallbackKey];
    }
    if (value == null || (value is String && value.isEmpty)) {
      value = data[key];
    }
    if (value == null || (value is String && value.isEmpty)) return 'N/A';

    if (value is String) return value;
    if (value is List) return value.join(', ');
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
     super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schemes by State'), // Needs translation
      ),
      body: Column(
        children: [
           if (_isOffline && !_isLoading)
            Container(
               width: double.infinity,
               color: Colors.orange.shade700,
               padding: const EdgeInsets.all(8.0),
               child: const Text( // Needs translation
                 "Offline Mode: Showing cached data.",
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.white),
               ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: DropdownButtonFormField<String>(
              value: _selectedState,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filter by State / Scheme Type', // Needs translation
                border: OutlineInputBorder(),
                 contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              ),
              items: _availableStates.map((String state) {
                return DropdownMenuItem<String>(
                  value: state,
                  child: Text(state, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: _isLoading ? null : (String? newValue) {
                if (newValue != null) {
                   setState(() {
                      _selectedState = newValue;
                      _applyStateFilter(); // Re-apply filter when dropdown changes
                    });
                }
              },
            ),
          ),
          Expanded(child: _buildSchemeList()),
        ],
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
            child: Text( // Needs translation
               _isOffline ? "Could not fetch schemes. Check connection." : "No schemes found for the selected filter.",
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
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkService {
  static const _key = 'bookmarkedSchemeIds';

  /// Fetches the list of saved scheme IDs.
  Future<List<String>> getBookmarkedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  /// Adds or removes a schemeId from bookmarks.
  /// Returns `true` if the scheme is now bookmarked, `false` if not.
  Future<bool> toggleBookmark(String schemeId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> ids = await getBookmarkedIds();
    bool isBookmarked = false;
    
    if (ids.contains(schemeId)) {
      ids.remove(schemeId);
      isBookmarked = false;
    } else {
      ids.add(schemeId);
      isBookmarked = true;
    }
    
    await prefs.setStringList(_key, ids);
    return isBookmarked;
  }
}
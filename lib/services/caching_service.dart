import 'package:hive/hive.dart';

class CachingService {
  static const _schemesBoxName = 'schemesBox';

  // Save the list of all schemes to the local database
  Future<void> saveSchemes(List<Map<String, dynamic>> schemes) async {
    try {
      final box = await Hive.openBox(_schemesBoxName);
      // Store the entire list under a single key
      await box.put('allSchemes', schemes);
      print("✅ Schemes saved to cache.");
      await box.close(); // Close the box after writing
    } catch (e) {
      print("Error saving schemes to cache: $e");
    }
  }

  // Load the list of all schemes from the local database
  Future<List<Map<String, dynamic>>?> loadSchemes() async {
    Box? box;
    try {
      box = await Hive.openBox(_schemesBoxName);
      final schemesData = box.get('allSchemes');
      await box.close(); // Close the box after reading

      if (schemesData != null && schemesData is List) {
        print("✅ Schemes loaded from cache.");
        // Ensure correct casting from List<dynamic> which might contain List<dynamic>
         return List<Map<String, dynamic>>.from(schemesData.map((e) {
             if (e is Map) {
                 return Map<String, dynamic>.from(e);
             }
             return <String, dynamic>{}; // Return empty map if item is not a map
         }).where((map) => map.isNotEmpty)); // Filter out empty maps
      }
    } catch (e) {
      print("Error loading schemes from cache: $e");
       if (box != null && box.isOpen) {
        await box.close();
      }
    }
    return null; // Return null if no data is found or an error occurs
  }
}
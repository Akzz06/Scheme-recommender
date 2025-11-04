import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle; // Import for loading local assets
// No CachingService or http import needed

class SchemeService {
  
  // This will hold all schemes in memory
  static List<Map<String, dynamic>>? _allSchemes; 

  // Fetches ALL schemes at once from the local JSON file
  static Future<List<Map<String, dynamic>>> fetchAllSchemes() async {
    // 1. Check if schemes are already loaded in memory
    if (_allSchemes != null && _allSchemes!.isNotEmpty) {
      return _allSchemes!;
    }

    // 2. If not, load them from the local asset file
    print("Loading schemes from local asset: assets/data/cleaned_schemes.json");
    try {
      // Load the JSON file as a string
      final String jsonString = await rootBundle.loadString('assets/data/cleaned_schemes.json');
      
      // Decode the outer JSON object {"schemes": {...}}
      final Map<String, dynamic>? jsonData = json.decode(jsonString) as Map<String, dynamic>?;
      if (jsonData == null || !jsonData.containsKey('schemes')) {
         print("Error: JSON file is not in the expected format {'schemes': ...}");
         return [];
      }
      
      // Get the inner map of schemes
      final Map<String, dynamic> schemesMap = jsonData['schemes'];
      
      // Convert the map's values into a list
      var schemes = schemesMap.entries.map((entry) {
          var schemeData = Map<String, dynamic>.from(entry.value);
          schemeData['id'] = entry.key; // The ID is 'scheme_001', 'scheme_002', etc.
          return schemeData;
      }).toList();

      _allSchemes = schemes; // Store in memory
      return schemes;

    } catch (e) {
      print("❌ Error loading schemes from asset: $e");
      return []; // Return empty list on error
    }
  }
}
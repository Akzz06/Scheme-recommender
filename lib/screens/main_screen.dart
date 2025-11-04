import 'package:flutter/material.dart';
import 'package:my_app/tabs/all_schemes_tab.dart';
import 'package:my_app/tabs/state_schemes_tab.dart';
import 'package:my_app/tabs/recommended_tab.dart';
import 'package:my_app/tabs/saved_schemes_tab.dart'; // <-- 1. IMPORT NEW TAB

class MainScreen extends StatefulWidget {
  final String selectedLanguage; // Assuming English for now
  const MainScreen({super.key, required this.selectedLanguage});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Default to "All Schemes"
  late List<Widget> _widgetOptions;

  // --- 2. ADD A KEY TO FORCE REFRESH ---
  Key _savedTabKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _buildWidgetOptions(); // Build options in a separate method
  }

  // --- 3. CREATE THIS METHOD ---
  void _buildWidgetOptions() {
    _widgetOptions = <Widget>[
      AllSchemesTab(selectedLanguage: widget.selectedLanguage),
      StateSchemesTab(selectedLanguage: widget.selectedLanguage),
      RecommendedTab(selectedLanguage: widget.selectedLanguage),
      // --- 4. ADD THE NEW TAB WIDGET ---
      SavedSchemesTab(
        key: _savedTabKey, // Assign the key
        selectedLanguage: widget.selectedLanguage
      ),
    ];
  }

  void _onItemTapped(int index) {
    // --- 5. ADD REFRESH LOGIC ---
    // If the user taps the 'Saved' tab, generate a new key
    // This forces the SavedSchemesTab to rebuild and reload data
    if (index == 3) {
      setState(() {
         _savedTabKey = UniqueKey();
         _buildWidgetOptions(); // Rebuild widget list with the new key
      });
    }
    
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use IndexedStack to keep the state of each tab alive
      body: IndexedStack(
         index: _selectedIndex,
         children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        // --- 6. ADD THE NEW ITEM ---
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded),
            label: 'All Schemes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city_rounded),
            label: 'By State',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_rounded),
            label: 'Recommended',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_rounded), // <-- NEW ICON
            label: 'Saved', // <-- NEW LABEL
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Ensure labels are always visible
      ),
    );
  }
}
Offline-First Scheme Recommender
An offline-first, multilingual (EN, HI, TA) Flutter application designed to help users discover relevant government schemes without an internet connection. The app provides personalized recommendations by filtering a large, bundled JSON dataset of over 3,700 schemes directly on the user's device.

This project is built to be a high-performance, responsive, and always-available mobile solution, demonstrating how to manage and filter a large local dataset efficiently—a core requirement for modern mobile applications (like management games, productivity tools, etc.).

✨ Core Features
100% Offline-First: The app is fully functional without an internet connection. All 3,700+ schemes are bundled locally as a JSON asset.

Multilingual Support: Full UI and data support for English, Hindi, and Tamil. The user can switch languages at any time.

Personalized Recommendations: A robust local filtering engine recommends schemes by matching a user's profile (Age, Gender, State, Caste, Occupation) against complex scheme criteria.

Dynamic Category Filtering: The "All Schemes" tab features a horizontal, icon-based chip list (e.g., 🌾 Agriculture, 💰 Loan, 🎓 Student) with a live count of schemes in each category.

Advanced Search & Filtering: Users can browse schemes by State/Central status or use the search bar within any category to filter results instantly.

Bookmarking: Users can save their favorite schemes to a "Saved" tab for quick access. This state is persistent and synced across all app views.

Text-to-Speech (TTS): Integrated TTS reads scheme details aloud in the user's selected language (EN, HI, or TA) for enhanced accessibility.

Rich Content Display: Scheme details are rendered using Markdown to display highlighted bold text for key information (e.g., amounts, eligibility), making complex data easy to scan.

🏛️ Architecture
This project is intentionally built as an offline-first application to ensure a fast, responsive, and reliable user experience, even with a poor or non-existent internet connection.

Data Source: All scheme data is pre-processed (translated, categorized) and stored in a single cleaned_schemes.json file, which is bundled directly with the app.

Data Handling:

SchemeService: Loads the bundled JSON data into memory.

CachingService: Uses Hive as a resilient backup cache for the scheme data.

State & Filtering: All filtering, searching, and recommendation logic happens locally on the user's device for instant results.

User Data: SharedPreferences is used for storing the user's profile and bookmark IDs.

🛠️ Technologies Used
Flutter & Dart

Local Storage: hive (for data caching) & shared_preferences (for user profile/bookmarks).

UI Components: flutter_markdown (for rendering rich text), flutter_tts (for accessibility).

State Management: setState (used for managing local state within each tab).

🚀 Getting Started
Clone the repository:

Bash

git clone https://github.com/Akzz06/Scheme-recommender.git
Navigate to the project directory:

Bash

cd Scheme-recommender
Install dependencies:

Bash

flutter pub get
Run the app:

Bash

flutter run

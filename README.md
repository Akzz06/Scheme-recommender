# 🌾 **Offline-First Scheme Recommender App**

### 🧠 Overview  
An **offline-first, multilingual (EN | HI | TA)** Flutter application that helps users discover **relevant government schemes** — even **without an internet connection**.  
It filters a **large bundled dataset (3,700+ schemes)** directly on the user’s device to provide **personalized recommendations** based on user profiles.

This project demonstrates how to build **high-performance**, **responsive**, and **always-available** mobile apps capable of managing large datasets efficiently — a principle often applied in **management games and productivity tools**.

---

## ✨ **Core Features**

- 📴 **100% Offline-First:**  
  Fully functional without internet. All 3,700+ schemes are bundled locally in a JSON file.  

- 🌐 **Multilingual Support:**  
  Full UI and data support for **English**, **Hindi**, and **Tamil**. Language can be switched dynamically.  

- 👤 **Personalized Recommendations:**  
  Intelligent local filtering engine matches the user’s profile *(Age, Gender, State, Caste, Occupation)* to relevant schemes.  

- 🧩 **Dynamic Category Filtering:**  
  The “All Schemes” tab features an icon-based chip list (🌾 Agriculture | 💰 Loan | 🎓 Student | 🏠 Housing)  
  with **real-time scheme counts** for each category.  

- 🔍 **Advanced Search & Filters:**  
  Filter instantly by **State/Central** status or search within any category for instant results.  

- 💾 **Bookmarking:**  
  Save favorite schemes to a **Saved tab**, persistent across app restarts using local storage.  

- 🗣️ **Text-to-Speech (TTS):**  
  Integrated **flutter_tts** reads scheme details aloud in the user’s selected language (EN, HI, TA).  

- 📄 **Rich Markdown Display:**  
  Scheme details rendered in **Markdown** for bold highlights and structured, easy-to-read information.

---

## 🏛️ **Architecture**

Built as a **truly offline-first** application for **speed**, **reliability**, and **instant responsiveness**, even with poor connectivity.

**🗂 Data Source:**  
All scheme data is preprocessed, categorized, and stored in a single `cleaned_schemes.json` file bundled with the app.

**🧩 Data Handling Workflow:**
| Component | Purpose |
|------------|----------|
| `SchemeService` | Loads bundled JSON data into memory |
| `CachingService` | Uses **Hive** for resilient local caching |
| **Filtering Engine** | Handles real-time search and filtering locally |
| `SharedPreferences` | Stores user profiles and bookmarks |

---

## 🛠️ **Technologies Used**

| Category | Tools & Frameworks |
|-----------|--------------------|
| **Language** | Flutter, Dart |
| **Local Storage** | Hive, SharedPreferences |
| **UI Components** | flutter_markdown, flutter_tts |
| **State Management** | setState (local state per tab) |

---

## 🚀 **Getting Started**

### Clone the repository:
```bash
git clone https://github.com/Akzz06/Scheme-recommender.git

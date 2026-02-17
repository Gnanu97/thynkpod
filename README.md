# 🤖 Thynkpod

Thinkpod is a multi-feature Flutter application designed to integrate smart device interaction, audio recording, intelligent processing, personal tracking, and productivity tools into one unified platform.

Built using Flutter, Thinkpod runs on Android, iOS, Web, Windows, macOS, and Linux using a single codebase.

------------------------------------------------------------

## 🚀 Overview

Thynkpod combines:

• BLE device connectivity  
• Audio recording & playback  
• Speech-to-text processing  
• AI-powered title generation  
• Diary tracking with sentiment support  
• Finance tracking and analytics  
• File management from connected devices  
• Cross-platform UI with modern navigation  

This project demonstrates full-stack Flutter application architecture with services, providers, models, and modular screens.

------------------------------------------------------------

## 🛠️ Tech Stack

• Flutter  
• Dart  
• BLE integration  
• Local database services  
• Audio playback & recording services  
• AI service integration (Groq API – via environment variables)  
• Provider-based state management  

------------------------------------------------------------

## 📂 Project Structure

lib/
  diary_tracking/
  finance_tracking/
  models/
  providers/
  screens/
  services/
  utils/
  widgets/
  main.dart

Each folder follows modular separation:

• models → Data classes  
• services → Business logic & API communication  
• providers → State management  
• screens → UI pages  
• widgets → Reusable UI components  
• utils → Helper functions & constants  

------------------------------------------------------------

## 🔐 Environment Configuration

IMPORTANT: API keys are NOT stored in the repository.

Create a file named:

.env

Inside the project root and add:

GROQ_API_KEY=YOUR_API_KEY_HERE

Make sure `.env` is added to `.gitignore`.

If using flutter_dotenv, load it in main.dart:

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

Access API key using:

final apiKey = dotenv.env['GROQ_API_KEY'];

------------------------------------------------------------

## 📥 Installation Guide

### 1️⃣ Clone Repository

git clone https://github.com/Gnanu97/thynkpod.git
cd thynkpod

### 2️⃣ Install Dependencies

flutter pub get

### 3️⃣ Run Application

For Android/iOS:
flutter run

For Web:
flutter run -d web

For Windows:
flutter run -d windows

For macOS:
flutter run -d macos

For Linux:
flutter run -d linux

------------------------------------------------------------

## 🧠 Core Functional Modules

BLE Module:
• Device scanning
• Connection handling
• File transfers

Audio Module:
• Audio recording
• Playback
• File storage management

AI Module:
• Speech-to-text
• Title generation
• Sentiment analysis (Diary)

Finance Module:
• Transaction tracking
• Category management
• Weekly and calendar-based analytics

Diary Module:
• Entry management
• Monthly trends
• Sentiment insights

------------------------------------------------------------

## 📌 Features

✔ Multi-platform support  
✔ Modular architecture  
✔ Clean separation of concerns  
✔ Secure API key handling  
✔ Expandable feature structure  
✔ Provider-based state management  

------------------------------------------------------------

## 🧪 Testing

Run widget tests:

flutter test

------------------------------------------------------------

## 🏗️ Build Release

Android APK:
flutter build apk

Android App Bundle:
flutter build appbundle

Web Build:
flutter build web

Windows:
flutter build windows

------------------------------------------------------------

## 🤝 Contributing

1. Fork repository  
2. Create new branch  
   git checkout -b feature/your-feature  
3. Commit changes  
   git commit -m "Added new feature"  
4. Push branch  
   git push origin feature/your-feature  
5. Open Pull Request  

------------------------------------------------------------

## 📝 License

This project is currently for development and educational purposes.
Add an MIT license file if publishing publicly.

------------------------------------------------------------

## 👨‍💻 Author

Developed by Gnanu97  
Flutter Multi-Platform Application Project  

------------------------------------------------------------

If you find this project useful, consider starring the repository.

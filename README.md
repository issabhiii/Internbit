🎮 Memory Puzzle – Flutter + Supabase

Memory Puzzle is a cross-platform Flutter application featuring Quest Mode, Supabase authentication, and interactive memory-matching gameplay.
It demonstrates structured UI design, cloud-stored game data, and persistent user progress tracking.

🚀 Features
🔐 Authentication

Email + Password login

Google OAuth (Supabase)

Secure session handling

Logout & success animation

🧩 Quest Mode

Quests loaded from Supabase games table

Unlockable levels (each quest depends on previous completion)

Memory game powered by JSON card-pair data

User progress saved in users.games_complete

🎨 Dynamic Theming

Light/Dark mode toggle

Smooth UI gradients

Modern components + animations

⚙️ Settings

Dark mode switch

Refresh stats

Feedback popup

Privacy Policy / Terms of Service

Logout with success overlay

🗄️ Supabase Tables
games
Column	Type	Description
id	bigint (PK)	Auto-generated
gameid	bigint	Quest number
questions	text	Quest title
pairs	json	Memory card pairs
theme	text	"quest"
reviewed	text	Status
users
Column	Type
email	text
games_complete	array/json of completed game IDs
🧱 Tech Stack

Flutter 3

Supabase (Auth + Database)

Dart

Material 3 UI

Google OAuth

▶️ Run Locally
flutter pub get
flutter run


For Web Google Sign-in, ensure:

Correct Authorized redirect URIs

Correct Authorized JavaScript origins
in Google Cloud Console + Supabase.

📁 Main File Structure
lib/
 ├── quest_screen.dart
 ├── memory_game_page.dart
 ├── settings_screen.dart
 ├── theme_manager.dart
 ├── main.dart

📄 License

This project is for educational and internship demonstration purposes.

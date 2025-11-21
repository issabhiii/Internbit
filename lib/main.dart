// ------------------------------------------------------------
//  Memory Puzzle Game with Smooth Card Flip Animations
//  Custom 3D flip animation implementation
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'theme_manager.dart';
import 'quest_screen.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  debugPrint('[APP] 🚀 Starting Memory Puzzle App...');
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  debugPrint('[APP] 🔧 Initializing Supabase...');
  try {
    await Supabase.initialize(
      url:
          'https://pabbnxaimlkcrawqfavj.supabase.co', // Replace with your Supabase project URL
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhYmJueGFpbWxrY3Jhd3FmYXZqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3NDg3ODcsImV4cCI6MjA3OTMyNDc4N30.0bda9zkTYuqr9PWJvpkzV-MSKr_CmWH-3zGS4t-Vt44', // Replace with your Supabase anon/public key
    );
    debugPrint('[APP] ✅ Supabase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('[APP] ❌ Failed to initialize Supabase: $e');
    debugPrint('[APP] 📋 Stack trace: $stackTrace');
    rethrow;
  }

  debugPrint('[APP] 🎮 Running Memory Puzzle App...');
  runApp(const MemoryPuzzleApp());
}

class MemoryPuzzleApp extends StatefulWidget {
  const MemoryPuzzleApp({super.key});

  @override
  State<MemoryPuzzleApp> createState() => _MemoryPuzzleAppState();
}

class _MemoryPuzzleAppState extends State<MemoryPuzzleApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    ThemeManager.setCallback(_toggleDarkMode);
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('dark_mode') ?? false;
      if (mounted) {
        setState(() {
          _isDarkMode = isDark;
        });
        ThemeManager.setDarkMode(isDark);
      }
    } catch (e) {
      debugPrint('[APP] Error loading theme preference: $e');
    }
  }

  void _toggleDarkMode(bool value) async {
    if (mounted) {
      setState(() {
        _isDarkMode = value;
      });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', value);
      debugPrint('[APP] Theme preference saved: dark_mode=$value');
    } catch (e) {
      debugPrint('[APP] Error saving theme preference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Puzzle Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomePage(),
    );
  }
}

// ------------------------------------------------------------
//                          HOME PAGE
// ------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final TextEditingController _codeController = TextEditingController();
  List<Map<String, dynamic>> _games = [];
  List<Map<String, dynamic>> _completedGames = [];
  List<int> _completedGameIds = [];
  bool _isLoadingGames = false;
  bool _isExpandedCompleted = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    debugPrint('[HOME] 🚀 HomePage initialized, loading games...');
    // Load games immediately when page opens
    _loadGames();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload games when page becomes visible again
    debugPrint(
      '[HOME] 🔄 HomePage dependencies changed, checking if games need reload...',
    );
  }

  @override
  void didPopNext() {
    // Called when returning to this route from another route
    debugPrint('[HOME] 🔄 Returned to HomePage, reloading games...');
    _loadGames();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadGames() async {
    debugPrint('[HOME] 📥 Starting to load games from Supabase...');
    setState(() {
      _isLoadingGames = true;
      _searchError = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // First, load user's completed games if logged in
      _completedGameIds = [];
      _completedGames = [];
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null && currentUser.email != null) {
        try {
          debugPrint('[HOME] 🔍 Loading user\'s completed games...');
          final userData = await supabase
              .from('users')
              .select('games_complete')
              .eq('email', currentUser.email!)
              .maybeSingle();

          if (userData != null && userData['games_complete'] != null) {
            final gamesComplete = userData['games_complete'];
            if (gamesComplete is List) {
              _completedGameIds = List<int>.from(
                gamesComplete.map((e) => e is int ? e : (e as num).toInt()),
              );
              debugPrint(
                '[HOME] ✅ Loaded ${_completedGameIds.length} completed game IDs: $_completedGameIds',
              );
            } else if (gamesComplete is String) {
              // Parse JSON string
              final parsed = jsonDecode(gamesComplete);
              if (parsed is List) {
                _completedGameIds = List<int>.from(
                  parsed.map((e) => e is int ? e : (e as num).toInt()),
                );
                debugPrint(
                  '[HOME] ✅ Loaded ${_completedGameIds.length} completed game IDs from JSON: $_completedGameIds',
                );
              }
            }
          }
        } catch (e) {
          debugPrint('[HOME] ⚠️ Error loading completed games: $e');
        }
      }

      debugPrint('[HOME] 🔍 Querying Supabase games table...');
      debugPrint(
        '[HOME] 📋 Query: SELECT id, questions, pairs, gameid, theme, reviewed FROM games WHERE theme != "custom" ORDER BY gameid',
      );

      final response = await supabase
          .from('games')
          .select('id, questions, pairs, gameid, theme, reviewed')
          .neq('theme', 'custom')
          .neq('theme', 'quest')
          .order('gameid');

      debugPrint('[HOME] ✅ Supabase query successful');
      debugPrint('[HOME] 📊 Raw response type: ${response.runtimeType}');
      debugPrint('[HOME] 📊 Response length: ${response.length}');

      if (response.isNotEmpty) {
        debugPrint('[HOME] 📋 First game sample: ${response.first}');
      }

      final allGames = List<Map<String, dynamic>>.from(response);
      debugPrint('[HOME] ✅ Converted to list: ${allGames.length} games');

      // Separate completed and available games
      final availableGames = <Map<String, dynamic>>[];
      final completedGamesList = <Map<String, dynamic>>[];

      for (final game in allGames) {
        final gameid = (game['gameid'] as num?)?.toInt();
        if (gameid != null && _completedGameIds.contains(gameid)) {
          completedGamesList.add(game);
        } else {
          availableGames.add(game);
        }
      }

      debugPrint('[HOME] 🎮 Available games: ${availableGames.length}');
      debugPrint('[HOME] 🎮 Completed games: ${completedGamesList.length}');

      setState(() {
        _games = availableGames;
        _completedGames = completedGamesList;
        _isLoadingGames = false;
      });

      debugPrint(
        '[HOME] ✅ Successfully loaded ${_games.length} available games and ${_completedGames.length} completed games',
      );
      debugPrint('[HOME] 🎯 Games lists updated in state');
    } catch (e, stackTrace) {
      debugPrint('[HOME] ❌ Error loading games: $e');
      debugPrint('[HOME] 📋 Stack trace: $stackTrace');
      setState(() {
        _isLoadingGames = false;
        _searchError = 'Failed to load games. Please try again.';
      });
      debugPrint('[HOME] ⚠️ Error state set, showing error message to user');
    }
  }

  Future<void> _searchByCode() async {
    final codeText = _codeController.text.trim();
    debugPrint('[HOME] 🔍 Search initiated with code: "$codeText"');

    if (codeText.isEmpty) {
      debugPrint('[HOME] ⚠️ Empty code entered');
      setState(() {
        _searchError = 'Please enter a game code';
      });
      return;
    }

    final gameid = int.tryParse(codeText);
    if (gameid == null) {
      debugPrint('[HOME] ⚠️ Invalid code format: "$codeText"');
      setState(() {
        _searchError = 'Invalid game code. Please enter a number.';
      });
      return;
    }

    debugPrint('[HOME] 🔍 Searching for game with gameid: $gameid');
    setState(() {
      _isLoadingGames = true;
      _searchError = null;
    });

    try {
      final supabase = Supabase.instance.client;
      debugPrint('[HOME] 📋 Query: SELECT * FROM games WHERE gameid = $gameid');

      final response = await supabase
          .from('games')
          .select('id, questions, pairs, gameid, theme, reviewed')
          .eq('gameid', gameid)
          .maybeSingle();

      debugPrint(
        '[HOME] 📊 Search response: ${response != null ? "Found" : "Not found"}',
      );

      if (response == null) {
        debugPrint('[HOME] ❌ Game with gameid $gameid not found');
        setState(() {
          _isLoadingGames = false;
          _searchError = 'Game not found. Please check the code.';
        });
        return;
      }

      debugPrint(
        '[HOME] ✅ Game found: id=${response['id']}, gameid=${response['gameid']}, theme=${response['theme']}',
      );
      debugPrint('[HOME] 🎮 Starting game with found data...');

      // Start the game with the found game data
      _startGame(response);
    } catch (e, stackTrace) {
      debugPrint('[HOME] ❌ Error searching game: $e');
      debugPrint('[HOME] 📋 Stack trace: $stackTrace');
      setState(() {
        _isLoadingGames = false;
        _searchError = 'Error searching for game. Please try again.';
      });
    }
  }

  void _startGame(Map<String, dynamic>? gameData) {
    if (gameData != null) {
      debugPrint(
        '[HOME] 🎮 Starting game with data: gameid=${gameData['gameid']}, theme=${gameData['theme']}',
      );
    } else {
      debugPrint('[HOME] 🎮 Starting default game (no game data)');
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemoryGamePage(gameData: gameData),
      ),
    ).then((_) {
      // Reload games when returning from game page
      debugPrint('[HOME] 🔄 Returned from game page, reloading games...');
      _loadGames();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Puzzle Game'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background image - fill 100% of screen
          Positioned.fill(
            child: Image.asset(
              'lib/Gemini_Generated_Image_4sop514sop514sop (1).png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to gradient if image not found
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.blue.shade100, Colors.blue.shade300],
                    ),
                  ),
                );
              },
            ),
          ),
          // Content overlay
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Start Quest Button
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QuestScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 28),
                  label: const Text(
                    'Start Quest',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 20,
                    ),
                    backgroundColor: Colors.blue,
                  ),
                ),
                const SizedBox(height: 32),
                // Search Box
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enter Game Code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _codeController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'Enter game code (e.g., 1003)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isLoadingGames ? null : _searchByCode,
                              child: _isLoadingGames
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Search'),
                            ),
                          ],
                        ),
                        if (_searchError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _searchError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Available Games List
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Games',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingGames)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_games.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No games available'),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _games.length,
                            itemBuilder: (context, index) {
                              final game = _games[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    game['questions']?.toString() ??
                                        'Memory Puzzle',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Theme: ${game['theme'] ?? 'N/A'} | Code: ${game['gameid'] ?? 'N/A'}',
                                  ),
                                  trailing: const Icon(Icons.play_arrow),
                                  onTap: () => _startGame(game),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                // Completed Games List
                if (_completedGames.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Completed Games',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _isExpandedCompleted
                                ? _completedGames.length
                                : (_completedGames.length > 4
                                      ? 4
                                      : _completedGames.length),
                            itemBuilder: (context, index) {
                              final game = _completedGames[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    game['questions']?.toString() ??
                                        'Memory Puzzle',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Theme: ${game['theme'] ?? 'N/A'} | Code: ${game['gameid'] ?? 'N/A'}',
                                  ),
                                  trailing: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  onTap: () => _startGame(game),
                                ),
                              );
                            },
                          ),
                          if (_completedGames.length > 4)
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isExpandedCompleted =
                                        !_isExpandedCompleted;
                                  });
                                },
                                icon: Icon(
                                  _isExpandedCompleted
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                ),
                                label: Text(
                                  _isExpandedCompleted
                                      ? 'Show Less'
                                      : 'Show More (${_completedGames.length - 4})',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
//                     MEMORY GAME PAGE
// ------------------------------------------------------------

class MemoryGamePage extends StatefulWidget {
  final Map<String, dynamic>? gameData;

  const MemoryGamePage({super.key, this.gameData});

  @override
  State<MemoryGamePage> createState() => _MemoryGamePageState();
}

class _MemoryGamePageState extends State<MemoryGamePage> {
  int rows = 4;
  int cols = 4;
  int totalPairs = 8;
  String? question;
  String? theme;

  List<CardModel> cards = [];
  int? firstIndex;
  int? secondIndex;
  int moves = 0;
  int matchedPairs = 0;
  bool lockBoard = false;

  @override
  void initState() {
    super.initState();
    _parseGameData();
    _initGame();
  }

  void _parseGameData() {
    if (widget.gameData != null) {
      question = widget.gameData!['questions']?.toString();
      theme = widget.gameData!['theme']?.toString();

      // Parse pairs from JSON
      try {
        final pairsData = widget.gameData!['pairs'];
        if (pairsData != null) {
          List<String> pairs;
          if (pairsData is String) {
            // Parse JSON string
            pairs = List<String>.from(jsonDecode(pairsData));
          } else if (pairsData is List) {
            pairs = List<String>.from(pairsData);
          } else {
            pairs = [];
          }

          totalPairs = pairs.length ~/ 2; // Each pair appears twice

          // Calculate grid size based on total cards
          final totalCards = pairs.length;
          if (totalCards <= 16) {
            rows = 4;
            cols = 4;
          } else if (totalCards <= 20) {
            rows = 4;
            cols = 5;
          } else if (totalCards <= 24) {
            rows = 4;
            cols = 6;
          } else {
            // For larger grids, calculate dynamically
            rows = 4;
            cols = (totalCards / rows).ceil();
          }

          debugPrint(
            '[GAME] Parsed game data: question=$question, theme=$theme, totalCards=$totalCards, totalPairs=$totalPairs, grid=${rows}x$cols',
          );
        }
      } catch (e) {
        debugPrint('[GAME] Error parsing pairs: $e');
      }
    }
  }

  void _initGame() {
    print('[GAME] Initializing new game...');

    if (widget.gameData != null && widget.gameData!['pairs'] != null) {
      // Use pairs from game data
      try {
        final pairsData = widget.gameData!['pairs'];
        List<String> pairs;
        if (pairsData is String) {
          pairs = List<String>.from(jsonDecode(pairsData));
        } else if (pairsData is List) {
          pairs = List<String>.from(pairsData);
        } else {
          pairs = [];
        }

        if (pairs.isEmpty) {
          debugPrint('[GAME] Empty pairs array, falling back to default');
          _initDefaultGame();
          return;
        }

        // Calculate total pairs (each symbol appears twice)
        totalPairs = pairs.length ~/ 2;

        // Shuffle the pairs array to randomize card positions
        final deck = [...pairs]..shuffle(Random());

        print(
          '[GAME] Using game data: $totalPairs pairs, ${deck.length} cards, grid=${rows}x$cols',
        );

        cards = List.generate(
          deck.length,
          (i) => CardModel(
            id: i,
            symbol: deck[i],
            isFlipped: false,
            isMatched: false,
          ),
        );
      } catch (e) {
        debugPrint('[GAME] Error using game data, falling back to default: $e');
        _initDefaultGame();
        return;
      }
    } else {
      _initDefaultGame();
      return;
    }

    moves = 0;
    matchedPairs = 0;
    firstIndex = null;
    secondIndex = null;
    lockBoard = false;
    print(
      '[GAME] ✅ Game initialized: ${cards.length} cards, $totalPairs pairs',
    );
    setState(() {});
  }

  void _initDefaultGame() {
    const List<String> pool = [
      '🎮',
      '🎯',
      '🎨',
      '🎪',
      '🎭',
      '🎬',
      '🎤',
      '🎧',
      '🎸',
      '🎹',
      '🎺',
      '🎻',
      '🥁',
      '🎲',
      '🎳',
      '🎰',
    ];

    final symbols = pool.take(totalPairs).toList();
    final deck = [...symbols, ...symbols]..shuffle(Random());
    print(
      '[GAME] Created default deck with ${deck.length} cards, ${totalPairs} pairs',
    );

    cards = List.generate(
      deck.length,
      (i) =>
          CardModel(id: i, symbol: deck[i], isFlipped: false, isMatched: false),
    );

    moves = 0;
    matchedPairs = 0;
    firstIndex = null;
    secondIndex = null;
    lockBoard = false;
    print(
      '[GAME] ✅ Default game initialized: ${cards.length} cards, $totalPairs pairs',
    );
    setState(() {});
  }

  void _tapCard(int i) {
    print('[GAME] Card tapped: index=$i, symbol=${cards[i].symbol}');

    if (lockBoard || cards[i].isFlipped || cards[i].isMatched) {
      print(
        '[GAME] Card tap ignored: lockBoard=$lockBoard, isFlipped=${cards[i].isFlipped}, isMatched=${cards[i].isMatched}',
      );
      return;
    }

    setState(() {
      cards[i] = CardModel(
        id: cards[i].id,
        symbol: cards[i].symbol,
        isFlipped: true,
        isMatched: cards[i].isMatched,
      );
    });
    print('[GAME] Card flipped: index=$i');

    if (firstIndex == null) {
      firstIndex = i;
      print('[GAME] First card selected: index=$i');
      return;
    }

    secondIndex = i;
    moves++;
    print('[GAME] Second card selected: index=$i, moves=$moves');

    final c1 = cards[firstIndex!];
    final c2 = cards[secondIndex!];

    if (c1.symbol == c2.symbol) {
      // match
      print('[GAME] Match found! Symbols: ${c1.symbol} == ${c2.symbol}');
      setState(() {
        cards[firstIndex!] = CardModel(
          id: c1.id,
          symbol: c1.symbol,
          isFlipped: c1.isFlipped,
          isMatched: true,
        );
        cards[secondIndex!] = CardModel(
          id: c2.id,
          symbol: c2.symbol,
          isFlipped: c2.isFlipped,
          isMatched: true,
        );
        matchedPairs++;
      });
      print('[GAME] Matched pairs: $matchedPairs / $totalPairs');

      firstIndex = null;
      secondIndex = null;

      if (matchedPairs == totalPairs) {
        print('[GAME] 🎉 GAME WON! All pairs matched. Moves: $moves');
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            print('[GAME] Showing win dialog...');
            _winDialog();
          } else {
            print('[GAME] Widget not mounted, cannot show dialog');
          }
        });
      }
    } else {
      lockBoard = true;
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          cards[firstIndex!] = CardModel(
            id: c1.id,
            symbol: c1.symbol,
            isFlipped: false,
            isMatched: c1.isMatched,
          );
          cards[secondIndex!] = CardModel(
            id: c2.id,
            symbol: c2.symbol,
            isFlipped: false,
            isMatched: c2.isMatched,
          );
          firstIndex = null;
          secondIndex = null;
          lockBoard = false;
        });
      });
    }
  }

  Future<void> _winDialog() async {
    print(
      '[WIN_DIALOG] Starting win dialog. Moves: $moves, Pairs: $totalPairs',
    );

    // Calculate current ratio
    final currentRatio = totalPairs / moves;
    print('[WIN_DIALOG] Current ratio: $currentRatio');

    // Try to save stats to both local storage and Supabase
    print('[WIN_DIALOG] Saving game stats...');
    try {
      // Save to local storage first
      print('[WIN_DIALOG] Saving to local storage...');
      await GameStats.incrementGamesWon();
      await GameStats.addTotalMoves(moves);
      await GameStats.updateBestScore(moves);
      await GameStats.updateBestRatio(moves, totalPairs);
      print('[WIN_DIALOG] ✅ Local stats saved');

      // Save to Supabase if user is logged in
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null && currentUser.email != null) {
        print('[WIN_DIALOG] Saving to Supabase...');
        try {
          // Get current user data
          final userData = await supabase
              .from('users')
              .select(
                'games_completed, best_ratio, total_moves, best_score, games_complete',
              )
              .eq('email', currentUser.email!)
              .maybeSingle();

          final currentGamesCompleted =
              (userData?['games_completed'] as num?)?.toInt() ?? 0;
          final currentBestRatio = (userData?['best_ratio'] as num?)
              ?.toDouble();
          final currentTotalMoves =
              (userData?['total_moves'] as num?)?.toInt() ?? 0;
          final currentBestScore = (userData?['best_score'] as num?)?.toInt();

          // Get current games_complete array
          List<int> gamesComplete = [];
          if (userData?['games_complete'] != null) {
            final gamesCompleteData = userData!['games_complete'];
            if (gamesCompleteData is List) {
              gamesComplete = List<int>.from(
                gamesCompleteData.map((e) => e is int ? e : (e as num).toInt()),
              );
            } else if (gamesCompleteData is String) {
              final parsed = jsonDecode(gamesCompleteData);
              if (parsed is List) {
                gamesComplete = List<int>.from(
                  parsed.map((e) => e is int ? e : (e as num).toInt()),
                );
              }
            }
          }

          // Add current game's gameid to completed games if it's from database
          if (widget.gameData != null && widget.gameData!['gameid'] != null) {
            final gameid = (widget.gameData!['gameid'] as num).toInt();
            if (!gamesComplete.contains(gameid)) {
              gamesComplete.add(gameid);
              print(
                '[WIN_DIALOG] ✅ Added gameid $gameid to completed games list',
              );
            }
          }

          // Update games_completed (increment by 1)
          final newGamesCompleted = currentGamesCompleted + 1;

          // Update total_moves (add current game moves)
          final newTotalMoves = currentTotalMoves + moves;

          // Update best_ratio if current is better (higher is better)
          double? newBestRatio = currentBestRatio;
          if (currentBestRatio == null || currentRatio > currentBestRatio) {
            newBestRatio = currentRatio;
            print(
              '[WIN_DIALOG] 🎯 New best ratio: $newBestRatio (was $currentBestRatio)',
            );
          }

          // Update best_score if current is better (lower is better for moves)
          int? newBestScore = currentBestScore;
          if (currentBestScore == null || moves < currentBestScore) {
            newBestScore = moves;
            print(
              '[WIN_DIALOG] 🎯 New best score: $newBestScore moves (was $currentBestScore)',
            );
          }

          // Calculate average moves (total_moves / games_completed)
          final newAvgMoves = newTotalMoves ~/ newGamesCompleted;

          // Update in Supabase
          await supabase
              .from('users')
              .update({
                'games_completed': newGamesCompleted,
                'best_ratio': newBestRatio,
                'total_moves': newTotalMoves,
                'best_score': newBestScore,
                'avg_moves': newAvgMoves,
                'games_complete': gamesComplete,
              })
              .eq('email', currentUser.email!);

          print(
            '[WIN_DIALOG] ✅ Supabase stats updated: games=$newGamesCompleted, ratio=$newBestRatio',
          );
        } catch (e) {
          print('[WIN_DIALOG] ❌ Error saving to Supabase: $e');
          // Continue anyway - local storage is saved
        }
      } else {
        print('[WIN_DIALOG] User not logged in, skipping Supabase save');
      }
    } catch (e) {
      print('[WIN_DIALOG] ❌ Error saving stats: $e');
      // Continue anyway - show the dialog
    }

    double? bestRatio;
    try {
      // Get best ratio from Supabase if logged in, otherwise from local
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null && currentUser.email != null) {
        try {
          final userData = await supabase
              .from('users')
              .select('best_ratio')
              .eq('email', currentUser.email!)
              .maybeSingle();

          if (userData?['best_ratio'] != null) {
            bestRatio = (userData!['best_ratio'] as num).toDouble();
            print('[WIN_DIALOG] Best ratio from Supabase: $bestRatio');
          }
        } catch (e) {
          print('[WIN_DIALOG] Error loading ratio from Supabase: $e');
        }
      }

      // Fallback to local storage
      if (bestRatio == null) {
        bestRatio = await GameStats.getBestRatio();
        print('[WIN_DIALOG] Best ratio from local: $bestRatio');
      }
    } catch (e) {
      print('[WIN_DIALOG] ❌ Error loading best ratio: $e');
    }

    if (!mounted) {
      print('[WIN_DIALOG] ❌ Widget not mounted, cannot show dialog');
      return;
    }

    print('[WIN_DIALOG] Showing dialog...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("🎉 You Win!"),
        content: Text(
          "Moves: $moves\n"
          "Match Quality: ${(totalPairs / moves * 100).toStringAsFixed(1)}%\n"
          "Best Ratio: ${bestRatio != null ? (bestRatio * 100).toStringAsFixed(1) : 'N/A'}%",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initGame();
            },
            child: const Text("Play Again"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close the win dialog
              // If it's a quest game, go back to quest screen, otherwise go to profile
              if (widget.gameData != null &&
                  widget.gameData!['theme']?.toString() == 'quest') {
                Navigator.pop(context); // Go back to quest screen
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              }
            },
            child: Text(
              widget.gameData != null &&
                      widget.gameData!['theme']?.toString() == 'quest'
                  ? "Play Next"
                  : "Profile",
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final textScale = MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5);

    // Calculate responsive font sizes
    final titleFontSize = (screenWidth * 0.06 * textScale).clamp(18.0, 28.0);
    final subtitleFontSize = (screenWidth * 0.04 * textScale).clamp(14.0, 20.0);
    final statsFontSize = (screenWidth * 0.045 * textScale).clamp(16.0, 24.0);
    final matchesFontSize = (screenWidth * 0.04 * textScale).clamp(14.0, 20.0);

    // Calculate responsive spacing based on screen size
    final gridSpacing = screenWidth * 0.025;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Puzzle'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _initGame),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: screenHeight * 0.01),
          // Question and Theme
          if (question != null || theme != null) ...[
            if (question != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                child: Text(
                  question!,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (theme != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.005,
                ),
                child: Text(
                  'Theme: $theme',
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: screenHeight * 0.01),
          ],
          Text("Moves: $moves", style: TextStyle(fontSize: statsFontSize)),
          Text(
            "Matches: $matchedPairs / $totalPairs",
            style: TextStyle(fontSize: matchesFontSize),
          ),
          SizedBox(height: screenHeight * 0.01),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(screenWidth * 0.04),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: gridSpacing,
                mainAxisSpacing: gridSpacing,
                childAspectRatio: 1.0,
              ),
              itemCount: cards.length,
              itemBuilder: (_, i) => MemoryCard(
                key: ValueKey('card_${cards[i].id}'),
                card: cards[i],
                onTap: () => _tapCard(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
//                          MEMORY CARD
// ------------------------------------------------------------

class MemoryCard extends StatefulWidget {
  final CardModel card;
  final VoidCallback onTap;

  const MemoryCard({super.key, required this.card, required this.onTap});

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    // Initialize based on current state
    if (widget.card.isFlipped) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(MemoryCard old) {
    super.didUpdateWidget(old);

    // If card becomes matched, ensure it's flipped
    if (widget.card.isMatched && !old.card.isMatched) {
      if (_controller.value < 1.0) {
        _controller.forward();
      }
      return;
    }

    // If flip state changed, animate
    if (widget.card.isFlipped != old.card.isFlipped) {
      if (widget.card.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.card.isFlipped || widget.card.isMatched
          ? null
          : widget.onTap,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * 3.14159; // π radians
          final isFrontVisible = _flipAnimation.value > 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective
              ..rotateY(angle),
            child: isFrontVisible
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateY(3.14159), // Mirror the front
                    child: _frontCard(),
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateY(3.14159), // Mirror the back
                    child: _backCard(),
                  ),
          );
        },
      ),
    );
  }

  Widget _frontCard() {
    // Get screen size for responsive sizing
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final textScale = MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5);

    // Calculate responsive font size based on screen width
    // Use a percentage of screen width, clamped to reasonable bounds
    final symbolFontSize = (screenWidth * 0.08 * textScale).clamp(20.0, 48.0);

    return _styledCard(
      color: widget.card.isMatched
          ? Colors.green.shade100
          : Colors.blue.shade50,
      border: widget.card.isMatched
          ? Colors.green.shade400
          : Colors.blue.shade300,
      child: Text(
        widget.card.symbol,
        style: TextStyle(fontSize: symbolFontSize),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _backCard() {
    // Get screen size for responsive sizing
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final textScale = MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5);

    // Calculate responsive icon size
    final iconSize = (screenWidth * 0.08 * textScale).clamp(20.0, 48.0);

    return _styledCard(
      color: Colors.blue.shade600,
      border: Colors.blue.shade800,
      child: Icon(
        Icons.help_outline,
        size: iconSize,
        color: Colors.blue.shade100,
      ),
    );
  }

  Widget _styledCard({
    required Widget child,
    required Color color,
    required Color border,
  }) {
    // Get screen size for responsive border radius and border width
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final borderRadius = (screenWidth * 0.03).clamp(8.0, 16.0);
    final borderWidth = (screenWidth * 0.005).clamp(1.5, 3.0);

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Center(child: child),
    );
  }
}

// ------------------------------------------------------------
//                     CARD MODEL
// ------------------------------------------------------------

class CardModel {
  final int id;
  final String symbol;
  bool isFlipped;
  bool isMatched;

  CardModel({
    required this.id,
    required this.symbol,
    required this.isFlipped,
    required this.isMatched,
  });
}

// ------------------------------------------------------------
//                  STORAGE HELPER (Web/Mobile)
// ------------------------------------------------------------

class StorageHelper {
  static SharedPreferences? _prefs;

  static Future<void> _init() async {
    final platform = kIsWeb ? 'Web' : 'Desktop/Mobile';
    print('[STORAGE] Initializing SharedPreferences on $platform...');
    try {
      _prefs = await SharedPreferences.getInstance();
      print(
        '[STORAGE] ✅ SharedPreferences initialized successfully on $platform',
      );
    } catch (e) {
      print(
        '[STORAGE] ❌ Error initializing SharedPreferences on $platform: $e',
      );
      print(
        '[STORAGE] ⚠️  NOTE: If you see MissingPluginException, you need to:',
      );
      print('[STORAGE]    1. STOP the app completely (not just hot restart)');
      print('[STORAGE]    2. Run: flutter clean');
      print('[STORAGE]    3. Run: flutter pub get');
      print('[STORAGE]    4. Start the app from scratch (full restart)');
      rethrow;
    }
  }

  static Future<void> _ensureInit() async {
    if (_prefs == null) await _init();
  }

  static Future<void> setInt(String key, int value) async {
    await _ensureInit();
    await _prefs!.setInt(key, value);
    print('[STORAGE] Set $key = $value');
  }

  static Future<int?> getInt(String key) async {
    await _ensureInit();
    final value = _prefs!.getInt(key);
    print('[STORAGE] Got $key = $value');
    return value;
  }

  static Future<void> setDouble(String key, double value) async {
    await _ensureInit();
    await _prefs!.setDouble(key, value);
    print('[STORAGE] Set $key = $value');
  }

  static Future<double?> getDouble(String key) async {
    await _ensureInit();
    final value = _prefs!.getDouble(key);
    print('[STORAGE] Got $key = $value');
    return value;
  }

  static Future<void> setString(String key, String value) async {
    await _ensureInit();
    await _prefs!.setString(key, value);
    print('[STORAGE] Set $key = $value');
  }

  static Future<String?> getString(String key) async {
    await _ensureInit();
    final value = _prefs!.getString(key);
    print('[STORAGE] Got $key = $value');
    return value;
  }

  static Future<bool> getBool(String key) async {
    await _ensureInit();
    final value = _prefs!.getBool(key) ?? false;
    print('[STORAGE] Got $key = $value');
    return value;
  }

  static Future<void> setBool(String key, bool value) async {
    await _ensureInit();
    await _prefs!.setBool(key, value);
    print('[STORAGE] Set $key = $value');
  }

  static Future<void> remove(String key) async {
    await _ensureInit();
    await _prefs!.remove(key);
    print('[STORAGE] Removed $key');
  }
}

// ------------------------------------------------------------
//                     STATS MANAGER
// ------------------------------------------------------------

class GameStats {
  static const String gamesWonKey = 'games_won';
  static const String totalMovesKey = 'total_moves';
  static const String bestScoreKey = 'best_score';
  static const String bestRatioKey = 'best_ratio';
  static const String usernameKey = 'username';
  static const String isLoggedInKey = 'is_logged_in';

  static Future<void> incrementGamesWon() async {
    try {
      final current = await StorageHelper.getInt(gamesWonKey) ?? 0;
      final newValue = current + 1;
      print('[STATS] Incrementing games won: $current -> $newValue');
      await StorageHelper.setInt(gamesWonKey, newValue);
      print('[STATS] ✅ Games won updated: $newValue');
    } catch (e) {
      print('[STATS] ❌ Error incrementing games won: $e');
    }
  }

  static Future<void> addTotalMoves(int m) async {
    try {
      final current = await StorageHelper.getInt(totalMovesKey) ?? 0;
      final newValue = current + m;
      print('[STATS] Adding total moves: $current + $m = $newValue');
      await StorageHelper.setInt(totalMovesKey, newValue);
      print('[STATS] ✅ Total moves updated: $newValue');
    } catch (e) {
      print('[STATS] ❌ Error adding total moves: $e');
    }
  }

  static Future<void> updateBestScore(int moves) async {
    try {
      final current = await StorageHelper.getInt(bestScoreKey);
      print('[STATS] Current best score: $current, new score: $moves');
      if (current == null || moves < current) {
        await StorageHelper.setInt(bestScoreKey, moves);
        print('[STATS] ✅ Best score updated: $moves');
      } else {
        print('[STATS] Best score not updated (current is better)');
      }
    } catch (e) {
      print('[STATS] ❌ Error updating best score: $e');
    }
  }

  static Future<void> updateBestRatio(int moves, int pairs) async {
    if (moves == 0) {
      print('[STATS] Skipping ratio update (moves = 0)');
      return;
    }
    try {
      final ratio = pairs / moves;
      print('[STATS] Calculating ratio: $pairs / $moves = $ratio');
      final current = await StorageHelper.getDouble(bestRatioKey);
      print('[STATS] Current best ratio: $current, new ratio: $ratio');
      if (current == null || ratio > current) {
        await StorageHelper.setDouble(bestRatioKey, ratio);
        print('[STATS] ✅ Best ratio updated: $ratio');
      } else {
        print('[STATS] Best ratio not updated (current is better)');
      }
    } catch (e) {
      print('[STATS] ❌ Error updating best ratio: $e');
    }
  }

  static Future<int> getGamesWon() async {
    try {
      print('[STATS] Loading games won...');
      final value = await StorageHelper.getInt(gamesWonKey) ?? 0;
      print('[STATS] Games won loaded: $value');
      return value;
    } catch (e) {
      print('[STATS] ❌ Error getting games won: $e');
      return 0;
    }
  }

  static Future<int> getTotalMoves() async {
    try {
      print('[STATS] Loading total moves...');
      final value = await StorageHelper.getInt(totalMovesKey) ?? 0;
      print('[STATS] Total moves loaded: $value');
      return value;
    } catch (e) {
      print('[STATS] ❌ Error getting total moves: $e');
      return 0;
    }
  }

  static Future<int?> getBestScore() async {
    try {
      print('[STATS] Loading best score...');
      final value = await StorageHelper.getInt(bestScoreKey);
      print('[STATS] Best score loaded: $value');
      return value;
    } catch (e) {
      print('[STATS] ❌ Error getting best score: $e');
      return null;
    }
  }

  static Future<double?> getBestRatio() async {
    try {
      print('[STATS] Loading best ratio...');
      final value = await StorageHelper.getDouble(bestRatioKey);
      print('[STATS] Best ratio loaded: $value');
      return value;
    } catch (e) {
      print('[STATS] ❌ Error getting best ratio: $e');
      return null;
    }
  }

  // Username
  static Future<String?> getUsername() async {
    try {
      return await StorageHelper.getString(usernameKey);
    } catch (e) {
      print('[STATS] ❌ Error getting username: $e');
      return null;
    }
  }

  static Future<void> setUsername(String? username) async {
    try {
      if (username == null) {
        await StorageHelper.remove(usernameKey);
      } else {
        await StorageHelper.setString(usernameKey, username);
      }
    } catch (e) {
      print('[STATS] ❌ Error setting username: $e');
    }
  }

  // Login Status
  static Future<bool> isLoggedIn() async {
    try {
      return await StorageHelper.getBool(isLoggedInKey);
    } catch (e) {
      print('[STATS] ❌ Error getting login status: $e');
      return false;
    }
  }

  static Future<void> setLoggedIn(bool value) async {
    try {
      await StorageHelper.setBool(isLoggedInKey, value);
    } catch (e) {
      print('[STATS] ❌ Error setting login status: $e');
    }
  }

  // Clear all data
  static Future<void> clearAllData() async {
    try {
      await StorageHelper.remove(gamesWonKey);
      await StorageHelper.remove(totalMovesKey);
      await StorageHelper.remove(bestScoreKey);
      await StorageHelper.remove(bestRatioKey);
      await StorageHelper.remove(usernameKey);
      await StorageHelper.remove(isLoggedInKey);
      print('[STATS] ✅ All data cleared');
    } catch (e) {
      print('[STATS] ❌ Error clearing data: $e');
    }
  }
}

// ------------------------------------------------------------
//                   PROFILE SCREEN
// ------------------------------------------------------------

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int games = 0;
  int totalMoves = 0;
  int? bestScore;
  double? bestRatio;
  int? avgMoves;
  String? username;
  bool isLoggedIn = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    // Listen to Supabase auth state changes
    final supabase = Supabase.instance.client;
    supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        print('[PROFILE] Auth state changed, reloading...');
        _load();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when page becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    print('[PROFILE] Loading profile data...');
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      // Check Supabase auth first
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        // User is logged in via Supabase
        isLoggedIn = true;

        // Load user data from Supabase (query by email since id is auto-generated bigint)
        try {
          final userData = await supabase
              .from('users')
              .select(
                'name, email, games_completed, best_ratio, total_moves, best_score, avg_moves',
              )
              .eq('email', currentUser.email ?? '')
              .maybeSingle();

          if (userData != null) {
            // Use name from Supabase (username field)
            final nameValue = userData['name']?.toString();
            username = (nameValue != null && nameValue.trim().isNotEmpty)
                ? nameValue.trim()
                : currentUser.email?.split('@').first ?? 'User';

            // Load stats from Supabase (prioritize these)
            if (userData['games_completed'] != null) {
              games = (userData['games_completed'] as num).toInt();
              print('[PROFILE] Games from Supabase: $games');
            }
            if (userData['best_ratio'] != null) {
              bestRatio = (userData['best_ratio'] as num).toDouble();
              print('[PROFILE] Best ratio from Supabase: $bestRatio');
            }
            if (userData['total_moves'] != null) {
              totalMoves = (userData['total_moves'] as num).toInt();
              print('[PROFILE] Total moves from Supabase: $totalMoves');
            }
            if (userData['best_score'] != null) {
              bestScore = (userData['best_score'] as num).toInt();
              print('[PROFILE] Best score from Supabase: $bestScore');
            }
            if (userData['avg_moves'] != null) {
              avgMoves = (userData['avg_moves'] as num).toInt();
              print('[PROFILE] Average moves from Supabase: $avgMoves');
            }
          } else {
            username = currentUser.email?.split('@').first ?? 'User';
            print(
              '[PROFILE] No user data found in Supabase, using email as name',
            );
          }
        } catch (e) {
          print('[PROFILE] Error loading from Supabase: $e');
          username = currentUser.email?.split('@').first ?? 'User';
        }
      } else {
        // Not logged in via Supabase, check local storage
        isLoggedIn = await GameStats.isLoggedIn();
        username = await GameStats.getUsername();
      }

      // Load stats from local storage if not logged in or if Supabase data is missing
      if (currentUser == null) {
        print('[PROFILE] Loading total moves from local...');
        totalMoves = await GameStats.getTotalMoves();
        print('[PROFILE] Loading best score from local...');
        bestScore = await GameStats.getBestScore();
      } else {
        // If logged in but Supabase doesn't have these values, load from local as fallback
        if (totalMoves == 0) {
          final localMoves = await GameStats.getTotalMoves();
          if (localMoves > 0) totalMoves = localMoves;
        }
        if (bestScore == null) {
          bestScore = await GameStats.getBestScore();
        }
      }

      // If not logged in, also load games/ratio from local
      if (currentUser == null) {
        print('[PROFILE] Loading games won from local...');
        final localGames = await GameStats.getGamesWon();
        if (localGames > 0) games = localGames;

        print('[PROFILE] Loading best ratio from local...');
        final localRatio = await GameStats.getBestRatio();
        if (localRatio != null) bestRatio = localRatio;
      }

      print(
        '[PROFILE] ✅ Profile data loaded: games=$games, moves=$totalMoves, score=$bestScore, ratio=$bestRatio, user=$username, loggedIn=$isLoggedIn',
      );
    } catch (e) {
      print('[PROFILE] ❌ Error loading profile stats: $e');
      // Set defaults on error
      games = 0;
      totalMoves = 0;
      bestScore = null;
      bestRatio = null;
      username = null;
      isLoggedIn = false;
    }

    if (mounted) {
      setState(() => isLoading = false);
      print('[PROFILE] ✅ Profile page state updated');
    } else {
      print('[PROFILE] ⚠️ Widget not mounted, skipping setState');
    }
  }

  Future<void> _handleLogin() async {
    // Navigate to full login screen
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );

    // Reload profile data after returning from login screen
    await _load();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Sign out from Supabase
        final supabase = Supabase.instance.client;
        await supabase.auth.signOut();
      } catch (e) {
        print('[PROFILE] Error signing out from Supabase: $e');
      }

      // Clear local storage
      await GameStats.setLoggedIn(false);
      await GameStats.setUsername(null);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            child: Icon(
                              isLoggedIn ? Icons.person : Icons.person_outline,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            username ?? 'Guest User',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (isLoggedIn)
                            Chip(
                              label: const Text('Logged In'),
                              avatar: const Icon(Icons.check_circle, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login/Logout Button
                  if (!isLoggedIn)
                    FilledButton.icon(
                      onPressed: _handleLogin,
                      icon: const Icon(Icons.login),
                      label: const Text('Login / Sign Up'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Stats Section
                  Text(
                    'Game Statistics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildStatCard(
                    icon: Icons.emoji_events,
                    title: 'Games Won',
                    value: games.toString(),
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 12),

                  _buildStatCard(
                    icon: Icons.touch_app,
                    title: 'Total Moves',
                    value: totalMoves.toString(),
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),

                  _buildStatCard(
                    icon: Icons.star,
                    title: 'Best Score',
                    value: bestScore != null ? '$bestScore moves' : 'N/A',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),

                  _buildStatCard(
                    icon: Icons.trending_up,
                    title: 'Best Ratio',
                    value: bestRatio != null
                        ? '${(bestRatio! * 100).toStringAsFixed(1)}%'
                        : 'N/A',
                    color: Colors.orange,
                    subtitle: bestRatio != null
                        ? '${bestRatio!.toStringAsFixed(2)} (pairs/moves)'
                        : null,
                  ),
                  if (games > 0) ...[
                    const SizedBox(height: 12),
                    _buildStatCard(
                      icon: Icons.calculate,
                      title: 'Average Moves',
                      value: avgMoves != null
                          ? avgMoves.toString()
                          : (totalMoves / games).toStringAsFixed(1),
                      color: Colors.purple,
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Data Management
                  Text(
                    'Data Management',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Stats'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple Login Dialog

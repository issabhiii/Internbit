import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'main.dart';

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  late Future<List<Map<String, dynamic>>> _questsFuture;
  List<int> _completedQuestIds = [];

  @override
  void initState() {
    super.initState();
    _questsFuture = _loadQuests();
    _loadCompletedQuests();
  }

  Future<void> _loadCompletedQuests() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null && currentUser.email != null) {
        final userData = await supabase
            .from('users')
            .select('games_complete')
            .eq('email', currentUser.email!)
            .maybeSingle();

        if (userData != null && userData['games_complete'] != null) {
          final gamesComplete = userData['games_complete'];
          if (gamesComplete is List) {
            _completedQuestIds = List<int>.from(
              gamesComplete.map((e) => e is int ? e : (e as num).toInt()),
            );
          } else if (gamesComplete is String) {
            final parsed = jsonDecode(gamesComplete);
            if (parsed is List) {
              _completedQuestIds = List<int>.from(
                parsed.map((e) => e is int ? e : (e as num).toInt()),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[QUEST] Error loading completed quests: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadQuests() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('games')
          .select('id, questions, pairs, gameid, theme, reviewed')
          .eq('theme', 'quest')
          .order('gameid', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[QUEST] Error loading quests: $e');
      return [];
    }
  }

  bool _isQuestUnlocked(int index, List<Map<String, dynamic>> quests) {
    if (index == 0) return true;
    final prevQuest = quests[index - 1];
    final prevGameid = (prevQuest['gameid'] as num?)?.toInt();
    return prevGameid != null && _completedQuestIds.contains(prevGameid);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Quest Adventure'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade400,
                Colors.purple.shade400,
                Colors.blue.shade600,
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    const Color(0xFF1A1A1A),
                    const Color(0xFF2D2D2D),
                    const Color(0xFF1A1A1A),
                  ]
                : [
                    const Color(0xFFFAFAFA),
                    const Color(0xFFF0F0F0),
                    const Color(0xFFFAFAFA),
                  ],
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _questsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withOpacity(0.3),
                            Colors.purple.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Loading quests...",
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            final quests = snapshot.data ?? [];

            if (quests.isEmpty) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'No quests found.',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
              itemCount: quests.length,
              itemBuilder: (context, index) {
                final quest = quests[index];
                final unlocked = _isQuestUnlocked(index, quests);
                final isFirst = index == 0;
                final isLast = index == quests.length - 1;
                final gameid = (quest['gameid'] as num?)?.toInt();
                final isCompleted =
                    gameid != null && _completedQuestIds.contains(gameid);

                return _QuestPillItem(
                  quest: quest,
                  isDarkMode: isDarkMode,
                  unlocked: unlocked,
                  isFirst: isFirst,
                  isLast: isLast,
                  isCompleted: isCompleted,
                  onOpen: () async {
                    if (!unlocked) {
                      HapticFeedback.vibrate();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Complete the previous quest to unlock this one!',
                          ),
                        ),
                      );
                      return;
                    }

                    HapticFeedback.selectionClick();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MemoryGamePage(gameData: quest),
                      ),
                    );

                    // Reload completed quests after returning
                    if (mounted) {
                      await _loadCompletedQuests();
                      setState(() {});
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _QuestPillItem extends StatelessWidget {
  final Map<String, dynamic> quest;
  final bool unlocked;
  final bool isDarkMode;
  final bool isFirst;
  final bool isLast;
  final bool isCompleted;
  final VoidCallback onOpen;

  const _QuestPillItem({
    required this.quest,
    required this.unlocked,
    required this.isDarkMode,
    required this.isFirst,
    required this.isLast,
    required this.isCompleted,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFF6B46C1); // Purple-blue color
    final progress = isCompleted ? 1.0 : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 120,
          child: CustomPaint(
            painter: _TimelinePainter(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.2),
              isFirst: isFirst,
              isLast: isLast,
            ),
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: unlocked
                      ? LinearGradient(
                          colors: [
                            brand,
                            brand.withOpacity(0.8),
                          ],
                        )
                      : LinearGradient(
                          colors: [
                            Colors.grey.shade600,
                            Colors.grey.shade700,
                          ],
                        ),
                  shape: BoxShape.circle,
                  border: unlocked
                      ? Border.all(color: brand.withOpacity(0.5), width: 2)
                      : null,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check
                      : (unlocked ? Icons.play_arrow : Icons.lock),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onOpen,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: unlocked
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDarkMode
                            ? [
                                Colors.white.withOpacity(0.15),
                                Colors.white.withOpacity(0.05),
                              ]
                            : [
                                Colors.white.withOpacity(0.8),
                                Colors.white.withOpacity(0.6),
                              ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDarkMode
                            ? [
                                Colors.grey.withOpacity(0.2),
                                Colors.grey.withOpacity(0.1),
                              ]
                            : [
                                Colors.grey.withOpacity(0.3),
                                Colors.grey.withOpacity(0.2),
                              ],
                      ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: unlocked
                      ? brand.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      quest['questions']?.toString() ?? 'Quest',
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        color: unlocked
                            ? (isDarkMode ? Colors.white : Colors.black87)
                            : (isDarkMode ? Colors.white60 : Colors.grey.shade600),
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        wordSpacing: 2.0,
                      ),
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          unlocked ? brand : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final Color color;
  final bool isFirst;
  final bool isLast;

  _TimelinePainter({
    required this.color,
    required this.isFirst,
    required this.isLast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final double top = isFirst ? size.height / 2 : 0.0;
    final double bottom = isLast ? size.height / 2 : size.height;

    canvas.drawLine(Offset(centerX, top), Offset(centerX, bottom), paint);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast;
  }
}


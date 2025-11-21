import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'theme_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode
        ? const Color(0xFF1C1B1F)
        : const Color(0xFFF5F5F5);
    final tileColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final iconColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Dark Mode Toggle
          _buildDarkModeTile(
            tileColor: tileColor,
            textColor: textColor,
            iconColor: iconColor,
          ),
          // Refresh Stats
          _buildSettingTile(
            label: "Refresh Stats",
            icon: Icons.refresh,
            onTap: () => _refreshStats(context),
            tileColor: tileColor,
            textColor: textColor,
            iconColor: iconColor,
          ),
          // Feedback
          _buildSettingTile(
            label: "Feedback",
            icon: Icons.mail,
            onTap: () => _showFeedbackDialog(context),
            tileColor: tileColor,
            textColor: textColor,
            iconColor: iconColor,
          ),
          _buildSettingTile(
            label: "Privacy Policy",
            icon: Icons.shield,
            onTap: () => _showPrivacyPolicy(context),
            tileColor: tileColor,
            textColor: textColor,
            iconColor: iconColor,
          ),
          _buildSettingTile(
            label: "Terms of Service",
            icon: Icons.description,
            onTap: () => _showTermsAndConditions(context),
            tileColor: tileColor,
            textColor: textColor,
            iconColor: iconColor,
          ),
          const SizedBox(height: 16),
          _buildSettingTile(
            label: "Log out",
            icon: Icons.logout,
            onTap: () => _logout(context),
            danger: true,
            tileColor: tileColor,
            textColor: textColor,
            iconColor: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildDarkModeTile({
    required Color tileColor,
    required Color textColor,
    required Color iconColor,
  }) {
    final isDarkMode = ThemeManager.isDarkMode;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tileColor,
            Color.lerp(tileColor, Colors.white.withOpacity(0.06), 0.2) ??
                tileColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: -6,
            offset: Offset(0, 6),
            color: Colors.black26,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: iconColor,
          size: 24,
        ),
        title: Text(
          "Dark Mode",
          style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
        ),
        trailing: Switch(
          value: isDarkMode,
          onChanged: (value) {
            ThemeManager.toggleTheme(value);
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color tileColor,
    required Color textColor,
    required Color iconColor,
    bool danger = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tileColor,
            Color.lerp(tileColor, Colors.white.withOpacity(0.06), 0.2) ??
                tileColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: -6,
            offset: Offset(0, 6),
            color: Colors.black26,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: iconColor, size: 24),
        title: Text(
          label,
          style: TextStyle(
            color: danger ? Colors.redAccent : textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: textColor.withOpacity(0.5)),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showSuccessOverlay(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: Curves.elasticOut.transform(value),
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.check, color: Colors.green, size: 84),
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1200));
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _logout(BuildContext context) async {
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
        await supabase.auth.signOut();
        await _showSuccessOverlay(context);
        if (context.mounted) {
          Navigator.of(context).pop(); // Return to previous screen
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
        }
      }
    }
  }

  void _refreshStats(BuildContext context) async {
    // Navigate back and show message
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Stats will refresh when you return to Profile page."),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Feedback"),
        content: const Text(
          "We'd love to hear from you. Send feedback to abhinav.jain.0461@gmail.com",
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: "abhinav.jain.0461@gmail.com"),
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Email copied to clipboard")),
                );
              }
            },
            child: const Text("Copy email"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showTermsAndConditions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode
        ? const Color(0xFF1C1B1F)
        : const Color(0xFFF5F5F5);
    final textColor = isDarkMode ? Colors.white : Colors.black;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text(
              'Terms & Conditions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last updated: 2025-10-19',
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  '1. Acceptance of Terms',
                  'By accessing or using our services, you agree to these Terms. If you do not agree, please do not use the service.',
                  textColor,
                ),
                const SizedBox(height: 20),
                _buildSection(
                  '2. Eligibility',
                  'You must be at least 13 years old to use the service. If you are under the age of majority in your jurisdiction, you must have your parent/guardian\'s permission.',
                  textColor,
                ),
                const SizedBox(height: 20),
                _buildSection(
                  '3. Accounts',
                  'You are responsible for maintaining the security of your account and password.\n\nDo not share your account or use someone else\'s account without permission.\n\nProvide accurate and up-to-date information.',
                  textColor,
                ),
                const SizedBox(height: 20),
                _buildSection(
                  '4. Acceptable Use',
                  'Use the service for lawful purposes only.\n\nDon\'t attempt to disrupt or reverse engineer the service.\n\nRespect other users; no harassment, hate speech, or abusive content.',
                  textColor,
                ),
                const SizedBox(height: 20),
                _buildSection(
                  '5. Content and Intellectual Property',
                  'All content (including lessons, graphics, and branding) is protected by intellectual property laws.\n\nYou may not copy, distribute, or create derivative works without permission.',
                  textColor,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If you have questions, please contact Support from within the app or via our website.',
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'support@bhashagroup.com',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Back to Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode
        ? const Color(0xFF1C1B1F)
        : const Color(0xFFF5F5F5);
    final textColor = isDarkMode ? Colors.white : Colors.black;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text(
              'Privacy Policy',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last updated: 2025-10-19',
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'We value your privacy. This policy explains what information we collect, how we use it, and the choices you have.',
                  style: TextStyle(
                    color: textColor.withOpacity(0.8),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  'Information We Collect',
                  'Account info: name, email, avatar (if you sign in with Google).\n\nUsage data: device type, interactions, pages visited, approximate location (based on IP) to improve the experience.\n\nCookies: small files to keep you signed in, remember preferences, and measure performance.',
                  textColor,
                ),
                const SizedBox(height: 20),
                _buildSection(
                  'How We Use Information',
                  'Provide and personalize the learning experience.\n\nMaintain account security and prevent abuse.\n\nAnalyze performance and improve features.\n\nSend service updates, tips, and announcements (you can opt out of non-essential emails).',
                  textColor,
                ),
                const SizedBox(height: 20),
                _buildSection(
                  'Data Sharing',
                  'We do not sell your personal data. We may share limited information with trusted providers (e.g., authentication, analytics, hosting) to operate the service.',
                  textColor,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Questions or requests? Contact Support from within the app or via our website.',
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'support@bhashagroup.com',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Back to Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            color: textColor.withOpacity(0.8),
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

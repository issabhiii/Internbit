import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginScreen extends StatefulWidget {
  final String? preFilledName;
  final String? preFilledEmail;

  const LoginScreen({super.key, this.preFilledName, this.preFilledEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoginMode = true;
  bool _loading = false;
  bool _agreedToTerms = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController = TextEditingController();
  final ValueNotifier<Set<String>> _unmetCriteria = ValueNotifier({});
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);

    // Pre-fill data if provided (from Google sign-in)
    if (widget.preFilledName != null) {
      _nameController.text = widget.preFilledName!;
      isLoginMode = false;
    }
    if (widget.preFilledEmail != null) {
      _emailController.text = widget.preFilledEmail!;
      isLoginMode = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _validatePassword() {
    final password = _passwordController.text;
    final unmet = <String>{};
    if (password.length < 8) unmet.add('minimum 8 characters');
    if (!RegExp(r'[A-Z]').hasMatch(password)) unmet.add('1 uppercase letter');
    if (!RegExp(r'[a-z]').hasMatch(password)) unmet.add('1 lowercase letter');
    if (!RegExp(r'\d').hasMatch(password)) unmet.add('1 number');
    if (!RegExp(r'[!@#\$&*~%^(),.?":{}|<>]').hasMatch(password)) {
      unmet.add('1 special character');
    }
    _unmetCriteria.value = unmet;
  }

  Future<void> _signUp() async {
    final supabase = Supabase.instance.client;
    if (_loading) return;
    setState(() => _loading = true);

    // Validate username (for sign-up)
    if (!isLoginMode && _nameController.text.trim().isEmpty) {
      _showError("Please enter a username.");
      setState(() => _loading = false);
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError("Please enter an email address.");
      setState(() => _loading = false);
      return;
    }
    
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showError("Please enter a valid email address.");
      setState(() => _loading = false);
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showError("Please enter a password.");
      setState(() => _loading = false);
      return;
    }

    if (!isLoginMode && _passwordController.text != _repeatPasswordController.text) {
      _showError("Passwords do not match");
      setState(() => _loading = false);
      return;
    }

    if (!isLoginMode && _unmetCriteria.value.isNotEmpty) {
      _showError("Password does not meet requirements");
      setState(() => _loading = false);
      return;
    }

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null && currentUser.email == email) {
        // User already authenticated with Google - create/update user record
        try {
          // Check if user exists by email (since we can't use auth UUID as bigint id)
          final existingUser = await supabase
              .from('users')
              .select('id, email')
              .eq('email', email)
              .maybeSingle();

          if (existingUser == null) {
            // Insert new user - let id auto-generate
            await supabase.from('users').insert({
              'name': _nameController.text.trim().isEmpty 
                  ? email.split('@').first 
                  : _nameController.text.trim(),
              'email': email,
              'games_completed': 0,
              'best_ratio': null,
            });
            debugPrint('✅ [Sign-Up] New user record created (Google auth)');
          } else {
            // Update existing user by email
            await supabase.from('users').update({
              'name': _nameController.text.trim().isEmpty 
                  ? email.split('@').first 
                  : _nameController.text.trim(),
            }).eq('email', email);
            debugPrint('✅ [Sign-Up] Existing user record updated (Google auth)');
          }
        } catch (dbError) {
          debugPrint('❌ [Sign-Up] Database error (Google auth): $dbError');
          final errorMsg = dbError.toString();
          if (errorMsg.contains("duplicate key") || 
              errorMsg.contains("unique constraint") ||
              errorMsg.contains("already exists")) {
            debugPrint('⚠️ [Sign-Up] User already exists, continuing...');
          } else {
            // Re-throw to be caught by outer catch
            throw Exception("Database error: $errorMsg");
          }
        }

        try {
          await supabase.auth.updateUser(
            UserAttributes(password: _passwordController.text.trim()),
          );
        } catch (e) {
          debugPrint('⚠️ Could not set password: $e');
        }
      } else {
        // Normal sign-up flow
        try {
          final response = await supabase.auth.signUp(
            email: email,
            password: _passwordController.text.trim(),
          );
          final user = response.user;
          if (user == null) {
            _showError("Signup failed. Try again.");
            setState(() => _loading = false);
            return;
          }

          // Insert into users table - let id auto-generate (don't insert user.id UUID)
          try {
            await supabase.from('users').insert({
              // Don't insert 'id' - let it auto-generate as bigint
              'name': _nameController.text.trim().isEmpty 
                  ? email.split('@').first 
                  : _nameController.text.trim(),
              'email': email,
              'games_completed': 0,
              'best_ratio': null,
            });
            debugPrint('✅ [Sign-Up] User record created in database');
          } catch (dbError) {
            debugPrint('❌ [Sign-Up] Database error: $dbError');
            // If insert fails, try to continue anyway (user is already authenticated)
            final errorMsg = dbError.toString();
            if (errorMsg.contains("duplicate key") || 
                errorMsg.contains("already exists") ||
                errorMsg.contains("unique constraint")) {
              debugPrint('⚠️ [Sign-Up] User record already exists, continuing...');
            } else {
              rethrow;
            }
          }
        } catch (e) {
          final errorMsg = e.toString();
          debugPrint('❌ [Sign-Up] Auth error: $e');
          if (errorMsg.contains("user_already_exists") ||
              errorMsg.contains("already registered")) {
            _showError("This email is already registered. Please sign in instead.");
            setState(() => _loading = false);
            return;
          }
          rethrow;
        }
      }

      _showMessage("Signup successful! 🎉");
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      final errorMsg = e.toString();
      debugPrint('❌ [Sign-Up] Error: $e');
      debugPrint('❌ [Sign-Up] Error message: $errorMsg');
      
      if (errorMsg.contains("user_already_exists") ||
          errorMsg.contains("already registered") ||
          errorMsg.contains("User already registered")) {
        _showError("That email is already registered. Please sign in instead.");
      } else if (errorMsg.contains("password") || 
                 errorMsg.contains("Password") ||
                 errorMsg.contains("password is too weak")) {
        _showError("Your password is too weak. Please follow the requirements above.");
      } else if (errorMsg.contains("Invalid API key") || 
                 errorMsg.contains("JWT") ||
                 errorMsg.contains("configuration") ||
                 errorMsg.contains("YOUR_SUPABASE")) {
        _showError("Configuration error: Please check your Supabase credentials in main.dart");
      } else if (errorMsg.contains("relation") && errorMsg.contains("does not exist")) {
        _showError("Database error: The 'users' table doesn't exist. Please create it in Supabase.");
      } else if (errorMsg.contains("Failed host lookup") || 
                 errorMsg.contains("network") ||
                 errorMsg.contains("SocketException") ||
                 errorMsg.contains("Connection")) {
        _showError("No internet connection. Please check your network and try again.");
      } else if (errorMsg.contains("timeout") || errorMsg.contains("Timeout")) {
        _showError("Request timed out. Please try again.");
      } else if (errorMsg.contains("email") && errorMsg.contains("invalid")) {
        _showError("Please enter a valid email address.");
      } else if (errorMsg.contains("PostgrestException") || 
                 errorMsg.contains("database") ||
                 errorMsg.contains("22P02")) {
        _showError("Database error. Please check your database configuration.");
      } else {
        // Show a more helpful error message
        final cleanError = errorMsg
            .replaceAll('Exception: ', '')
            .replaceAll('PostgrestException: ', '')
            .replaceAll('AuthException: ', '');
        final displayError = cleanError.length > 120 
            ? cleanError.substring(0, 120) + '...' 
            : cleanError;
        _showError("Error: $displayError");
        debugPrint('[SIGN-UP] Full error details: $errorMsg');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _login() async {
    final supabase = Supabase.instance.client;
    if (_loading) return;
    
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    // Validate inputs
    if (email.isEmpty) {
      _showError("Please enter your email address.");
      return;
    }
    
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showError("Please enter a valid email address.");
      return;
    }
    
    if (password.isEmpty) {
      _showError("Please enter your password.");
      return;
    }
    
    setState(() => _loading = true);
    try {
      debugPrint('[LOGIN] Attempting to sign in with email: $email');
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        _showError("Invalid email or password. Please try again.");
        setState(() => _loading = false);
        return;
      }

      debugPrint('[LOGIN] ✅ Login successful for user: ${response.user!.email}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMessage("Welcome back!");
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      debugPrint('[LOGIN] ❌ Login error: $e');
      _handleAuthError(e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? Uri.base.toString()
            : 'com.intershala.memorygame://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
        scopes: 'email profile',
      );

      debugPrint('🔵 [Google Sign-In] OAuth flow initiated');

      await Future.delayed(const Duration(milliseconds: 1500));

      for (int i = 0; i < 20; i++) {
        if (!mounted) break;

        final session = supabase.auth.currentSession;
        if (session != null) {
          final user = session.user;
          debugPrint('✅ [Google Sign-In] Session found for user: ${user.email}');

          try {
            // Check if user exists by email (since id is auto-generated bigint)
            final userRecord = await supabase
                .from('users')
                .select('id, email')
                .eq('email', user.email ?? '')
                .maybeSingle();

            if (userRecord == null) {
              debugPrint('🆕 [Google Sign-In] New user detected');

              String? userName = user.userMetadata?['full_name'] ??
                  user.userMetadata?['name'] ??
                  user.userMetadata?['display_name'];

              final userEmail = user.email ?? '';

              if (mounted) {
                setState(() => _loading = false);
                _showMessage("Please complete your sign-up");
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      preFilledName: userName,
                      preFilledEmail: userEmail,
                    ),
                  ),
                );
              }
              return;
            }
          } catch (e) {
            debugPrint('❌ [Google Sign-In] Error: $e');
          }

          if (mounted) {
            setState(() => _loading = false);
            _showMessage("Welcome! Signed in with Google");
            Navigator.of(context).pop();
          }
          return;
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted) {
        setState(() => _loading = false);
        _showError("Sign-in timed out. Please try again.");
      }
    } catch (e) {
      debugPrint('❌ [Google Sign-In] Error: $e');
      final errorMsg = e.toString();
      if (mounted) {
        setState(() => _loading = false);
        
        if (errorMsg.contains("cancelled") || errorMsg.contains("canceled")) {
          _showError("Google sign-in was cancelled.");
        } else if (errorMsg.contains("network") || errorMsg.contains("Connection")) {
          _showError("No internet connection. Please check your network.");
        } else if (errorMsg.contains("timeout")) {
          _showError("Sign-in timed out. Please try again.");
        } else if (errorMsg.contains("configuration") || errorMsg.contains("redirect")) {
          _showError("Google sign-in configuration error. Please check your Supabase settings.");
        } else {
          _showError("Error signing in with Google. Please try again.");
        }
      }
    }
  }

  void _handleAuthError(dynamic error) {
    final message = error.toString();
    debugPrint('[AUTH] Handling error: $message');
    
    if (message.contains("Invalid login credentials") ||
        message.contains("Invalid credentials") ||
        message.contains("email or password") ||
        message.contains("wrong password")) {
      _showError("Incorrect email or password. Please check your credentials and try again.");
    } else if (message.contains("already registered") ||
               message.contains("user_already_exists") ||
               message.contains("User already registered")) {
      _showError("That email is already registered. Please sign in instead.");
    } else if (message.contains("Failed host lookup") ||
               message.contains("network") ||
               message.contains("SocketException") ||
               message.contains("Connection")) {
      _showError("No internet connection. Please check your network and try again.");
    } else if (message.contains("Invalid API key") ||
               message.contains("JWT") ||
               message.contains("configuration")) {
      _showError("Configuration error. Please check your Supabase credentials.");
    } else if (message.contains("relation") && message.contains("does not exist")) {
      _showError("Database error: The 'users' table doesn't exist. Please create it in Supabase.");
    } else if (message.contains("timeout") || message.contains("Timeout")) {
      _showError("Request timed out. Please try again.");
    } else if (message.contains("password") && message.contains("weak")) {
      _showError("Password is too weak. Please use a stronger password.");
    } else if (message.contains("email") && message.contains("invalid")) {
      _showError("Please enter a valid email address.");
    } else {
      // Show a more helpful error message
      final errorText = message.length > 150 
          ? message.substring(0, 150) + '...' 
          : message;
      _showError("Error: $errorText");
      debugPrint('[AUTH] Unhandled error type: $message');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color bgStart = const Color.fromARGB(255, 100, 181, 246);
    final Color bgEnd = const Color.fromARGB(255, 33, 150, 243);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgStart, bgEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(
              Icons.memory,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            const Text(
              'MEMORY PUZZLE',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => isLoginMode = true),
                    style: _buttonStyle(isLoginMode),
                    child: const Text("Login"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => isLoginMode = false),
                    style: _buttonStyle(!isLoginMode),
                    child: const Text("Sign Up"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (!isLoginMode)
                        _buildTextField(Icons.person, "Username",
                            controller: _nameController),
                      _buildTextField(Icons.email, "Email",
                          controller: _emailController),
                      _buildTextField(Icons.lock, "Password",
                          isObscure: true, controller: _passwordController),
                      if (!isLoginMode)
                        ValueListenableBuilder<Set<String>>(
                          valueListenable: _unmetCriteria,
                          builder: (context, unmet, _) {
                            if (unmet.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: unmet
                                    .map((c) => Text(
                                          '• Must include $c',
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 14),
                                        ))
                                    .toList(),
                              ),
                            );
                          },
                        ),
                      if (!isLoginMode)
                        _buildTextField(Icons.lock_outline, "Repeat Password",
                            isObscure: true,
                            controller: _repeatPasswordController),
                      if (!isLoginMode) ...[
                        const SizedBox(height: 16),
                        _buildTermsCheckbox(),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loading ||
                                (!isLoginMode && !_agreedToTerms)
                            ? null
                            : () async {
                                if (isLoginMode) {
                                  await _login();
                                } else {
                                  await _signUp();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 32),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                isLoginMode ? "Login" : "Sign Up",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                              child: Divider(color: Colors.white.withOpacity(0.5))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "OR",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                              child: Divider(color: Colors.white.withOpacity(0.5))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _signInWithGoogle,
                        icon: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                        label: const Text(
                          "Sign in with Google",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          "← Back",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(bool isActive) {
    return ElevatedButton.styleFrom(
      backgroundColor: isActive ? Colors.white : Colors.blue.shade200,
      foregroundColor: isActive ? Colors.blue : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  Widget _buildTextField(IconData icon, String hint,
      {bool isObscure = false,
      TextEditingController? controller,
      String? errorText}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white),
          hintText: hint,
          errorText: errorText,
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _agreedToTerms,
          onChanged: (value) {
            setState(() {
              _agreedToTerms = value ?? false;
            });
          },
          activeColor: Colors.white,
          checkColor: Colors.blue,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: const TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _showTermsOfService(context),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _showPrivacyPolicy(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
          child: Column(
            children: [
              AppBar(
                title: const Text('Terms & Conditions',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildTermsContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
          child: Column(
            children: [
              AppBar(
                title: const Text('Privacy Policy',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildPrivacyContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last updated: ${DateTime.now().toString().split(' ')[0]}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 24),
        _buildSection('1. Acceptance of Terms',
            'By using Memory Puzzle Game, you agree to these Terms.'),
        const SizedBox(height: 20),
        _buildSection('2. Game Rules',
            'Play fairly. Do not use cheats or exploits.'),
        const SizedBox(height: 20),
        _buildSection('3. Accounts',
            'You are responsible for maintaining account security.'),
        const SizedBox(height: 20),
        _buildSection('4. Data',
            'Your game statistics are stored securely.'),
      ],
    );
  }

  Widget _buildPrivacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last updated: ${DateTime.now().toString().split(' ')[0]}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 24),
        _buildSection('Information We Collect',
            'Account info: name, email. Game statistics: games completed, best ratio.'),
        const SizedBox(height: 20),
        _buildSection('How We Use Information',
            'To provide and improve the game experience.'),
        const SizedBox(height: 20),
        _buildSection('Data Security',
            'We use industry-standard security measures to protect your data.'),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 8),
        Text(content,
            style: TextStyle(color: Colors.grey[700], fontSize: 15, height: 1.5)),
      ],
    );
  }
}


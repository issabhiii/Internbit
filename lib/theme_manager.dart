// Theme manager to avoid circular dependencies
class ThemeManager {
  static Function(bool)? _onThemeChanged;
  static bool _isDarkMode = true; // Default to dark mode

  static void setCallback(Function(bool) callback) {
    _onThemeChanged = callback;
  }

  static void setDarkMode(bool value) {
    _isDarkMode = value;
  }

  static void toggleTheme(bool value) {
    _isDarkMode = value;
    _onThemeChanged?.call(value);
  }

  static bool get isDarkMode => _isDarkMode;
}

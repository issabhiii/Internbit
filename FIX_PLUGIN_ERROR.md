# Fix MissingPluginException for shared_preferences

## Steps to Fix:

1. **Stop the app completely** (not just hot reload)
   - Press `Ctrl+C` in the terminal or stop the debug session

2. **Clean the build** (optional but recommended):
   ```bash
   flutter clean
   ```

3. **Get dependencies again**:
   ```bash
   flutter pub get
   ```

4. **Do a FULL RESTART** (not hot reload):
   - Stop the app completely
   - Run `flutter run` again
   - OR use "Restart" button (not "Hot Reload") in your IDE

## Why this happens:
When you add a new plugin like `shared_preferences`, Flutter needs to:
- Link the native code
- Register the plugin channels
- Rebuild the app

Hot reload doesn't do this - you need a full restart!

## Alternative Quick Fix:
If you're using VS Code or Android Studio:
- Press `Ctrl+Shift+F5` (VS Code) or `Shift+F10` (Android Studio) for full restart
- This is different from hot reload (`Ctrl+F5` or `Ctrl+\`)


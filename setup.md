## Quick Setup Instructions

### 1. Install Flutter

**Windows:**
1. Download Flutter SDK from: https://flutter.dev/docs/get-started/install/windows
2. Extract to `C:\flutter`
3. Add `C:\flutter\bin` to your PATH environment variable
4. Run `flutter doctor` to check installation

**macOS:**
1. Download Flutter SDK from: https://flutter.dev/docs/get-started/install/macos
2. Extract to your home directory
3. Add Flutter to your PATH in `~/.zshrc` or `~/.bash_profile`
4. Run `flutter doctor` to check installation

**Linux:**
1. Download Flutter SDK from: https://flutter.dev/docs/get-started/install/linux
2. Extract to your home directory
3. Add Flutter to your PATH in `~/.bashrc`
4. Run `flutter doctor` to check installation

### 2. Install Dependencies

```bash
# Navigate to project directory
cd herbascan

# Install Flutter dependencies
flutter pub get

# Check for any issues
flutter doctor
```

### 3. Run the App

```bash
# For Android
flutter run

# For iOS (macOS only)
flutter run -d ios

# For Web
flutter run -d web
```

## Development Setup

### Android Studio Setup
1. Install Android Studio
2. Install Android SDK (API level 21 or higher)
3. Create an Android Virtual Device (AVD)
4. Enable USB Debugging on your physical device

### VS Code Setup
1. Install VS Code
2. Install Flutter and Dart extensions
3. Open the project folder in VS Code
4. Use `Ctrl+Shift+P` and run "Flutter: Select Device"

## Troubleshooting

### Common Issues

**Flutter not found:**
- Make sure Flutter is added to your PATH
- Restart your terminal/command prompt
- Run `flutter doctor` to verify installation

**Android SDK not found:**
- Install Android Studio
- Run `flutter doctor --android-licenses`
- Accept all licenses

**Device not detected:**
- Enable USB Debugging on Android device
- Install device drivers
- Run `flutter devices` to list available devices

**Dependencies not installing:**
- Check internet connection
- Run `flutter clean` then `flutter pub get`
- Check `pubspec.yaml` for syntax errors
- Verify Flutter and Dart versions compatibility

**Build errors:**
- Check Flutter and Dart versions
- Update dependencies if needed
- Run `flutter doctor` to identify issues
- Check for version conflicts in pubspec.yaml

**Camera permissions:**
- Add camera permissions to AndroidManifest.xml
- Test on real device (camera doesn't work in emulator)
- Check device camera permissions in settings

**Database errors:**
- Check SQLite database initialization
- Verify database schema creation
- Check file permissions for database storage

### Getting Help

1. Check Flutter documentation: https://flutter.dev/docs
2. Check the project's README.md for specific instructions

## Next Steps

After successful setup:

1. **Test the app**: Run `flutter run` and test all functionality
2. **Test AI Features**: 
   - Test plant identification with camera and gallery
   - Verify GradCAM visualization and overlay controls
   - Check confidence scores and predictions
3. **Test Offline Mode**: Toggle offline mode in settings and verify functionality
4. **Test Multi-language**: Switch between English and Filipino
5. **Deploy**: Build APK with `flutter build apk` for release

**Current Features Ready for Testing**:
- ✅ Plant identification (camera + gallery)
- ✅ GradCAM visualization with working overlay controls
- ✅ Offline processing capabilities
- ✅ Multi-language support (English/Filipino)
- ✅ Scan history with metadata
- ✅ Settings and preferences
- ✅ Responsive UI with fixed overflow issues

## Project Structure Overview

```
herbascan/
├── lib/                   # Dart source code
│   ├── core/              # Core functionality
│   │   ├── models/        # Data models
│   │   ├── providers/     # State management
│   │   ├── services/      # Business logic
│   │   ├── theme/         # App styling
│   │   └── localization/  # Multi-language
│   └── features/          # Feature modules
│       ├── splash/        # App launch
│       ├── home/          # Main dashboard
│       ├── scan/          # Camera scanning
│       └── ...
├── assets/                # Static assets
│   ├── images/            # Plant images and app icons
│   ├── models/            # AI model files (.tflite)
│   ├── data/              # JSON data files (doh_plants.json)
│   ├── fonts/             # Custom fonts (Inter)
│   └── icons/             # App icons and UI elements
├── android/               # Android-specific code
├── ios/                   # iOS-specific code
└── pubspec.yaml           # Dependencies
```

## AI Model Integration

The app includes pre-trained models:
1. **MobileNet V2 Feature Extractor**: `mobilenetv2_feature_extractor.tflite`
2. **Random Forest Classifier**: `random_forest_distilled.tflite`
3. **Class Labels**: `labels.json` and `labels.txt`

**Model Files Location**: `assets/models/`

## Database Setup

The app uses SQLite for local storage. The database is created automatically on first run with the following tables:

- `plants` - Plant information (DOH-approved medicinal plants)
- `medicinal_uses` - Medicinal applications and therapeutic uses
- `preparation_methods` - Preparation instructions and dosage guidelines
- `scan_history` - User scan results with GradCAM paths and metadata
- `plant_details` - Detailed plant characteristics and taxonomy


## Development Tips

### Hot Reload & Debugging
- Use `r` in terminal for hot reload during development
- Use `R` in terminal for hot restart
- Use `flutter run --debug` for debugging
- Use `flutter run --release` for performance testing
- Use `flutter devices` to see available devices

### Performance Tips
- Use `flutter run --release` for better performance
- Enable R8/ProGuard for smaller APK size
- Optimize images in `assets/images/`
- Use `flutter build apk --split-per-abi` for smaller APKs
- Monitor memory usage with Flutter Inspector

### Code Quality
- Run `flutter analyze` to check for issues
- Use `flutter test` to run unit tests
- Follow Dart/Flutter style guidelines
- Use proper error handling throughout the app

---

**Need help?** Check the main README.md, PROJECT_STATUS.md, or contact the development team.

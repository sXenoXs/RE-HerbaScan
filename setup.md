## Quick Setup Instructions

**Last Updated**: February 2026 · **App Version**: v0.8.8

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

**Current Features Ready for Testing** (v0.8.8 – February 2026):
- ✅ Plant identification (camera + gallery)
- ✅ GradCAM visualization with working overlay controls
- ✅ XAI explanations from cache/offline/fallback only (no live LLM)
- ✅ Contraindication Engine (safety_profiles.json) and structured safety
- ✅ Offline processing and offline CAM heatmap generation
- ✅ Multi-language support (English/Filipino)
- ✅ Scan history with Device/Cloud tabs, swipe, pull-to-refresh
- ✅ Accounts: signup with 6-digit confirmation, change password/email, delete account
- ✅ Interactive preparation guide with timers, Focus Mode, calendar add
- ✅ Settings and preferences; offline management
- ✅ Backend API for Grad-CAM (Railway); Postman collection

**Recent Features (v0.8.8)**:
- ✅ Signup 6-digit email confirmation; stronger password rules; delete account
- ✅ Interactive preparation checklist, contextual timers, Focus Mode, calendar
- ✅ Contraindication Engine; no live LLM (thesis-defensible)
- ✅ Scan History: swipe between tabs, pull-to-refresh on Cloud, offline-aware
- ✅ Friendly auth errors; 6-digit OTP password reset; auth deep links

**Recent Fixes (v0.8.8)**:
- ✅ Summary tab content and layout; taxonomy Markdown line breaks
- ✅ Railway /identify 401 when not logged in (optional JWT)
- ✅ Calendar add-event on Android (queries intent); Focus Mode contrast
- ✅ Offline/management settings copy and refresh behavior

**Backend API Testing**:
- See `backend/README.md` → "🧪 Testing with Postman" for complete testing guide
- Postman collection: `backend/HerbaScan_API.postman_collection.json`
- Supports: Postman desktop, VS Code (REST Client, Thunder Client), curl

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

### Backend Setup (Python FastAPI)

HerbaScan includes a Python backend API for true Grad-CAM computation:

**Location**: `backend/` directory

#### Prerequisites
- Python 3.8+ installed
- Virtual environment (recommended)
- Model files: `backend/models/mobilenetv2_rf.h5` and `backend/models/labels.json`
- Railway account (for deployment) - Optional but recommended

#### Setup Steps

1. **Navigate to backend directory**:
   ```bash
   cd backend
   ```

2. **Create virtual environment**:
   ```bash
   # Windows
   python -m venv venv
   venv\Scripts\activate
   
   # Mac/Linux
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Place model files**:
   - Copy `mobilenetv2_rf.h5` to `backend/models/`
   - Copy `labels.json` to `backend/models/`

5. **Run locally**:
   ```bash
   python main.py
   # Or
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

6. **Test API**:
   ```bash
   curl http://localhost:8000/health
   ```

#### Backend Documentation

For detailed backend setup, see:
- **`backend/README.md`** - Complete backend documentation
- **`backend/QUICK_START.md`** - Quick deployment guide
- **Model Management**: `backend/README.md` → "🔄 Updating Models"
- **Deployment**: `backend/README.md` → "🚀 Deployment to Railway"
- **Phase 2**: `backend/README.md` → "Phase 2: Model Extraction & Conversion"
- **Testing**: `backend/README.md` → "🧪 Testing with Postman"

#### Phase 2: Model Extraction (For Flutter Assets)

After setting up the backend, extract CAM weights and create multi-output TFLite model:

```bash
cd backend

# Extract CAM weights
python extract_cam_weights.py

# Create multi-output TFLite model
python create_multi_output_tflite.py

# Copy to Flutter assets
cp models/cam_weights.json ../assets/models/
cp models/mobilenetv2_multi_output.tflite ../assets/models/
```

**For detailed instructions, see `backend/README.md` → "Phase 2: Model Extraction & Conversion"**

## Database Setup

The app uses SQLite for local storage. The database is created automatically on first run with the following tables:

- `plants` - Plant information (42 medicinal plants: 10 DOH-approved + 32 additional)
- `medicinal_uses` - Medicinal applications and therapeutic uses
- `preparation_methods` - Preparation instructions and dosage guidelines
- `scan_history` - User scan results with GradCAM paths and metadata

**Plant Database**: The app automatically initializes with 42 plants on first launch (10 DOH-approved + 32 additional). See main README for full list.

## XAI Explanation System Setup

### Offline Explanations
- **Location**: `assets/data/plant_explanations.json`, `assets/data/safety_profiles.json`
- **Content**: Pre-written explanations and safety profiles for all 42 plants
- **Format**: JSON with taxonomy, ecology, medicinal uses, safety; structured safety profiles
- **Status**: ✅ Automatically included in app assets

### Online Explanations (No Live LLM in v0.8.8)
- **Behavior**: As of v0.8.8, the app does **not** use live generative AI at runtime. Explanations come only from: SharedPreferences/file cache (read-only), offline `plant_explanations.json`, and fallback text. Safety is fully deterministic via the Contraindication Engine (`safety_profiles.json`).
- **Offline data**: `assets/data/plant_explanations.json` and `assets/data/safety_profiles.json`.
- **Fallback**: If no cached or offline explanation is found, a fallback message is shown.

### Explanation Features
- **Markdown Formatting**: Rich text with bold, italic, headers, lists
- **Usability Assessment**: Clear status (USABLE/USE WITH CAUTION/NOT RECOMMENDED)
- **Heatmap Integration**: Explanations reference GradCAM/CAM patterns
- **Refresh Functionality**: Regenerate both heatmap and explanation


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

## Key Configuration Files

### API Configuration
- **Backend (GradCAM)**: `lib/core/services/online_gradcam_service.dart` – set base URL to your Railway deployment. Optional JWT: see `supabase/README.md` and `backend/README.md`.
- **No live LLM in v0.8.8**: Explanations use cache/offline JSON and fallback only.

### Backend API URL
- **Location**: `lib/core/services/online_gradcam_service.dart`
- **Default**: Set to your Railway deployment URL
- **Format**: `https://YOUR-APP.up.railway.app`

### Offline Explanation Data
- **Location**: `assets/data/plant_explanations.json`
- **Update**: Edit JSON file and rebuild app
- **Format**: See existing entries for structure

## Troubleshooting

### XAI Explanation Issues

**Offline explanations not showing:**
- Check `assets/data/plant_explanations.json` exists
- Verify JSON format is valid
- Check `pubspec.yaml` includes `assets/data/` in assets list

**Online GradCAM not working:**
- Check backend URL in `online_gradcam_service.dart` and network connectivity
- If using JWT on Railway, see `supabase/README.md` (optional JWT); unset `SUPABASE_JWT_SECRET` to allow unauthenticated /identify

**Markdown not rendering:**
- Verify `flutter_markdown: ^0.6.18` in `pubspec.yaml`
- Run `flutter pub get`
- Check for markdown syntax errors in explanation text



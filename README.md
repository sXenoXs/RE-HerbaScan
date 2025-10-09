# HerbaScan - AI-Powered Plant Identification App

HerbaScan is a Flutter-based mobile application that uses Convolutional Neural Networks (CNN) and Random Forest algorithms to identify Philippine medicinal plants. The app provides comprehensive information about DOH-approved herbal medicines and supports offline processing for rural areas.

## 🚀 Current Development Status

**Last Updated**: September 10, 2025
**Project Phase**: Phase 2 incomplete (GradCAM had Minor issues)  
**Overall Progress**: 35% Complete

### ✅ Added Features (Complete/Uncomplete Features)

- **Project Architecture**: Add Flutter project structure with MVVM pattern
- **UI/UX Design**: All main screens implemented with Material Design 3
- **State Management**: Provider pattern with 5 core providers (including OfflineProvider)
- **Database Schema**: SQLite database with proper relationships
- **Multi-language Support**: English/Filipino localization system
- **Navigation**: Bottom navigation with 5 main sections
- **Settings**: Comprehensive app configuration
- **Sample Data**: A few DOH-approved plants and model labels
- **Offline Processing**: Full offline functionality
- **AI Model Integration**: MobileNet V2 + Random Forest fully integrated, which is still not accurate
- **Offline AI Inference**: TensorFlow Lite models work offline
- **Connectivity Monitoring**: Real-time network status detection
- **Offline Data Management**: Local storage with optimization and cleanup
- **Offline Sync Management**: Automatic data synchronization when online
- **Offline UI Components**: Status indicators and management interface
- **GradCAM Visualization**: Explainable AI heatmap system with working overlay controls, which still needs fixing
- **Plant Results Screen**: AI prediction results with functional GradCAM integration and overlay functionality, not accurate at the momment
- **Interactive Heatmaps**: Working opacity controls and tabbed interface for heatmap visualization
- **Critical Bug Fixes**: All GradCAM-related bugs resolved (type casting, overlay controls, UI overflow), still need optimazing fix and improvements

### 🔄 In Progress (Phase 6)

- **Performance Optimization**: Final mobile deployment optimization
- **Plant Database Population**: Load real plant data
- **Search & Filtering**: Advanced plant browsing

### ⏳ Pending

- **User Testing**: Real-world testing and feedback
- **App Store Preparation**: Final deployment preparation

## 📋 Development Progress Log

### Phase 1: Core Foundation (Added Features ✅)

**Date**: September 6, 2025

#### Project Setup & Architecture

- [x] Created Flutter project structure
- [x] Implemented MVVM architecture with Provider pattern
- [x] Set up proper folder organization
- [x] Added all necessary dependencies in pubspec.yaml

#### Core Models & Services

- [x] **Plant Model**: Created a data structure for medicinal plants
- [x] **ScanResult Model**: AI prediction results with metadata
- [x] **DatabaseService**: SQLite operations with proper relationships
- [x] **PlantService**: Business logic for plant operations

#### State Management

- [x] **AppProvider**: Global app settings and preferences
- [x] **PlantProvider**: Plant data and scan history management
- [x] **CameraProvider**: Camera functionality and image processing
- [x] **LanguageProvider**: Multi-language support with persistence

#### UI/UX Implementation

- [x] **Splash Screen**: App launch with language selection
- [x] **Onboarding**: 4-page feature introduction
- [x] **Home Dashboard**: Main hub with quick actions and statistics
- [x] **Settings Screen**: Comprehensive app configuration
- [x] **Navigation**: Bottom navigation with 5 sections

#### Database Schema

- [x] **Plants Table**: Core plant information
- [x] **Medicinal Uses Table**: Therapeutic applications
- [x] **Preparation Methods Table**: Traditional preparation instructions
- [x] **Scan History Table**: User scan results and AI predictions
- [x] **Indexes**: Optimized database performance

#### Multi-language Support

- [x] **Localization System**: English/Filipino language support
- [x] **Dynamic Language Switching**: Runtime language changes
- [x] **Persistent Settings**: Language preference storage

### Phase 2: AI Integration (Added ✅)

**Date**: September 7, 2025

#### Camera Functionality

- [x] **Camera Provider**: Implement a camera management system
- [x] **Image Capture**: Photo capture with error handling
- [x] **Image Processing**: Preprocessing for AI inference
- [x] **Scan Screen**: Camera interface with overlay controls
- [x] **Error Handling**: Comprehensive error states and recovery

#### AI Model Integration

- [x] **Model Architecture**: MobileNet V2 + Random Forest integrated
- [x] **Asset Structure**: Models directory with proper organization
- [x] **Model Conversion**: Converted .h5/.pkl to TensorFlow Lite
- [x] **Model Integration**: Load and run inference implemented
- [x] **Offline AI Processing**: Implement a offline inference pipeline

### Phase 3: Bug Fixes & Optimization (Added Features ✅)

**Date**: September 7, 2025

#### Bug Fixes

- [x] **Theme Switching Errors**: Fixed GlobalKey conflicts causing red error screens
- [x] **Theme Switching Performance**: Eliminated 1-second delay during mode changes
- [x] **Flashlight Functionality**: Fixed flashlight/torch feature on physical devices
- [x] **Quick Actions UI Overflow**: Resolved "BOTTOM OVERFLOWED BY 8.6 PIXELS" errors
- [x] **AI Model Connection**: Fixed AI models not loading for image capture
- [x] **Camera Error Handling**: Improved error handling and recovery
- [x] **UI Layout Issues**: Fixed various UI layout problems from USB testing

#### Device Testing

- [x] **USB Device Testing**: Comprehensive testing on physical Android devices
- [x] **Theme Stability**: Extensive dark/light mode switching testing
- [x] **UI Responsiveness**: Layout testing across different screen sizes
- [x] **Error Handling**: Comprehensive error scenario testing

### Phase 4: Offline Processing (Added Features ✅)

**Date**: September 8, 2025

#### Offline Service Architecture

- [x] **OfflineService**: Central coordinator for all offline functionality
- [x] **OfflineProvider**: State management with real-time connectivity updates
- [x] **OfflineDataManager**: Local data storage, cleanup, and optimization
- [x] **OfflineSyncManager**: Automatic data synchronization when online

#### Connectivity Monitoring

- [x] **Real-time Detection**: Network status monitoring using connectivity_plus
- [x] **Automatic Switching**: Seamless online/offline mode transitions
- [x] **Background Sync**: Data synchronization with retry logic
- [x] **Error Handling**: Robust error handling for offline scenarios

#### Offline UI Components

- [x] **OfflineIndicator**: Connection status display component
- [x] **OfflineStatusCard**: Comprehensive status information display
- [x] **OfflineFeatureStatus**: Feature availability status display
- [x] **OfflineDemoScreen**: Added a testing interface for offline capabilities

#### Offline Data Management

- [x] **Local Storage**: Efficient local data storage with optimization
- [x] **Data Cleanup**: Automatic cleanup of old and unnecessary data
- [x] **Storage Statistics**: Real-time storage usage monitoring
- [x] **Export/Import**: Data export and import functionality

### Phase 5: GradCAM Visualization (Added Features ✅)

**Date**: September 9, 2025

#### GradCAM System Implementation

- [x] **GradCAMService**: Core service for generating attention heatmaps
- [x] **GradCAMVisualization Widget**: Interactive UI component with working opacity controls
- [x] **Plant Results Screen**: Enhanced with functional GradCAM display and tabbed interface
- [x] **Camera Integration**: GradCAM generation in both camera capture and gallery selection flows
- [x] **Interactive Heatmaps**: Working opacity slider and color-coded visualization with overlay functionality
- [x] **Comprehensive Testing**: Unit, integration, and manual testing suite
- [x] **File Management**: Automatic saving and cleanup of heatmap images

#### Critical Bug Fixes

- [x] **Type Casting Issues**: Fixed ColorRgb8 to Pixel type casting errors preventing heatmap generation
- [x] **Gallery Integration**: Fixed gallery image processing to use GradCAM-enabled classification
- [x] **UI Overflow Issues**: Fixed "Right Overflowed by 44 pixels" error with responsive Wrap widget
- [x] **Confidence Bar Overflow**: Fixed green confidence indicator overflow with proper value clamping
- [x] **Overlay Controls**: Fixed "Show Heatmap Overlay" toggle and "Heatmap Opacity" slider functionality
- [x] **Offline Processing**: Fixed offline processing path that was setting GradCAM paths to null

### Phase 6: Final Features (In Progress 🔄)

**Date**:

#### Plant Database & Optimization

- [ ] **Plant Database Population**: Load real Philippine medicinal plant data
- [ ] **Search & Filtering**: Advanced plant browsing capabilities
- [ ] **Performance Optimization**: Final mobile deployment optimization

#### Plant Database

- [ ] **Data Population**: Load real Philippine medicinal plant data
- [ ] **DOH Integration**: Complete 13 DOH-approved plants
- [ ] **Search & Filtering**: Advanced plant browsing capabilities
- [ ] **Image Assets**: High-quality plant photos

#### User Experience

- [ ] **Scan History**: Complete history management
- [ ] **Plant Details**: Comprehensive plant information screens
- [ ] **Performance Optimization**: Mobile deployment optimization
- [ ] **User Testing**: Real-world testing and feedback

## 🛠️ Technical Implementation Details

### Architecture

- **Framework**: Flutter 3.9.2+
- **State Management**: Provider pattern with 5 providers
- **Database**: SQLite with proper relationships
- **AI/ML**: TensorFlow Lite with a offline processing and GradCAM visualization
- **Offline Processing**: Add a offline functionality for rural areas
- **GradCAM**: Explainable AI heatmap generation with working interactive visualization and overlay controls
- **Connectivity**: Real-time network monitoring with connectivity_plus
- **Localization**: Flutter's built-in i18n system

### Key Dependencies

```yaml
# State Management
provider: ^6.1.1

# Database
sqflite: ^2.3.0
path: ^1.8.3

# Camera & Image Processing
camera: ^0.9.4+5
image_picker: ^1.0.4
image: ^3.0.2

# AI/ML
tflite_flutter: ^0.9.0
tflite_flutter_helper: ^0.2.1

# Localization
flutter_localizations:
intl: ^0.20.2

# UI Components
flutter_staggered_grid_view: ^0.7.0
shimmer: ^3.0.0
lottie: ^2.7.0

# Connectivity & Offline
connectivity_plus: ^6.0.5

# Image Processing & GradCAM
path_provider: ^2.1.1
```

### File Structure

```
herbascan/
├── lib/                   ✅ (35+ files)
│   ├── core/              ✅
│   │   ├── models/        ✅ (Plant, ScanResult)
│   │   ├── providers/     ✅ (5 providers)
│   │   ├── services/      ✅ (Database, Plant, Offline, GradCAM)
│   │   ├── widgets/       ✅ (Offline indicators, GradCAM visualization)
│   │   ├── theme/         ✅ (Material Design 3)
│   │   └── localization/  ✅ (i18n)
│   └── features/          ✅ (9 screens)
├── assets/                ✅ (organized structure)
├── Documentation          ✅ (5 comprehensive docs)
└── Configuration          ✅ (pubspec.yaml, etc.)
```

## 🎯 Next Steps

### Immediate (Next Session)

1. **Plant Database Population**: Load real Philippine medicinal plant data
2. **Search & Filtering**: Implement advanced plant browsing capabilities
3. **Performance Optimization**: Final mobile deployment optimization
4. **User Testing**: Test with real users and gather feedback

### Short Term (1-2 weeks)

1. **Complete Plant Database**: Load all 13 DOH-approved plants with detailed information
2. **Implement Search & Filtering**: Advanced plant browsing and search capabilities
3. **Performance Optimization**: Optimize for mobile deployment and battery usage
4. **User Testing**: Test with real users and gather feedback

### Long Term (1-2 months)

1. **User Testing**: Test with target users
2. **UI/UX Refinements**: Based on user feedback
3. **App Store Preparation**: Final deployment preparation
4. **Documentation**: Complete user and developer documentation

## 📊 Progress Metrics

- **Code Files Created**: 35+ files
- **Lines of Code**: 4000+ lines
- **Features Implemented**: 25+ core features
- **Screens Created**: 9 main screens
- **Providers**: 5 state management providers
- **Offline Features**: Add a offline processing system
- **GradCAM Features**: Add a explainable AI visualization system
- **Database Tables**: 4 tables with relationships
- **Languages Supported**: 2 (English, Filipino)

## 🌐 Offline Processing Capabilities

HerbaScan is designed to work seamlessly in rural areas without internet connectivity, making it perfect for underserved communities in the Philippines.

### Offline Functionality

- **Offline AI Processing**: Plant identification works ok with offline using TensorFlow Lite models
- **Offline Data Access**: Full plant database accessible without internet
- **Offline Storage**: All scan results stored locally with optimization
- **Connectivity Monitoring**: Real-time network status detection and management
- **Automatic Sync**: Data synchronization when connectivity returns

### Offline Service Architecture

- **OfflineService**: Central coordinator for all offline functionality
- **OfflineProvider**: State management with real-time connectivity updates
- **OfflineDataManager**: Local data storage, cleanup, and optimization
- **OfflineSyncManager**: Automatic data synchronization when online

### Offline UI Components

- **OfflineIndicator**: Connection status display in app header
- **OfflineStatusCard**: Comprehensive status information display
- **OfflineFeatureStatus**: Feature availability status display
- **OfflineDemoScreen**: Add a testing interface for offline capabilities

## 🔧 Development Notes

### Recent Changes

- **GradCAM Visualization**: Updated the explainable AI heatmap system implementation
- **Plant Results Screen**: Enhanced with interactive GradCAM display and tabbed interface
- **Interactive Heatmaps**: Opacity controls and color-coded visualization
- **Comprehensive Testing**: Unit, integration, and manual testing suite for GradCAM
- **Offline Processing**: Updated the offline functionality implementation
- **Connectivity Monitoring**: Real-time network status detection
- **Bug Fixes**: All critical bugs from USB device testing resolved

### Known Issues

- **Database Population**: Pending real plant data loading
- **Search & Filtering**: Pending advanced plant browsing capabilities
- **Performance Optimization**: Pending final mobile deployment optimization

### Technical Decisions

- **State Management**: Chose Provider over Bloc for simplicity
- **Database**: SQLite for offline-first approach
- **UI Framework**: Material Design 3 for modern look
- **Architecture**: MVVM pattern for maintainability
- **Offline Processing**: Updated offline-first architecture for rural areas
- **GradCAM Implementation**: Simplified attention-based heatmap approach for TensorFlow Lite

---

## Features

- 🌿 **AI-Powered Plant Recognition**: Uses MobileNet V2 + Random Forest for accurate plant identification
- 📱 **Offline Processing**: Works without internet connection
- 🏥 **DOH Integration**: Access to 13 clinically validated herbal medicines
- 🔍 **Explainable AI**: GradCAM visualization shows how the AI identifies plants
- 🌐 **Multi-language Support**: English and Filipino language options
- 📊 **Confidence Scoring**: Shows prediction confidence levels
- 📚 **Comprehensive Database**: Detailed plant information including taxonomy, morphology, and medicinal uses

## Setup Instructions

### Prerequisites

1. **Flutter SDK**: Install Flutter 3.9.2 or later

   - Download from: https://flutter.dev/docs/get-started/install
   - Add Flutter to your PATH environment variable

2. **Android Studio**: For Android development

   - Download from: https://developer.android.com/studio
   - Install Android SDK and emulator

3. **VS Code** (Recommended): For Flutter development
   - Install Flutter and Dart extensions

### Installation

1. **Clone the repository**:

   ```bash
   git clone <repository-url>
   cd herbascan
   ```

2. **Install dependencies**:

   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

### For Android Development

1. **Enable Developer Options** on your Android device
2. **Enable USB Debugging**
3. **Connect your device** or start an emulator
4. **Run the app**:
   ```bash
   flutter run
   ```

## AI Model Integration

### Current Status

- ✅ MobileNet V2 + Random Forest model trained
- ✅ Model files: `.h5` and `.pkl` formats
- ✅ Model conversion to TensorFlow Lite (complete)
- ✅ GradCAM visualization with working overlay controls (all bugs resolved)
- ✅ Android integration (Good)
- ✅ Offline processing (ok)

### Model Conversion Steps

1. **Convert H5 to TensorFlow Lite**:

   ```python
   import tensorflow as tf

   # Convert MobileNet V2 model (.h5 to .tflite)
   model_path = r"Your path file of the Model"

   # Load the Keras model
   model = tf.keras.models.load_model(model_path)

   # Convert to TensorFlow Lite
   converter = tf.lite.TFLiteConverter.from_keras_model(model)
   converter.optimizations = [tf.lite.Optimize.DEFAULT]

   # Optional: Set input/output types for better performance
   converter.target_spec.supported_types = [tf.float16]

   tflite_model = converter.convert()

   # Save the converted model
   with open("mobilenetv2_feature_extractor.tflite", "wb") as f:
      f.write(tflite_model)

   print("✅ MobileNet V2 conversion complete: mobilenetv2_feature_extractor.tflite")
   ```

2. **Convert Random Forest**:

   ```python
   # distill_rf_to_tflite.py
   import pickle
   import numpy as np
   import tensorflow as tf
   from sklearn.model_selection import train_test_split

   # Paths — adjust
   rf_path = r"Your path file of the Model"
   features_path = r"Your path file of the Model"
   # your features (recommended)
   tflite_out = "random_forest_distilled.tflite"

   # -------- load RF
   with open(rf_path, "rb") as f:
      rf = pickle.load(f)

   # -------- load or synthesize features
   try:
      X = np.load(features_path)
      print("Loaded features from", features_path, "shape:", X.shape)
   except Exception as e:
      print("Could not load features.npy — falling back to synthetic sampling. It's better to use real features.")
      # fallback: sample from a simple normal distribution
      # If you know ranges/means for each feature, replace this with better sampling
      num_samples = 20000
      feature_dim = getattr(rf, "n_features_in_", 2048)
      X = np.random.normal(size=(num_samples, feature_dim)).astype(np.float32)
      print("Generated synthetic features shape:", X.shape)

   # -------- get RF predictions
   # Prefer probabilities for richer supervision if RF supports it
   if hasattr(rf, "predict_proba"):
      y_rf = rf.predict_proba(X)  # shape (N, n_classes)
      use_prob = True
      n_classes = y_rf.shape[1]
      print("RF predict_proba available — using probabilistic distillation, classes:", n_classes)
   else:
      y_rf = rf.predict(X)        # shape (N,)
      use_prob = False
      # convert to int labels
      y_rf = np.asarray(y_rf)
      n_classes = len(np.unique(y_rf))
      print("RF predict_proba not available — using labels, estimated classes:", n_classes)

   # -------- split
   X_train, X_val, y_train, y_val = train_test_split(X, y_rf, test_size=0.12, random_state=42)

   # -------- build a small Keras model
   input_dim = X.shape[1]
   if use_prob:
      # train to match probability distribution (MSE or KL)
      model = tf.keras.Sequential([
         tf.keras.Input(shape=(input_dim,)),
         tf.keras.layers.Dense(512, activation="relu"),
         tf.keras.layers.Dropout(0.2),
         tf.keras.layers.Dense(256, activation="relu"),
         tf.keras.layers.Dense(n_classes, activation="softmax")
      ])
      loss = tf.keras.losses.KLDivergence()  # or 'mse'
      metrics = [tf.keras.metrics.CategoricalAccuracy(name="cat_acc")]
   else:
      # train to match labels
      model = tf.keras.Sequential([
         tf.keras.Input(shape=(input_dim,)),
         tf.keras.layers.Dense(512, activation="relu"),
         tf.keras.layers.Dropout(0.2),
         tf.keras.layers.Dense(256, activation="relu"),
         tf.keras.layers.Dense(n_classes, activation="softmax")
      ])
      loss = tf.keras.losses.SparseCategoricalCrossentropy()
      metrics = [tf.keras.metrics.SparseCategoricalAccuracy(name="sparse_acc")]

   model.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss=loss, metrics=metrics)
   model.summary()

   # -------- Prepare targets for training
   if use_prob:
      y_train_target = y_train.astype(np.float32)
      y_val_target = y_val.astype(np.float32)
   else:
      # ensure integer labels
      # If rf.predict returns strings, map to integers
      if y_train.dtype.kind in {"U", "S", "O"}:
         # map unique labels
         classes, inv = np.unique(y_train, return_inverse=True)
         y_train_target = inv
         classes_val_map = {c:i for i,c in enumerate(classes)}
         y_val_target = np.array([classes_val_map[x] for x in y_val])
      else:
         y_train_target = y_train.astype(np.int32)
         y_val_target = y_val.astype(np.int32)

   # -------- train (adjust epochs/batch_size to your compute)
   history = model.fit(
      X_train, y_train_target,
      validation_data=(X_val, y_val_target),
      epochs=20,
      batch_size=256,
      callbacks=[tf.keras.callbacks.EarlyStopping(monitor='val_loss', patience=3, restore_best_weights=True)]
   )

   # -------- Evaluate
   eval_res = model.evaluate(X_val, y_val_target, verbose=1)
   print("Validation eval:", eval_res)

   # -------- Convert to TFLite
   converter = tf.lite.TFLiteConverter.from_keras_model(model)
   converter.optimizations = [tf.lite.Optimize.DEFAULT]
   # for quantization (optional), you'd need a representative dataset function
   tflite_model = converter.convert()

   with open(tflite_out, "wb") as f:
      f.write(tflite_model)

   print("✅ Saved TFLite to", tflite_out)
   # Optionally save the Keras model
   model.save("random_forest_distilled_keras.h5")
   print("✅ Saved Keras model random_forest_distilled_keras.h5")
   ```

3. **Converting class_labels.pkl to labels.txt**:

   ```python
   import pickle
   import json
   from pathlib import Path

   def convert_class_labels():
      # === PATHS ===
      pkl_path = Path(r"Your path file of the Model")
      txt_path = Path(r"..\HerbaScan\herbascan\assets\models\labels.txt")
      json_path = Path(r"..\HerbaScan\herbascan\assets\models\labels.json")

      print("🔄 Loading class labels from pickle file...")

      # === LOAD PICKLE ===
      with open(pkl_path, 'rb') as f:
         class_labels = pickle.load(f)

      # Handle if it's a dict instead of list
      if isinstance(class_labels, dict):
         class_labels = list(class_labels.values())
      elif not isinstance(class_labels, (list, tuple)):
         raise TypeError(f"Unexpected type for labels: {type(class_labels)}")

      print(f"✅ Loaded {len(class_labels)} class labels")
      print(f"🧾 Sample labels: {class_labels[:5]}")

      # === SAVE AS TXT ===
      txt_path.parent.mkdir(parents=True, exist_ok=True)
      with open(txt_path, 'w', encoding='utf-8') as f:
         for label in class_labels:
               f.write(f"{label}\n")

      print(f"✅ Labels saved to TXT: {txt_path}")

      # === SAVE AS JSON ===
      labels_dict = {i: label for i, label in enumerate(class_labels)}

      with open(json_path, 'w', encoding='utf-8') as f:
         json.dump(labels_dict, f, indent=2, ensure_ascii=False)

      print(f"✅ Labels saved to JSON: {json_path}")

      # === SUMMARY ===
      print("\n📋 Label Summary:")
      for i, label in enumerate(class_labels):
         print(f"{i:2d}: {label}")

      return class_labels


   if __name__ == "__main__":
      try:
         labels = convert_class_labels()
         print("\n🎉 Conversion complete!")
      except Exception as e:
         print(f"❌ Error: {e}")
   ```

4. **Place model files** in `assets/models/` directory:
   - `herbascan_model.tflite` (CNN model)
   - `random_forest_classifier.tflite` (Random Forest model)
   - `labels.json` (JSON format)
   - `labels.txt` (Class labels)

## Database Schema

The app uses SQLite for local data storage with the following tables:

- **plants**: Plant information and metadata
- **medicinal_uses**: Medicinal applications for each plant
- **preparation_methods**: Traditional preparation instructions
- **scan_history**: User scan results and AI predictions

## DOH-Approved Plants

The app includes information about 13 DOH-approved herbal medicines:

1. Lagundi (Vitex negundo) - Cough, Asthma
2. Sambong (Blumea balsamifera) - Kidney stones
3. Akapulko (Cassia alata) - Skin conditions
4. Tsaang Gubat (Ehretia microphylla) - Diarrhea
5. Ampalaya (Momordica charantia) - Diabetes
6. Niyog-niyogan (Quisqualis indica) - Intestinal worms
7. Ulasimang-bato (Peperomia pellucida) - Gout
8. Bawang (Allium sativum) - Hypertension
9. Bayabas (Psidium guajava) - Wound healing
10. Yerba Buena (Mentha cordifolia) - Stomach ache
11. Pansit-pansitan (Peperomia pellucida) - Gout
12. Tawa-tawa (Euphorbia hirta) - Dengue fever
13. Malunggay (Moringa oleifera) - Nutrition

## Development Roadmap

### Phase 1: Core Functionality ✅

- [x] Project setup and architecture
- [x] UI/UX design implementation
- [x] Database schema and models
- [x] State management setup
- [x] Multi-language support
- [x] Camera integration
- [x] Image processing pipeline
- [x] Comprehensive documentation

### Phase 2: AI Integration ✅

- [x] Camera integration
- [x] Image processing pipeline
- [x] Model conversion to TensorFlow Lite
- [x] AI inference pipeline
- [x] Offline processing
- [x] GradCAM visualization

### Phase 3: Advanced Features ✅

- [ ] Plant database population
- [ ] Search and filtering
- [ ] Scan history management
- [ ] Performance optimization
- [ ] User testing and feedback

### Phase 4: Polish & Deployment ✅

- [ ] UI/UX refinements
- [ ] Performance testing
- [ ] App/Google store preparation
- [ ] Documentation completion

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Submit a pull request

## License

This project is part of an undergraduate thesis at Lyceum of the Philippines University-Cavite.

## Contact

For questions or support, please contact the development team.

---

**Note**: This app is for educational and informational purposes only. Always consult healthcare professionals before using any herbal remedies.


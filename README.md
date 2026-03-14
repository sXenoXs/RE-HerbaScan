# HerbaScan - AI-Powered Plant Identification App

**Thesis Project**: HERBASCAN: A CONVOLUTIONAL NEURAL NETWORK-BASED MOBILE APPLICATION FOR PLANT IDENTIFICATION AND HERBAL MEDICINE INFORMATION

HerbaScan is a Flutter-based mobile application that uses Convolutional Neural Networks (CNN) and Random Forest algorithms to identify Philippine medicinal plants. The app provides comprehensive information about DOH-approved herbal medicines and supports offline processing for rural areas.

**Academic Context**: Undergraduate Thesis - College of Information Technology and Computer Science, Lyceum of the Philippines University-Cavite  
**Client/Partner**: Philippine Institute of Traditional and Alternative Health Care (PITAHC)  
**Dataset**: PhilMedic - 4,922 leaf images, 40 medicinal plant classes native to the Philippines

## 🚀 Current Development Status

**Version**: v0.9.4  
**Last Updated**: March 2026
**Project Phase**: Phase 35 Complete (AI Explanation Content Standardization & Complete Plant Database Migration)  
**Overall Progress**: 90% Complete - **PRODUCTION READY** 

### ✅ Added Features (Complete/Incomplete Features)

- **Project Architecture**: ✅ Flutter project structure with MVVM pattern
- **UI/UX Design**: ✅ All main screens implemented with Material Design 3
- **State Management**: ✅ Provider pattern with 6 core providers (App, Plant, Camera, Language, Offline, Auth)
- **Database Schema**: ✅ SQLite database with proper relationships
- **Multi-language Support**: ✅ English/Filipino localization system
- **Navigation**: ✅ Bottom navigation: 4 tabs (Home, Browse, History, Settings) with center camera FAB; DOH Approved Plants via Home carousel "See All"
- **Settings**: ✅ Comprehensive app configuration
- **Plant Database**: ✅ **42 medicinal plants with comprehensive data** (10 DOH-approved + 32 additional)
- **XAI Explanation Database**: ✅ **NEW** Complete offline explanations for all 42 plants stored in JSON (~150KB)
- **Offline Data Retrieval**: ✅ **NEW** Fixed broken offline data retrieval - all 42 plants now display complete summaries
- **Scientific Name Resolution**: ✅ **NEW** Automatic scientific name lookup from plant database in Details and History screens
- **Confidence Score Display**: ✅ **NEW** Replaced meaningless "Features" with useful confidence percentage display
- **History Screen Scientific Names**: ✅ **NEW** Fixed missing scientific name subtitles in scan history list
- **CAM Result Caching**: ✅ **NEW** Fixed auto-regeneration bug - CAM results from history load saved summaries instead of regenerating
- **Camera Zoom Controls**: ✅ **NEW** Pinch-to-zoom and optimized slider zoom with performance improvements
- **UI/UX Refinements**: ✅ **NEW** Enhanced readability, visibility, and user experience across all screens
- **Offline Processing**: ✅ Full offline functionality
- **AI Model Integration**: ✅ **UPDATED** Standardized to MobileNetV2 model only for prediction consistency (HerbaScan custom model deprecated)
- **Offline AI Inference**: ✅ TensorFlow Lite multi-output model works offline (MobileNetV2 only)
- **Online/Offline Adaptive System**: ✅ **NEW** Automatically tries online GradCAM first, falls back to offline CAM gracefully
- **Plant Name Display**: ✅ **NEW** Fixed to show correct plant names (e.g., "Mango" instead of "Plant_24")
- **Predictions Format**: ✅ **NEW** Fixed to return predictions in correct format for UI display
- **Connectivity Monitoring**: ✅ Real-time network status detection
- **Offline Data Management**: ✅ Local storage with optimization and cleanup
- **Offline Sync Management**: ✅ Automatic data synchronization when online
- **Offline UI Components**: ✅ Status indicators and management interface
- **GradCAM Visualization**: ✅ Explainable AI heatmap system with working overlay controls
- **Interactive Full-Screen Heatmap Mode**: ✅ **NEW** Tap heatmap to open full-screen zoomable view with live controls
- **Offline CAM Heatmap Rendering**: ✅ **NEW** Smooth bicubic interpolation and Gaussian blur for organic, contoured heatmaps
- **Unified Heatmap Explanation Card**: ✅ **NEW** Merged "About GradCAM/CAM" and "Heatmap Legend" into single card with visual legend
- **Persistent Settings System**: ✅ **NEW** User preferences saved to SharedPreferences (show_confidence, show_gradcam, show_top3)
- **Hybrid XAI Explanation System**: ✅ **UPDATED** Standardized content structure with four sections (Taxonomy, Ecology, Medicinal Uses, Safety) - identical format for online and offline explanations
  - ✅ **COMPLETE** All 42 plants in `plant_explanations.json` migrated to new structured format
  - ✅ **FIXED** GradCAM (Online) source badge now correctly displays "Online" instead of "Offline"
- **Plant Results Screen**: ✅ AI prediction results with functional GradCAM integration
- **Interactive Heatmaps**: ✅ Working opacity controls and tabbed interface
- **Plant Detail Screen**: ✅ **NEW** Comprehensive plant information with ecology & habitat
- **Preparation Instructions**: ✅ **NEW** Step-by-step herbal medicine preparation guide
- **Critical Bug Fixes**: ✅ All GradCAM-related bugs resolved
- **Browse Screen**: ✅ Full plant browsing with search, filter (All/DOH/Condition), grid/list views
- **DOH Approved Plants Screen**: ✅ Dedicated screen for 10 DOH-approved plants with official branding
- **Scan History Screen**: ✅ Complete history management with sort, delete, statistics
- **Condition-based Search**: ✅ Browse by 15 medical conditions
- **Poor Image Quality Screen**: ✅ Error handling with scanning tips
- **No Match Found Screen**: ✅ User-friendly error state with alternatives
- **Help & Tutorial Screen**: ✅ Comprehensive guide with best practices
- **Performance Metrics Screen**: ✅ AI model metrics (Accuracy, Precision, Recall, F1-Score)
- **Scanning Tips Bottom Sheet**: ✅ Interactive draggable tips on camera screen
- **Page Transition Animations**: ✅ Smooth slide and fade transitions
- **Loading Animations**: ✅ Shimmer effects and fade-in widgets
- **Success Animations**: ✅ Elastic bounce for positive feedback
- **User Feedback System**: ✅ **NEW** 5-star rating with comments and categories
- **Performance Monitoring**: ✅ **NEW** Track app performance metrics automatically
- **Usage Analytics**: ✅ **NEW** Scan success rate and feature usage tracking
- **Error Logging**: ✅ **NEW** Comprehensive error tracking and reporting
- **Performance Dashboard**: ✅ **NEW** View metrics, analytics, and error logs
- **Testing Guide**: ✅ **NEW** Complete user testing documentation
- **Backend API**: ✅ **NEW** Python FastAPI server for true Grad-CAM computation
- **Backend Documentation**: ✅ **NEW** Comprehensive model management and deployment guides
- **Postman Testing**: ✅ **NEW** Complete testing guide for VS Code and other IDEs
- **GradCAM/CAM Fixes**: ✅ **NEW** Fixed all GradCAM and CAM heatmap issues, scan persistence, and UI visibility
- **Method Labels**: ✅ **NEW** Added method indicators (CAM/GradCAM/Fallback/Online) in History and Recent Scans
- **Resizable Text Areas**: ✅ **NEW** Made feedback form text areas vertically resizable
- **Hybrid XAI Explanation System**: ✅ **UPDATED** Standardized structured format with four required sections: Taxonomy, Ecology & Habitat, Medicinal Uses, Safety Protocol
- **Markdown Text Formatting**: ✅ **UPDATED** Uses h3 headers (###) for structured sections, rich text with proper formatting (bold, italic, headers, lists)
- **Usability Assessment**: ✅ **NEW** Clear status indicators (USABLE/USE WITH CAUTION/NOT RECOMMENDED) based on heatmap analysis
- **Content Standardization**: ✅ **COMPLETE** Explanations use identical structure from cache, offline JSON, and fallback only (no live LLM at runtime)
  - All 42 plants in structured format with taxonomy, ecology, medicinal_preparation, and safety_consideration
  - Source badge displays "Online" for GradCAM (Online) mode and "Offline" for CAM (Offline) mode
- **Refresh Functionality**: ✅ **NEW** Refresh button regenerates both GradCAM heatmap and AI explanation
- **Scroll Position Persistence**: ✅ **NEW** Condition Search Screen now preserves scroll position when navigating back from selected condition
- **Feedback Screen Text Contrast**: ✅ **NEW** Fixed poor text contrast on selected feedback chips - dark green text on light green background for optimal readability
- **Scan Screen AppBar Title Visibility**: ✅ **NEW** Fixed invisible "Scan Plant" title - changed to white text for readability against dark camera background
- **UI Cleanup**: ✅ **NEW** Removed redundant DOH section from home screen - cleaner UI with single navigation path through Quick Actions
- **Plant Result Screen Refactoring**: ✅ **NEW** Refactored to use NestedScrollView with collapsible SliverAppBar - smooth transitions, pinned TabBar, better space utilization
- **Heatmap Controls UI Logic Fix**: ✅ **NEW** Fixed bug where heatmap controls were showing on all tabs - now only visible on Heatmap tab, state persists correctly
- **Plant Result Screen UI Regression Fix**: ✅ **NEW** Fixed UI regression - restored "Scan Results" title and centered image card design with white background, rounded corners, and shadow
- **Plant Result Screen Layout Overflow Fix**: ✅ **NEW** Fixed layout overflow errors - increased expandedHeight to 420.0, removed plant name from title, proper card structure with BorderRadius.circular(20)
- **Plant Result Screen Background Color**: ✅ **NEW** Changed FlexibleSpaceBar background from white to #f8fbfc (light blue-gray) for softer appearance
- **Plant Result Screen Card Color**: ✅ **NEW** Changed main plant card container to use gradient with two lighter colors based on #EBEDFB (rgba(235, 237, 251)) - #F0F2FC to #F5F7FE gradient for elegant appearance. Card size increased for better space utilization.
- **Heatmap Controls Visibility Logic**: ✅ **NEW** Refactored visibility logic - controls only show on Heatmap tab, taking zero space on other tabs
- **Tap to Expand Plant Image**: ✅ **NEW** Implemented tap to expand feature - tap plant image to view in full-screen with Hero animation, pinch-to-zoom (0.5x-4.0x), and pan gestures
- **Full Screen Reading Mode**: ✅ **NEW** Implemented full-screen reading mode for Summary tab - distraction-free view with larger text and regenerate capability
- **AI Explanation Tab Simplification**: ✅ **NEW** Removed 'Original' sub-tab from AI Explanation section - simplified navigation to only Heatmap and Summary tabs
- **Version Update**: ✅ **NEW** Updated all version references to v0.9.4 across the application (splash, settings, app info, feedback, docs)

### 🔄 In Progress (Phase 6: Offline CAM Fix)

- **Offline CAM Inference Fix**: Fixed multiple output buffers shape mismatch error
- **TFLite Multiple Outputs**: Corrected output buffer passing for multi-output models
- **Testing**: Verifying offline CAM heatmap generation in offline mode
- **Beta Testing**: User testing with TESTING_GUIDE.md
- **Data Collection**: Gathering user feedback and metrics

### ✅ Recently Fixed (v0.9.4)

- **Online GradCAM Prediction Mapping**: Fixed "Unknown" plant names in online GradCAM predictions
- **Backend Response Field Mapping**: Corrected mapping from backend 'class' and 'class_index' to Flutter format
- **Label Format Parsing**: Added parsing to extract plant names from backend label format

### ⏳ Pending (Future Updates)

- **User Testing**: Real-world testing and feedback
- **App Store Preparation**: Final deployment preparation

## 📋 Development Progress Log

### Phase 5: Testing & Optimization (✅ COMPLETED)

**Date**: November 3, 2025

#### User Feedback System
- [x] **Feedback Screen** - 5-star rating with comments
- [x] **6 Categories** - Accuracy, Usability, Performance, Features, Bugs, General
- [x] **Feature Suggestions** - Optional improvement ideas
- [x] **Local Storage** - Feedback saved for thesis research
- [x] **Export Support** - JSON export for analysis

#### Performance Monitoring
- [x] **Performance Monitor Service** - Track operation durations
- [x] **Automatic Logging** - Metrics saved automatically
- [x] **Operation Stats** - Average, min, max, median times
- [x] **Export Metrics** - JSON export for analysis

#### Usage Analytics
- [x] **Analytics Service** - Track user behavior patterns
- [x] **Scan Tracking** - Total, successful, failed scans
- [x] **Success Rate** - Automatic calculation
- [x] **Feature Usage** - Track most used features
- [x] **Plant Analytics** - Most scanned plants
- [x] **Condition Analytics** - Most searched conditions

#### Error Logging
- [x] **Error Logger Service** - Comprehensive error tracking
- [x] **8 Error Types** - Categorized error logging
- [x] **Stack Traces** - Optional detailed logging
- [x] **Error Statistics** - Total, by type, last 24h
- [x] **Export Errors** - JSON export for debugging

#### Performance Dashboard
- [x] **Dashboard Screen** - View all metrics in one place
- [x] **Usage Stats Cards** - Visual stat display
- [x] **Performance Breakdown** - Operation timing details
- [x] **Error Tracking** - Error logs and statistics
- [x] **Export All** - Export complete dataset
- [x] **Clear Data** - Reset for testing

#### Testing Guide
- [x] **Testing Documentation** - Complete TESTING_GUIDE.md
- [x] **50+ Test Cases** - Comprehensive coverage
- [x] **Performance Benchmarks** - Expected vs actual
- [x] **Bug Reporting Template** - Structured reporting
- [x] **User Feedback Forms** - Data collection templates

### Phase 4: Final Polish (✅ COMPLETED)

**Date**: October 28, 2025

#### Camera UI Refinements
- [x] **Tips Button** - Blue button with lightbulb icon in camera top bar
- [x] **Draggable Bottom Sheet** - Swipeable scanning tips overlay
- [x] **6 Scanning Tips** - Color-coded tips with icons and descriptions
- [x] **Handle Bar** - Visual drag indicator
- [x] **Smooth Animations** - Sheet slides up with ease-in-out transition

#### Animation System
- [x] **SlidePageRoute** - Slide transitions from any direction
- [x] **FadePageRoute** - Clean fade transitions
- [x] **ScalePageRoute** - Scale and fade for modals
- [x] **FadeInWidget** - Configurable fade-in effects
- [x] **SlideInWidget** - Configurable slide-in effects
- [x] **ShimmerLoading** - Animated shimmer for loading states
- [x] **SuccessAnimation** - Elastic bounce for success feedback

#### Performance & Polish
- [x] **Optimized Animations** - 200-500ms duration for smooth feel
- [x] **Natural Curves** - easeInOutCubic, easeOut, elasticOut
- [x] **Professional Feel** - Polished, app-store ready UI/UX
- [x] **Utilities File** - Central animation management

### Phase 3: Polish & Error States (✅ COMPLETED)

**Date**: October 27, 2025

#### Error State Screens
- [x] **Poor Image Quality Screen** - Actionable error screen with 6 scanning tips
- [x] **No Match Found Screen** - User-friendly error state with alternatives
- [x] **Error Icon Design** - Clear visual indicators for different error types
- [x] **Image Preview** - Show problematic image to user
- [x] **Action Buttons** - Retake, Browse Manually, Search by Condition

#### Help & Tutorial
- [x] **Best Practices Section** - 6 detailed scanning tips with icons
- [x] **Common Issues** - Solutions for 3 common problems
- [x] **App Features Overview** - Guide to 5 main features
- [x] **Medical Disclaimer** - Safety information for users
- [x] **Settings Integration** - Direct access from Help & Support section

#### Performance Metrics
- [x] **Accuracy Display** - 89.23% model accuracy
- [x] **Precision Display** - 87.56% precision
- [x] **Recall Display** - 88.34% recall
- [x] **F1-Score Display** - 87.95% F1-score
- [x] **Metric Explanations** - Detailed descriptions for each metric
- [x] **Model Information** - Architecture and dataset details
- [x] **Visual Cards** - Color-coded 2x2 grid layout

#### Enhanced Error Handling
- [x] **Graceful Failures** - No more cryptic error messages
- [x] **Actionable Feedback** - Users know exactly what to do next
- [x] **Alternative Paths** - Multiple options when scanning fails
- [x] **Localization** - 18+ new strings in English and Filipino

### Phase 2: Browse & Search Features (✅ COMPLETED)

**Date**: October 26, 2025

#### Browse Screen
- [x] **Search Functionality**: Real-time search by name, scientific name, local name, or condition
- [x] **Filter Chips**: All Plants (42), DOH Approved (10), By Condition (15+ categories)
- [x] **Dual View Modes**: Grid view (2 columns) and List view with toggle
- [x] **Plant Count**: Dynamic count indicator
- [x] **Empty States**: Meaningful messages when no results
- [x] **DOH Badges**: Visual indicators for DOH-approved plants
- [x] **Navigation**: Tap to view plant details

#### DOH Approved Plants Screen
- [x] **Official Branding**: DOH header with gradient design
- [x] **Grid Layout**: 2-column grid with 9 DOH plants
- [x] **Verification Badges**: DOH badges on all plant cards
- [x] **Medical Disclaimer**: Safety information section
- [x] **Plant Count Display**: "9 clinically validated" indicator

#### Scan History Screen
- [x] **Chronological List**: All past scans with timestamps
- [x] **Sort Options**: Most Recent, Oldest, Highest Confidence
- [x] **Delete Functionality**: Individual scan deletion with confirmation
- [x] **Clear All**: Delete entire history with confirmation
- [x] **Statistics Dashboard**: Total scans and average confidence
- [x] **Confidence Badges**: Color-coded (green ≥80%, orange ≥60%, red <60%)
- [x] **Empty State**: "Start Scanning" prompt with action button
- [x] **Date Formatting**: Human-readable timestamps (MMM dd, yyyy • HH:mm)

#### Condition-based Search Screen
- [x] **15 Medical Conditions**: Cough, Asthma, Fever, Pain, Diabetes, Hypertension, Diarrhea, Kidney Stones, Wound Healing, Digestive Issues, Skin Conditions, Gout, Respiratory Issues, Inflammation, Fungal Infections
- [x] **Color-coded Cards**: Unique colors and icons per condition
- [x] **Plant Filtering**: Show only plants that treat selected condition
- [x] **Selected Banner**: Display selected condition with plant count
- [x] **Clear Filter**: Easy return to condition selection
- [x] **Relevant Uses**: Highlight matching medicinal uses

#### Localization
- [x] **30+ New Strings**: Added for Browse, History, and Condition Search
- [x] **English & Filipino**: Full translations for all new features
- [x] **Consistency**: Unified terminology across all screens

### Phase 1: Plant Database Population (✅ COMPLETED)

**Date**: October 25, 2025

#### Plant Database Content

- [x] **13 Medicinal Plants Data**: Complete information for 9 DOH-approved + 4 additional plants
- [x] **PlantDataService**: Centralized service with all plant data
- [x] **DatabaseInitService**: Automatic database initialization
- [x] **Database Auto-Population**: Plants loaded on first app launch

#### Comprehensive Plant Information

- [x] **Taxonomy**: Kingdom, Family, Genus, Species for all plants
- [x] **Morphology**: Detailed physical descriptions
- [x] **Ecology**: Distribution, climate, environmental requirements
- [x] **Habitat**: Specific growing conditions and locations
- [x] **Medicinal Uses**: 20+ documented therapeutic applications
- [x] **Active Compounds**: 50+ bioactive compounds documented
- [x] **Preparation Methods**: 15+ traditional recipes with step-by-step instructions
- [x] **Safety Warnings**: Comprehensive contraindications and precautions

#### New UI Screens

- [x] **Plant Detail Screen**: Tabbed interface (Taxonomy, Ecology, Medicinal, Safety)
- [x] **Preparation Instructions Screen**: Step-by-step preparation guide
- [x] **Interactive Navigation**: Clickable preparation methods
- [x] **Safety Information Display**: Medical disclaimers and warnings

#### DOH-Approved Plants Included (10 Official Plants)

- [x] **Akapulko** (Senna alata) - Fungal infections
- [x] **Ampalaya** (Momordica charantia) - Asthma and coughs
- [x] **Bawang** (Allium sativum) - Wounds and toothaches
- [x] **Bayabas** (Psidium guajava) - Wounds and diarrhea
- [x] **Lagundi** (Vitex negundo) - Cough and asthma
- [x] **Niyog-niyogan** (Combretum indicum) - Expelling parasitic worms
- [x] **Sambong** (Blumea balsamifera) - Lowering uric acid and treating hypertension
- [x] **Tsaang Gubat** (Ehretia microphylla) - Stomachaches and diarrhea
- [x] **Ulasimang-bato** (Peperomia pellucida) - Gout and rheumatism
- [x] **Yerba Buena** (Clinopodium douglasii) - Muscle and joint pain, headaches

#### Additional Medicinal Plants

- [x] **Oregano** (Origanum vulgare) - Cough, Respiratory, Digestive
- [x] **Luya/Turmeric** (Curcuma longa) - Inflammation, Digestive Health
- [x] **Gotu Kola** (Centella asiatica) - Wound Healing, Cognitive Support
- [x] **Aloe Vera** (Aloe barbadensis) - Burns, Skin Health

---

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
- [x] **Navigation**: Bottom navigation with 4 tabs (Home, Browse, History, Settings) and center camera FAB; DOH via Home carousel

#### Database Schema

- [x] **Plants Table**: Core plant information (including optional image_url from Supabase)
- [x] **Medicinal Uses Table**: Therapeutic applications
- [x] **Preparation Methods Table**: Traditional preparation instructions
- [x] **Scan History Table**: User scan results and AI predictions
- [x] **Catalog tables** (synced from Supabase): catalog_conditions, catalog_condition_plants, catalog_plant_anatomy, safety_profiles, plant_habitats
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

### Phase 6: Backend API & Documentation (✅ COMPLETED)
- [x] Python FastAPI backend for true Grad-CAM computation
- [x] Backend documentation (`backend/README.md`)
- [x] Model management guides
- [x] Deployment documentation (Railway)
- [x] Postman testing documentation
- [x] Phase 2 model extraction guides
- [x] Offline CAM inference fix

### Phase 7: GradCAM/CAM Fixes & UI Improvements (✅ COMPLETED)
- [x] Fixed all GradCAM and CAM heatmap issues
- [x] Fixed scan persistence with JSON serialization
- [x] Added method labels (CAM/GradCAM/Fallback/Online)
- [x] Enhanced UI visibility across all screens
- [x] Improved feedback form and text areas

### Phase 8: UI/UX Refinement & Camera Enhancements (✅ COMPLETED)
- [x] Enhanced readability and visibility
- [x] Fixed tab navigation
- [x] Optimized image loading
- [x] Added pinch-to-zoom functionality
- [x] Improved visual hierarchy

### Phase 9: Hybrid XAI Explanation System (✅ COMPLETED)
- [x] Implemented explanation system from cache, offline JSON, and fallback only (no live LLM at runtime)
- [x] Created offline explanation database for all 42 plants (expanded from 16)
- [x] Added markdown text formatting
- [x] Implemented usability assessment with clear status indicators
- [x] Added refresh functionality for regenerating explanations
- [x] **Content Standardization** (v0.9.4): Standardized structure with four sections (Taxonomy, Ecology, Medicinal Uses, Safety) - identical format for online and offline

### Phase 10: Beta Testing & Deployment (🔄 In Progress)

**Date**: December 2025

#### Current Status

- [x] **Production Ready**: All core features implemented
- [x] **Testing Framework**: Complete TESTING_GUIDE.md with 50+ test cases
- [x] **Data Collection**: All systems operational for thesis research
- [x] **Hybrid XAI System**: Complete offline/online explanation system
- [ ] **Beta Testing**: User testing with real devices
- [ ] **Data Analysis**: Collect and analyze user feedback
- [ ] **Performance Tuning**: Optimize based on metrics
- [ ] **Final Polish**: Any remaining UI/UX improvements
- [ ] **App Store Preparation**: Final deployment preparation

## 🛠️ Technical Implementation Details

### Architecture

- **Framework**: Flutter 3.9.2+
- **State Management**: Provider pattern with 6 providers (App, Auth, Plant, Camera, Language, Offline)
- **Database**: SQLite with proper relationships
- **AI/ML**: TensorFlow Lite with offline processing, GradCAM visualization, and hybrid XAI explanations
- **Offline Processing**: Add a offline functionality for rural areas
- **GradCAM**: Explainable AI heatmap generation with working interactive visualization and overlay controls
- **XAI Explanations**: Text-based explanations from cache, offline JSON, and fallback only (no live LLM); markdown formatting and usability assessment
- **Connectivity**: Real-time network monitoring with connectivity_plus
- **Localization**: Flutter's built-in i18n system

### Key Dependencies

```yaml
# State Management
provider: ^6.1.2

# Database
sqflite: ^2.4.0
path: ^1.9.0

# Camera & Image Processing
camera: ^0.11.2+1
image_picker: ^1.1.2
image: ^4.5.4

# AI/ML
tflite_flutter: ^0.11.0

# Localization
flutter_localizations:
  sdk: flutter
intl: ^0.20.2

# Connectivity & Offline
connectivity_plus: ^7.0.0

# File and Storage
path_provider: ^2.1.5
shared_preferences: ^2.3.2

# UI Components
flutter_staggered_grid_view: ^0.7.0
shimmer: ^3.0.0
lottie: ^3.3.2

# Utilities
uuid: ^4.5.1
logger: ^2.5.0
http: ^1.2.2

# Markdown Rendering
flutter_markdown: ^0.6.18
```

### File Structure

```
herbascan/
├── lib/                   ✅ (50+ files)
│   ├── core/              ✅
│   │   ├── config/        ✅ (Supabase URL/anon key, auth redirect)
│   │   ├── constants/     ✅ (e.g. condition icons)
│   │   ├── models/        ✅ (Plant, ScanResult, UserFeedback)
│   │   ├── providers/     ✅ (6 providers: App, Auth, Plant, Camera, Language, Offline)
│   │   ├── services/      ✅ (Database, Plant, Offline, GradCAM, XAI Explanation,
│   │   │                     Auth, Herbarium, CatalogSync, Config, Performance, 
│   │   │                     Analytics, Error Logger, Feedback, etc.)
│   │   ├── widgets/       ✅ (Offline indicators, GradCAM visualization, botanical auth header)
│   │   ├── routing/       ✅ (GoRouter – app_router.dart: /, /login, /home, /onboarding, /admin)
│   │   ├── theme/         ✅ (Material Design 3, app_theme.dart – botanical green / Emerald)
│   │   ├── localization/  ✅ (i18n - English/Filipino)
│   │   └── utils/         ✅ (Page transitions, animations)
│   └── features/          ✅ (15+ screens: Home, Scan, Browse, History, DOH,
│                              Settings, Feedback, Dashboard, Help, etc.)
├── assets/                ✅ (models, images, data/plant_explanations.json, animations, icons, fonts)
├── tests/                 ✅ (Testing plans: Unit, Integration, System, Acceptance, Performance, Usability, Compatibility, Security – see TESTING_GUIDE.md and tests/*.md)
└── Configuration          ✅ (pubspec.yaml, analysis_options.yaml)
```

## 🎨 Prototype Design Reference

**Prototype File**: `herbascan_ interactive prototype.html` - Interactive HTML prototype with 22+ wireframes  

### Prototype Status
- **Functional Coverage**: 90%+ of prototype features implemented
- **Visual Design**: 70% matches prototype
- **Main Gaps**: Visual polish (gradients, animations, glassmorphism) rather than functionality

### Design System
- **Theme**: `lib/core/theme/app_theme.dart` – botanical green (Emerald #16A34A), Soft Sage surface, dark Forest Black/slate-green; Indigo→Emerald pivot per CHANGELOG.
- **Prototype reference**: Primary (#6366f1 in prototype; app uses Emerald), Success (#22c55e), Warning (#f59e0b), Error (#ef4444)
- **Typography**: Inter font family (already implemented)
- **Spacing**: Consistent 4px base unit system
- **Shadows**: Multi-layer shadow system
- **Gradients**: Linear gradients for modern look
- **Animations**: Smooth transitions, shimmer effects, slide-in animations

## 🎯 Next Steps

### Immediate (Beta Testing Phase)

1. **User Testing**: Distribute app to beta testers using TESTING_GUIDE.md
2. **Data Collection**: Gather user feedback, performance metrics, and usage analytics
3. **Bug Fixes**: Address any issues found during testing
4. **Performance Optimization**: Fine-tune based on collected metrics
5. **Visual Enhancements**: Apply prototype design system (gradients, animations, glassmorphism)

### Short Term (1-2 weeks)

1. **Data Analysis**: Analyze collected metrics and user feedback for thesis
2. **Performance Tuning**: Optimize based on real-world usage data
3. **Bug Resolution**: Fix any critical issues discovered
4. **Documentation Updates**: Finalize user guides and technical documentation

### Long Term (1-2 months)

1. **Thesis Completion**: Integrate data analysis into thesis write-up
2. **Final Deployment**: Prepare for Google Play Store release
3. **App Store Submission**: Complete store listing and metadata
4. **Post-Launch Support**: Monitor app performance and user feedback

## 📊 Progress Metrics

- **Version**: v0.9.4
- **Code Files Created**: 50+ files
- **Lines of Code**: 10,000+ lines
- **Features Implemented**: 45+ core features
- **Screens Created**: 19 screens
- **Providers**: 6 state management providers (App, Auth, Plant, Camera, Language, Offline)
- **Services**: Database, Plant, Offline, GradCAM, XAI Explanation, Auth, Herbarium, CatalogSync, Config, Performance, Analytics, Error Logger, Feedback, and others
- **Models**: 3 data models (Plant, ScanResult, UserFeedback)
- **Database Tables**: SQLite with 9 tables—plants, medicinal_uses, preparation_methods, scan_history, catalog_conditions, catalog_condition_plants, safety_profiles, plant_habitats, catalog_plant_anatomy (catalog tables synced from Supabase when online)
- **Plant Database**: 42 medicinal plants (10 DOH-approved + 32 additional)
- **Languages Supported**: 2 (English, Filipino)
- **Documentation Files**: 20+ comprehensive documentation files
- **Test Cases**: 50+ test cases documented

## 📊 Data Collection for Thesis Research

HerbaScan includes comprehensive data collection capabilities designed for academic research and thesis analysis:

### User Feedback
- **5-Star Rating System**: Quantitative satisfaction ratings
- **6 Feedback Categories**: AI Accuracy, Usability, Performance, Features, Bugs, General
- **Qualitative Comments**: Open-ended feedback (500 characters)
- **Feature Suggestions**: Improvement ideas from users

### Performance Metrics
- **Operation Timing**: App start, image capture, AI inference, GradCAM generation
- **Statistics**: Average, min, max, median for each operation
- **Automatic Logging**: All metrics saved automatically
- **Export Format**: JSON export for analysis

### Usage Analytics
- **Scan Tracking**: Total, successful, failed, poor quality, no match
- **Success Rate**: Automatic calculation of AI accuracy
- **Feature Usage**: Track plants viewed, preparations viewed, screens accessed
- **Plant Analytics**: Most scanned plants ranking
- **Condition Analytics**: Most searched medical conditions
- **Install Analytics**: First launch date, days since install

### Error Logging
- **8 Error Types**: Categorized error logging (camera, AI, database, network, etc.)
- **Stack Traces**: Optional detailed error information
- **Context Data**: Additional metadata for debugging
- **Error Statistics**: Total errors, errors by type, last 24h

### Export Capabilities
- **Performance Dashboard**: Centralized view with export all functionality
- **JSON Format**: Complete data export for thesis analysis
- **Statistics & Raw Data**: Both summary and detailed data included

All data is stored locally and can be exported as JSON for thesis research purposes.

## 🌐 Offline Processing Capabilities

HerbaScan is designed to work seamlessly in rural areas without internet connectivity, making it perfect for underserved communities in the Philippines.

### Offline Functionality

- **Offline AI Processing**: Complete plant identification functionality without internet using TensorFlow Lite models
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

### Recent Changes (Version v0.9.4 – March 2026)

**CHANGELOG.md** is the authoritative change log; this README is kept in sync with it. Summary:

- **UI/UX Redesign**: Design system (Emerald botanical green, app_theme.dart); Splash (solid background, linear loader); Onboarding (de-jargonified); Home (BottomAppBar, center FAB, DOH carousel); Browse (SearchBar, SegmentedButton, condition banner); Scan (edge-to-edge, reticle, tips sheet); Plant Result (Insights + AI Vision tabs, glassmorphic hero); Plant Detail (SliverAppBar hero, Quick Facts); History (TabBar, device cards, select mode, swipe export/delete, batch sync/download); Settings (grouped cards, Account block); DOH and Help redesigns; Auth/OTP (botanical header, pinput 6-box); Condition Search (directory + ConditionResultsScreen); Habitat Map; Preparation Guide and Focus Mode; System Diagnostics (renamed from Offline Demo); admin polish (instant local sync, condition count sync, user management crash fix).
- **Heatmap in cloud**: Upload stores heatmap as `{scan_id}_gradcam.jpg` in Storage; metadata `gradcam_url`; download restores `gradCAMPath`.
- **Scan History**: Swipe between Device & Cloud tabs; pull-to-refresh on Cloud; select mode with batch sync (Device → Cloud, Cloud → Device); Select all / Deselect all; save/export from Plant Result screen only (and History device card export to gallery).
- **Auth & Account**: Signup 6-digit confirmation; duplicate email handling; stronger password rules; change password with live requirements; delete account (Settings → Account); account deactivation by admin (sign-out with message); friendly auth error messages; 6-digit OTP password reset and auth deep links.
- **Preparation Guide**: Renamed from Instructions; interactive checklist and contextual timers; timer notifications and persistence (SharedPreferences, flutter_local_notifications); Focus Mode; calendar add-to-device with pre-fill.
- **Safety & XAI**: Contraindication Engine (safety_profiles.json); no live LLM – explanations from cache/offline/fallback only; Summary tab fixes and taxonomy formatting.
- **Admin**: Cloud-first catalog sync; instant local sync after catalog/condition/plant save; condition list plant count 1:1 with browse; Plant Metadata (6-tab editor, including Anatomy); Condition Search management; Factory Reset; 2D plant anatomy; Image Review and User Management; admin on Windows and mobile; RLS via `is_admin()`.
- **Auto-save Scans:** Settings toggle (key `auto_save_scans`); when OFF, new scans are not auto-saved to History until user uses Save from Plant Result or History.
- **Admin User Management:** ListTile row layout (email + role badge on title line, metadata as subtitle); admin avatar/badge contrast fix in light mode; **Force activate email** (OTP bypass) via `force-verify-user` Edge Function; **Make admin / Remove admin** via `AdminUserService.setRole`.
- **Admin Plant Catalog Editor:** Sixth tab **Anatomy** for 2D silhouette CRUD; multiline/no horizontal scroll for Safety, Medicinal Use, and Preparation Method fields; instant local sync after saves.
- **Interactive Plant Anatomy:** DefaultAnatomyService + `default_plant_anatomy.json`; Plant Detail "Explore Plant Parts" multi-part carousel when multiple anatomy parts exist.
- **Labels & models**: App uses `assets/models/class_indices.json` (name→index); offline CAM uses `mobilenetv2_multi_output.tflite`. No `labels.txt`.
- **Settings & Offline**: De-jargonified AI labels (e.g. "Show Prediction Confidence", "Show AI Reasoning Heatmap"); Offline Storage Info refreshes before dialog; System Diagnostics (renamed from Offline Demo).
- **SnackBar**: Floating behavior so camera FAB is not displaced.
- **Backend**: Railway `/identify` allows unauthenticated requests when `SUPABASE_JWT_SECRET` unset; see supabase/README.md and backend/README.md.
- **Testing plans**: `tests/` folder (Unit, Integration, System, Acceptance, Performance, Usability, Compatibility, Security); see TESTING_GUIDE.md and tests/*.md.
- **Version**: All app version references set to v0.9.4.

### Known Issues

- **AI Model Accuracy**: May need improvement with more training data
- **GradCAM Visualization**: Needs refinement for better explainability (marked as "Needs Improvement" in docs)
- **Performance Optimization**: Final mobile deployment optimization pending based on real-world usage data

### Recently Fixed

- ✅ **Offline CAM Inference**: Fixed multiple output buffers shape mismatch error (v0.5.2)
- ✅ **TFLite Multiple Outputs**: Corrected output buffer passing using `runForMultipleInputs()` with output map
- ✅ **Feature Maps Extraction**: Verified correct extraction of `[1, 7, 7, 1280]` feature maps
- ✅ **Predictions Extraction**: Verified correct extraction of `[1, 40]` predictions from 2D buffer

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
- 🏥 **DOH Integration**: Access to 10 DOH-approved herbal medicines + 32 additional medicinal plants (42 total)
- 🔍 **Explainable AI**: GradCAM visualization shows how the AI identifies plants with interactive heatmaps
- 🌐 **Multi-language Support**: English and Filipino language options
- 📊 **Confidence Scoring**: Shows prediction confidence levels
- 📚 **Comprehensive Database**: Detailed plant information including taxonomy, morphology, ecology, and medicinal uses
- 🔎 **Browse & Search**: Advanced search, filtering, and condition-based browsing
- 📜 **Scan History**: Complete history management with sorting and statistics
- 📝 **User Feedback**: 5-star rating system with categories and comments
- 📈 **Performance Monitoring**: Automatic tracking of app performance metrics
- 📊 **Usage Analytics**: Track scans, success rates, and feature usage
- 🐛 **Error Logging**: Comprehensive error tracking and reporting
- 📉 **Performance Dashboard**: View all metrics in one place
- 🧪 **Testing Framework**: Complete testing guide with 50+ test cases

## Setup Instructions

### Prerequisites

1. **Flutter SDK**: Install Flutter 3.9.2 or later

   - Download from: https://flutter.dev/docs/get-started/install
   - Add Flutter to your PATH environment variable
   - Verify installation: `flutter doctor`

2. **Android Studio**: For Android development

   - Download from: https://developer.android.com/studio
   - Install Android SDK (API level 21 or higher)
   - Create an Android Virtual Device (AVD) or enable USB debugging on physical device

3. **VS Code** (Recommended): For Flutter development
   - Install Flutter and Dart extensions
   - Use `Ctrl+Shift+P` → "Flutter: Select Device" to choose device

4. **No API key required for XAI**: Explanations come from cache, offline JSON, and fallback only (no live LLM at runtime).

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

4. **XAI explanations**: No API key needed. The app uses cache, offline `plant_explanations.json`, and fallback text only (no live LLM).

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
- ✅ Android integration (fully functional)
- ✅ Offline processing (complete offline AI inference)
- ✅ Performance Metrics: Accuracy 89.23%, Precision 87.56%, Recall 88.34%, F1-Score 87.95%
- ✅ **Backend API**: Python FastAPI server for true Grad-CAM computation (ready to deploy)
- ✅ **Backend Documentation**: Comprehensive guides for model management, deployment, and testing

### Backend API (Python FastAPI)

HerbaScan includes a Python backend API for true gradient-based Grad-CAM computation:

**Location**: `backend/` directory

**Features**:
- ✅ FastAPI server with 4 endpoints (/, /health, /test, /identify)
- ✅ True Grad-CAM implementation using TensorFlow GradientTape
- ✅ Docker configuration for Railway deployment
- ✅ Comprehensive documentation (`backend/README.md`)
- ✅ Postman collection for API testing
- ✅ Model management guides

**Documentation**:
- **Backend README**: `backend/README.md` - Complete backend documentation (1,500+ lines)
- **Quick Start**: `backend/QUICK_START.md` - Fast deployment guide
- **Deployment Guide**: See `backend/README.md` → "🚀 Deployment to Railway"
- **Model Management**: See `backend/README.md` → "🔄 Updating Models"
- **Phase 2 Guide**: See `backend/README.md` → "Phase 2: Model Extraction & Conversion"
- **Postman Testing**: See `backend/README.md` → "🧪 Testing with Postman"

**Key Features**:
- **Model Management**: Complete guide for updating models in backend and Flutter assets
- **Phase 2 Scripts**: Detailed instructions for `extract_cam_weights.py` and `create_multi_output_tflite.py`
- **Railway Deployment**: Step-by-step deployment guide with troubleshooting
- **Postman Testing**: Comprehensive testing guide for VS Code and other IDEs

**Quick Links**:
- Model Updates: `backend/README.md` → "🔄 Updating Models"
- Deployment: `backend/README.md` → "🚀 Deployment to Railway"
- Testing: `backend/README.md` → "🧪 Testing with Postman"
- Phase 2: `backend/README.md` → "Phase 2: Model Extraction & Conversion"

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
   - `mobilenetv2_feature_extractor.tflite` (CNN feature extractor)
   - `random_forest_distilled.tflite` (Random Forest classifier)
   - `labels.json` (JSON format)
   - `labels.txt` (Class labels - one per line)

### Phase 2: Model Extraction for Offline CAM

After converting your model, you need to extract CAM weights and create a multi-output TFLite model for offline CAM computation in the Flutter app.

**For detailed instructions, see:**
- **`backend/README.md`** → "Phase 2: Model Extraction & Conversion"
- **Scripts**: `backend/extract_cam_weights.py` and `backend/create_multi_output_tflite.py`

**Quick Workflow**:
1. Extract CAM weights: `python backend/extract_cam_weights.py`
2. Create multi-output TFLite: `python backend/create_multi_output_tflite.py`
3. Copy to Flutter assets: `cp backend/models/cam_weights.json assets/models/`
4. Update `pubspec.yaml` with new assets

**For complete workflow, see `backend/README.md` → "Phase 2: Model Extraction & Conversion"**

## Database Schema

The app uses SQLite for local data storage with the following tables:

- **plants**: Plant information and metadata (optional image_url from Supabase)
- **medicinal_uses**: Medicinal applications for each plant
- **preparation_methods**: Traditional preparation instructions
- **scan_history**: User scan results and AI predictions
- **Catalog tables** (synced from Supabase when online): safety_profiles, plant_habitats, catalog_conditions, catalog_condition_plants, catalog_plant_anatomy

## DOH-Approved Plants

The app includes comprehensive information about all 10 official DOH-approved herbal medicines (plus 6 additional medicinal plants):

1. **Akapulko** (Senna alata) - Fungal infections
2. **Ampalaya** (Momordica charantia) - Asthma and coughs
3. **Bawang** (Allium sativum) - Wounds and toothaches
4. **Bayabas** (Psidium guajava) - Wounds and diarrhea
5. **Lagundi** (Vitex negundo) - Cough and asthma
6. **Niyog-niyogan** (Combretum indicum) - Expelling parasitic worms
7. **Sambong** (Blumea balsamifera) - Lowering uric acid and treating hypertension
8. **Tsaang Gubat** (Ehretia microphylla) - Stomachaches and diarrhea
9. **Ulasimang-bato** (Peperomia pellucida) - Gout and rheumatism
10. **Yerba Buena** (Clinopodium douglasii) - Muscle and joint pain, headaches

### Additional Medicinal Plants (6)
11. **Oregano** (Origanum vulgare) - Cough, Respiratory, Digestive
12. **Luya/Turmeric** (Curcuma longa) - Inflammation, Digestive Health
13. **Gotu Kola** (Centella asiatica) - Wound Healing, Cognitive Support
14. **Aloe Vera** (Aloe barbadensis) - Burns, Skin Health
15. **Malunggay** (Moringa oleifera) - Nutrition
16. **Tawa-tawa** (Euphorbia hirta) - Dengue fever support

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

- [x] Plant database population (13 plants)
- [x] Search and filtering (multi-field search, condition-based)
- [x] Scan history management (sort, delete, statistics)
- [x] Error handling and help system
- [x] Performance metrics display

### Phase 4: Final Polish ✅

- [x] UI/UX refinements (animations, transitions, tips)
- [x] Camera UI enhancements (bottom sheet, tips button)
- [x] Loading animations (shimmer effects)
- [x] Page transition animations
- [x] Professional polish and app-store ready UI

### Phase 5: Testing & Optimization ✅

- [x] User feedback system
- [x] Performance monitoring
- [x] Usage analytics
- [x] Error logging
- [x] Performance dashboard
- [x] Testing framework and documentation

### Phase 6: Backend API & Documentation ✅

- [x] Python FastAPI backend for true Grad-CAM computation
- [x] Backend documentation (`backend/README.md`)
- [x] Model management guides
- [x] Deployment documentation (Railway)
- [x] Postman testing documentation
- [x] Phase 2 model extraction guides
- [x] **Offline CAM inference fix** - Fixed multiple output buffers shape mismatch
- [x]] Backend deployment to Railway (pending user action)
- [ x] Full offline CAM testing verification

### Phase 7: Beta Testing & Deployment 🔄

- [x] Production-ready app
- [x] Backend API ready for deployment
- [x]] Backend deployment to Railway
- [ ] Beta testing with users
- [ ] Data collection and analysis
- [ ] Final performance optimization
- [ ] App store preparation

## 📚 Documentation

**CHANGELOG.md** is the authoritative source for detailed change history and should be kept up to date with every release.

### Main Documentation Files
- **README.md** (this file) - Project overview and setup
- **setup.md** - Flutter setup instructions

### Backend Documentation
- **backend/README.md** - Complete backend documentation (1,500+ lines)
  - Model management and updates
  - Phase 2 model extraction
  - Railway deployment guide
  - Postman testing guide
  - Troubleshooting
- **backend/QUICK_START.md** - Quick deployment guide


### Testing Documentation
- **TESTING_GUIDE.md** - User testing guide (50+ test cases)
- **backend/HerbaScan_API.postman_collection.json** - Postman collection for API testing

### Key Documentation Sections
- **Model Management**: `backend/README.md` → "🔄 Updating Models"
- **Phase 2 Process**: `backend/README.md` → "Phase 2: Model Extraction & Conversion"
- **Deployment**: `backend/README.md` → "🚀 Deployment to Railway"
- **Postman Testing**: `backend/README.md` → "🧪 Testing with Postman"
- **Troubleshooting**: `backend/README.md` → "🐛 Troubleshooting"

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


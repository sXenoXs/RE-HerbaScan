# HerbaScan - AI-Powered Plant Identification App

**Thesis Project**: HERBASCAN: A CONVOLUTIONAL NEURAL NETWORK-BASED MOBILE APPLICATION FOR PLANT IDENTIFICATION AND HERBAL MEDICINE INFORMATION

HerbaScan is a Flutter-based mobile application that uses a MobileNetV2 Convolutional Neural Network to identify Philippine medicinal plants fully offline. The app provides comprehensive information about DOH-approved herbal medicines and supports offline processing for rural areas.

**Academic Context**: Undergraduate Thesis — College of Information Technology and Computer Science, Lyceum of the Philippines University-Cavite  
**Client/Partner**: Integrative Medicine for Alternative Healthcare Systems (INAM) Philippines  
**Dataset**: PhilMedic — 4,922 leaf images, medicinal plant classes native to the Philippines  

---

## Current Development Status

**Version**: v1.0.31  
**Last Updated**: June 27, 2026  
**Overall Progress**: 100% Complete — **PRODUCTION READY**

---

## Key Features

### Offline-First Plant Identification (MobileNetV2)
- **Fully Offline**: On-device TFLite inference powered by a 31-class MobileNetV2 model.
- **Two-Stage Quality Gate**: Prevents poor inferences by checking brightness, blur, and edge density before running a confidence gate threshold.
- **Safety First**: Deterministic XAI explanations and a dedicated Toxic Plant Blacklist warning screen for dangerous flora (e.g., Adelfa, Ipil-Ipil).

### Comprehensive Plant Knowledge Base
- **Rich Catalog**: Supports 30 medicinal plants, including 10 official DOH-approved varieties.
- **Interactive Guides**: Detailed Preparation Guides with contextual timers, Focus Mode, and interactive 2D Plant Silhouettes.
- **Contraindication Engine**: Warns users of strict medical contraindications natively.

### Secure Authentication & Cloud Sync
- **Supabase Auth**: Secure email/password login with a bulletproof 6-digit OTP bypass flow and realtime role-change notices.
- **Personal Herbarium**: Seamlessly sync local SQLite scan histories with the cloud.

### Robust Admin Management Portal
- **Web & Mobile Ready**: Deployable on Vercel with strict security headers, or manageable natively on mobile.
- **Fleet Management**: Remote Config Editor, Data Deletion Requests, User Management, and Feedback Status tracking.
- **Image Tracer**: In-app Figma-style interactive UI to create dynamic plant anatomy SVGs.

---

## Tech Stack & Architecture

- **Mobile Framework**: Flutter (Dart)
- **Local Database**: SQLite (`sqflite` on mobile, `sqflite_common_ffi` on desktop)
- **Cloud Database & Auth**: Supabase (PostgreSQL, Storage, Edge Functions)
- **AI/ML**: TensorFlow Lite (`tflite_flutter`)
- **Backend (Retraining Pipeline)**: Python FastAPI on Railway (Used *only* for model retraining, not for live scanning)

---

## Getting Started

### Prerequisites
1. **Flutter SDK** (3.9.2 or later)
2. **Android Studio** (Android SDK API 21+) or **VS Code**

### Installation
```bash
git clone <repository-url>
cd RE-HerbaScan
flutter pub get
flutter run
```

---

## Documentation Hub

For deep technical details, please refer to our dedicated documentation files:

- **[CHANGELOG](CHANGELOG.md)**: Detailed version history and recent updates.
- **[Setup Guide](setup.md)**: Full local environment setup, IDE configuration, and troubleshooting.
- **[Supabase Setup](supabase/README.md)**: Database schemas, migrations, storage buckets, and Edge Functions.
- **[Backend API & Retraining](backend/README.md)**: Details on the Python FastAPI retraining pipeline and Modal GPU triggers.
- **[Backend Quick Start](backend/QUICK_START.md)**: 15-minute Railway deployment guide for the ML backend.

---

## Contributing
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Submit a pull request

---

## License
This project is part of an undergraduate thesis at Lyceum of the Philippines University-Cavite.

> **Note**: This app is for educational and informational purposes only. Always consult healthcare professionals before using any herbal remedies.

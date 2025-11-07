# TractorCare - Predictive Maintenance for Agricultural Tractors

TractorCare is a hybrid machine learning system designed for the early detection of tractor engine failures using acoustic analysis. It combines rule-based maintenance scheduling with AI-powered audio anomaly detection, specifically tailored for smallholder farmers in Rwanda. This project aims to improve tractor reliability, reduce downtime, and enhance agricultural productivity through affordable, accessible technology.

** Our Mission:** Revolutionize agricultural equipment maintenance in Rwanda through intelligent sound analysis and predictive insights.

---

##  Table of Contents

- [ Machine Learning Journey](#-machine-learning-journey)
- [ Core Achievements](#-core-achievements)
- [ System Architecture](#️-system-architecture)
- [ Key Features](#-key-features)
- [ Installation](#-installation)
- [ Running the Application](#-running-the-application)
- [ Project Structure](#-project-structure)
- [ Important Links](#-important-links)
- [ Deployment](#-deployment)
- [ Troubleshooting](#️-troubleshooting)

---

##  Machine Learning Journey

### Phase 1: Foundation Training with MIMII Dataset

**Starting Point: Industrial Pump Sound Analysis**
- **Dataset:** MIMII (Malfunctioning Industrial Machine Investigation and Inspection)
- **Samples:** 912 balanced audio recordings (456 normal, 456 abnormal)
- **Duration:** 10 seconds per sample at 16kHz sampling rate
- **Format:** WAV files with consistent audio properties

**Why Start with Pumps?**
Pumps and tractor engines share similar mechanical characteristics:
- Rotating machinery with bearings and gears
- Predictable failure patterns (wear, vibration, misalignment)
- Similar acoustic signatures for anomaly detection
- Abundant labeled industrial data for baseline training

### Phase 2: Feature Engineering & Model Comparison

**Feature Extraction Pipeline:**
- **Primary Features:** 40 MFCC (Mel-Frequency Cepstral Coefficients)
- **Preprocessing:** High-Pass Filter (100 Hz cutoff) to reduce background noise
- **Representation:** Fixed-length 40×100 frames per audio sample
- **Window Function:** Hamming window with 2048 sample frames, 512 hop length

**Model Architecture Comparison (6 Models Tested):**

| Model | Type | Accuracy | Precision | Recall | F1-Score | Key Strengths |
|-------|------|----------|-----------|--------|----------|---------------|
| **K-Nearest Neighbors** | Traditional ML | 95.08% | 100.00% | 90.43% | 94.97% | Perfect precision, simple implementation |
| **Support Vector Machine** | Traditional ML | 95.63% | 100.00% | 91.49% | 95.56% | Excellent generalization, robust to outliers |
| **Isolation Forest** | Unsupervised | 43.17% | 44.32% | 41.49% | 42.86% | No labeled data needed (limited performance) |
| **Basic CNN** | Deep Learning | 86.89% | 83.02% | 93.62% | 88.00% | Good feature learning, fast inference |
| **VGG-like CNN** | Deep Learning | 91.26% | 94.32% | 88.30% | 91.21% | Deeper features, batch normalization |
| **ResNet-like CNN** | Deep Learning | 92.90% | 100.00% | 86.17% | 92.57% | **SELECTED** - Residual connections, transfer learning ready |

### Phase 3: Transfer Learning to Real Tractor Sounds

**Challenge:** Industrial pump sounds ≠ Real tractor engine sounds

**Solution: Transfer Learning Approach**
1. **Pre-trained Model:** ResNet-like CNN trained on MIMII pump dataset
2. **Target Dataset:** Real tractor sounds collected from Freesound platform
3. **Technique:** Early layer freezing with reduced learning rates
4. **Result:** Significant improvement in real-world tractor anomaly detection

**Why ResNet-like CNN was Selected:**
-  **Perfect Precision (100.00%):** Critical for cost-effective maintenance scheduling
-  **Strong F1-Score (92.57%):** Balanced precision and recall
-  **Residual Connections:** Enhanced generalization for transfer learning
-  **Transfer Learning Ready:** Architecture suitable for domain adaptation
-  **Cloud Deployment Optimized:** Acceptable computational trade-offs

### Phase 4: Production Model Integration

**Model Deployment Pipeline:**
- **Format:** TensorFlow/Keras model (.h5 format)
- **Inference Service:** FastAPI backend with real-time processing
- **Audio Processing:** Automatic MFCC extraction and normalization
- **Response Format:** Anomaly probability scores with confidence intervals

---

##  Core Achievements

###  Technical Achievements

**1. Successful Transfer Learning Pipeline**
- ✅ Trained ResNet-like CNN on industrial pump dataset (MIMII)
- ✅ Successfully adapted model to real tractor engine sounds
- ✅ Achieved 92.90% accuracy with 100% precision on validation set
- ✅ Implemented real-time audio processing and MFCC feature extraction

**2. Hybrid Maintenance System**
- ✅ Rule-based scheduling for routine maintenance (oil changes, filters)
- ✅ AI-powered anomaly detection for unexpected failures
- ✅ Combined approach provides comprehensive predictive maintenance

**3. Complete End-to-End Solution**
- ✅ Mobile app for farmers with offline-first architecture
- ✅ Web platform for demonstrations and marketing
- ✅ Cloud-based API with ML model serving
- ✅ Real-time audio recording and analysis

###  Application Features Implemented

**Mobile Application (Flutter)**
- ✅ **Tractor Management:** Add, edit, and track multiple tractors
- ✅ **Audio Recording:** High-quality audio capture with real-time processing
- ✅ **Baseline Collection:** Establish healthy engine sound profiles
- ✅ **Test Sound Analysis:** Compare current recordings against baselines
- ✅ **Maintenance Scheduling:** Rule-based and AI-triggered maintenance alerts
- ✅ **Usage Tracking:** Log daily tractor usage and operating hours
- ✅ **Prediction History:** View past anomaly detection results with timestamps
- ✅ **Dashboard Analytics:** Visual charts of usage patterns and maintenance trends
- ✅ **Calendar Integration:** Schedule and track maintenance activities
- ✅ **Offline Support:** Core functionality works without internet connection

**Web Platform (Next.js)**
- ✅ **Public Demo:** Upload audio files for instant AI analysis
- ✅ **Product Information:** Comprehensive feature showcases
- ✅ **Educational Content:** How the system works and benefits
- ✅ **Responsive Design:** Works on desktop, tablet, and mobile devices

**Backend API (FastAPI)**
- ✅ **JWT Authentication:** Secure user registration and login
- ✅ **Tractor Management:** CRUD operations for tractor data
- ✅ **Audio Processing:** Real-time ML inference with MFCC extraction
- ✅ **Baseline Management:** Store and compare healthy engine profiles
- ✅ **Maintenance Scheduling:** Automated alerts and manual scheduling
- ✅ **Usage Analytics:** Track operating hours and generate insights
- ✅ **Real-time Predictions:** Instant anomaly detection with confidence scores
- ✅ **Database Integration:** MongoDB for scalable data storage

###  User Experience Innovations

**1. Baseline-Driven Analysis**
- **Concept:** Establish "healthy" sound profile for each tractor
- **Implementation:** Users record 3-5 baseline samples when tractor is in good condition
- **Benefit:** Personalized anomaly detection based on each tractor's unique characteristics
- **Accuracy Improvement:** Baseline comparison significantly reduces false positives

**2. Progressive Web App Features**
- **Offline-First Design:** Core functionality works without internet
- **Smart Caching:** Stores baseline profiles and predictions locally
- **Sync When Online:** Automatically uploads data when connection is available
- **Rural-Friendly:** Designed for areas with intermittent connectivity

**3. Intuitive Audio Analysis**
- **One-Tap Recording:** Simple interface for capturing engine sounds
- **Real-Time Feedback:** Instant visual indicators during recording
- **User-Friendly Results:** Anomaly scores displayed as percentages with plain language explanations
- **Historical Tracking:** View trends and patterns over time

---

##  System Architecture

### Hybrid Approach: Rule-Based + AI

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Rule-Based    │    │   AI-Powered    │    │   Combined      │
│   Maintenance   │    │   Anomaly       │    │   Intelligence  │
│                 │    │   Detection     │    │                 │
│ • Oil Changes   │    │ • Audio Analysis│    │ • Comprehensive │
│ • Filter Checks │ +  │ • MFCC Features │ =  │   Maintenance   │
│ • Scheduled     │    │ • ResNet CNN    │    │ • Predictive    │
│   Services      │    │ • Real-time     │    │   Insights      │
│                 │    │   Processing    │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

**Why Hybrid Approach?**
- **Rule-Based Systems:** Handle routine, time-based maintenance (oil changes, filter replacements)
- **AI Analysis:** Detect unexpected failures and emerging problems
- **Combined Power:** Neither approach alone provides complete coverage
- **Cost Effective:** Prevents both routine neglect and catastrophic failures



##  Key Features

###  Audio Analysis & Baseline System

**Baseline Collection Process:**
1. **Initial Setup:** Record 3-5 samples when tractor is in perfect condition
2. **Quality Validation:** System ensures recordings meet quality standards
3. **Profile Creation:** AI creates unique acoustic fingerprint for each tractor
4. **Continuous Learning:** Baseline evolves with tractor's normal aging process

**Test Sound Analysis:**
- **One-Click Recording:** Simple interface for capturing current engine state
- **Real-Time Processing:** Instant comparison against established baseline
- **Anomaly Scoring:** Percentage-based anomaly likelihood (0-100%)
- **Trend Analysis:** Historical view of engine health over time

###  Dashboard & Analytics

**Real-Time Insights:**
- **Usage Patterns:** Daily/weekly/monthly operating hour trends
- **Maintenance Schedule:** Upcoming and overdue maintenance alerts
- **Health Monitoring:** Engine condition trends with predictive warnings
- **Cost Tracking:** Maintenance expenses and ROI analysis

**Visual Analytics:**
- **Bar Charts:** Daily usage patterns with live data integration
- **Trend Lines:** Engine health progression over time
- **Alert Indicators:** Color-coded status for immediate attention items
- **Calendar View:** Maintenance schedule with drag-and-drop functionality

###  Maintenance Management

**Intelligent Scheduling:**
- **Rule-Based Alerts:** Automatic scheduling based on operating hours
- **AI-Triggered Maintenance:** Anomaly detection triggers preventive actions
- **Custom Reminders:** User-defined maintenance tasks and intervals
- **Vendor Integration:** Contact information and service history tracking

**Maintenance Records:**
- **Complete History:** Detailed logs of all maintenance activities
- **Photo Documentation:** Before/after photos with timestamp and location
- **Cost Tracking:** Parts, labor, and total expense monitoring
- **Warranty Management:** Track warranties and service agreements

###  User Experience Features

**Offline-First Design:**
- **Local Storage:** Critical data cached for offline access
- **Sync Management:** Automatic synchronization when connection available
- **Conflict Resolution:** Smart handling of offline/online data conflicts
- **Performance:** Fast loading and responsive interface

**Accessibility & Localization:**
- **Multi-Language Support:** Kinyarwanda, English, French
- **Voice Instructions:** Audio guides for illiterate users
- **Large Touch Targets:** Designed for field use with gloves
- **High Contrast Mode:** Visibility in bright sunlight

---

## 🔧 Installation

### Prerequisites

Ensure the following are installed on your development system:

| Requirement | Version | Download Link |
|-------------|---------|---------------|
| **Python** | 3.9+ | [Download](https://www.python.org/downloads/) |
| **Node.js** | 18+ | [Download](https://nodejs.org/) |
| **Flutter** | 3.0+ | [Download](https://flutter.dev/docs/get-started/install) |
| **Git** | Latest | [Download](https://git-scm.com/downloads) |
| **MongoDB** | 5.0+ | [Download](https://www.mongodb.com/try/download/community) |

### Step 1: Clone the Repository

```bash
git clone https://github.com/Joh-Ishimwe/tractorcare.git
cd tractorcare
```

### Step 2: Backend Setup (FastAPI + ML Model)

#### 2.1 Create Python Virtual Environment

**Windows:**
```bash
cd tractorcare-backend
python -m venv tractorcarenv
tractorcarenv\Scripts\activate
```

**macOS/Linux:**
```bash
cd tractorcare-backend
python3 -m venv tractorcarenv
source tractorcarenv/bin/activate
```

#### 2.2 Install Dependencies

```bash
pip install -r requirements.txt
```

#### 2.3 Configure Environment Variables

Create `.env` file in `tractorcare-backend/` directory:

```env
# Database Configuration
MONGO_URL=mongodb://localhost:27017
DATABASE_NAME=tractorcare_db

# Security Configuration
SECRET_KEY=your-secure-secret-key-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=43200

# CORS Configuration (comma-separated)
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000

# Application Settings
ENVIRONMENT=development
DEBUG=True
LOG_LEVEL=INFO

# File Upload Settings
MAX_FILE_SIZE=10485760  # 10MB
UPLOAD_FOLDER=uploads
```

**Security Note:** Generate a secure secret key:
```python
import secrets
print(secrets.token_urlsafe(32))
```

### Step 3: Web Frontend Setup (Next.js)

```bash
cd "info web"
npm install
```

**Environment Configuration:**
Create `.env.local` in `info web/` directory:
```env
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

### Step 4: Mobile App Setup (Flutter)

```bash
cd tractorcare_app
flutter pub get
flutter precache --web  # For web support
```

**Configuration:**
Update `lib/config/app_config.dart` with your API endpoint:
```dart
static const String baseUrl = 'http://localhost:8000';  # Development
// static const String baseUrl = 'https://your-api-domain.com';  # Production
```

### Step 5: Database Setup

**Option A: Local MongoDB**
1. Install and start MongoDB locally
2. Database will be created automatically on first run

**Option B: MongoDB Atlas (Recommended for Production)**
1. Create account at [MongoDB Atlas](https://www.mongodb.com/atlas)
2. Create cluster and get connection string
3. Update `MONGO_URL` in `.env` file

---

##  Running the Application

### 1. Start Backend API

```bash
cd tractorcare-backend
# Activate virtual environment
source tractorcarenv/bin/activate  # Linux/Mac
# or
tractorcarenv\Scripts\activate     # Windows

# Start the API server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Verify Backend:**
- API: http://localhost:8000
- Interactive Docs: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

### 2. Start Web Frontend

```bash
cd "info web"
npm run dev
```

**Access Web Platform:** http://localhost:3000

### 3. Run Mobile Application

**For Web Testing:**
```bash
cd tractorcare_app
flutter run -d chrome
```

**For Mobile Development:**
```bash
# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios

# Connected device
flutter devices  # List available devices
flutter run       # Run on default device
```

### 4. Testing the Complete System

**Test Flow:**
1. **Backend Health:** Visit http://localhost:8000/health
2. **Web Demo:** Upload audio file at http://localhost:3000
3. **Mobile App:** 
   - Register/Login
   - Add a tractor
   - Collect baseline samples
   - Test audio recording and analysis

---

##  Project Structure

```
tractorcare/
│
├──  Notebook/                    # ML Experiments & Research
│   ├── ML_experiments.ipynb        # Complete ML pipeline: training → transfer learning
│   └── data/                       # Training datasets (MIMII + Tractor sounds)
│
├──  tractorcare-backend/         # FastAPI Backend + ML Serving
│   ├── app/
│   │   ├── core/                   # Core configuration
│   │   │   ├── config.py           # Environment settings
│   │   │   ├── database.py         # MongoDB connection
│   │   │   └── security.py         # JWT authentication
│   │   ├── middleware/             # Custom middleware
│   │   │   └── security.py         # CORS, security headers
│   │   ├── models/                 # Database models (Beanie ODM)
│   │   │   ├── user.py             # User authentication model
│   │   │   ├── tractor.py          # Tractor management model
│   │   │   ├── audio_prediction.py # Audio analysis results
│   │   │   ├── maintenance.py      # Maintenance records
│   │   │   └── baseline.py         # Baseline audio profiles
│   │   ├── routes/                 # API endpoints
│   │   │   ├── auth.py             # Authentication (register, login, profile)
│   │   │   ├── tractors.py         # Tractor CRUD operations
│   │   │   ├── audio.py            # Audio upload & ML inference
│   │   │   ├── baseline.py         # Baseline collection & management
│   │   │   ├── maintenance.py      # Maintenance scheduling & records
│   │   │   ├── usage_tracking.py   # Operating hours & usage analytics
│   │   │   ├── statistics.py       # Dashboard analytics
│   │   │   └── demo.py             # Public demo endpoint
│   │   ├── services/               # Business logic
│   │   │   ├── ml_service.py       # ML model inference & processing
│   │   │   ├── audio_service.py    # Audio processing utilities
│   │   │   ├── maintenance_service.py # Maintenance logic
│   │   │   └── baseline_service.py # Baseline comparison logic
│   │   └── main.py                 # FastAPI application entry point
│   ├── uploads/                    # File storage
│   │   ├── audio/                  # User audio recordings
│   │   ├── baseline/               # Baseline audio samples
│   │   └── demo/                   # Demo audio files
│   ├── temp_models/                # ML model files
│   │   ├── tractor_resnet_transfer.h5  # Main ResNet model
│   │   └── tractor_resnet_final.keras  # Backup model format
│   ├── rule_based_maintenance.py   # Maintenance scheduling rules
│   ├── requirements.txt            # Python dependencies
│   └── .env                        # Environment variables (create this)
│
├──  info web/                    # Next.js Web Platform
│   ├── app/                        # Next.js 13+ app directory
│   │   ├── layout.tsx              # Root layout with metadata
│   │   ├── page.tsx                # Landing page
│   │   └── globals.css             # Global styles
│   ├── components/                 # React components
│   │   ├── hero-section.tsx        # Hero banner with CTA
│   │   ├── test-model-section.tsx  # Audio demo widget
│   │   ├── about-section.tsx       # Product information
│   │   ├── benefits-section.tsx    # Feature highlights
│   │   ├── how-it-works-section.tsx# Process explanation
│   │   ├── education-section.tsx   # Educational content
│   │   ├── faq-section.tsx         # Frequently asked questions
│   │   ├── contact-section.tsx     # Contact information
│   │   ├── navigation.tsx          # Header navigation
│   │   ├── footer.tsx              # Footer with links
│   │   └── ui/                     # Reusable UI components
│   ├── public/                     # Static assets
│   ├── styles/                     # CSS modules
│   ├── package.json                # Dependencies and scripts
│   └── next.config.mjs             # Next.js configuration
│
├──  tractorcare_app/             # Flutter Mobile Application
│   ├── lib/
│   │   ├── config/                 # App configuration
│   │   │   ├── app_config.dart     # API endpoints & settings
│   │   │   ├── routes.dart         # Navigation routes
│   │   │   ├── colors.dart         # Color scheme
│   │   │   └── theme.dart          # Material Design theme
│   │   ├── models/                 # Data models
│   │   │   ├── user.dart           # User model with authentication
│   │   │   ├── tractor.dart        # Tractor information model
│   │   │   ├── audio_prediction.dart # Audio analysis results
│   │   │   ├── maintenance.dart    # Maintenance task model
│   │   │   └── baseline.dart       # Baseline audio profile
│   │   ├── screens/                # UI screens
│   │   │   ├── auth/               # Registration & login
│   │   │   ├── home/               # Dashboard with analytics
│   │   │   ├── tractors/           # Tractor management
│   │   │   │   ├── tractor_list_screen.dart
│   │   │   │   ├── tractor_detail_screen.dart
│   │   │   │   └── add_tractor_screen.dart
│   │   │   ├── audio/              # Audio recording & analysis
│   │   │   │   ├── recording_screen.dart
│   │   │   │   └── results_screen.dart
│   │   │   ├── baseline/           # Baseline collection
│   │   │   │   ├── baseline_setup_screen.dart
│   │   │   │   ├── baseline_collection_screen.dart
│   │   │   │   └── baseline_status_screen.dart
│   │   │   ├── maintenance/        # Maintenance management
│   │   │   │   ├── maintenance_list_screen.dart
│   │   │   │   ├── calendar_screen.dart
│   │   │   │   └── add_maintenance_screen.dart
│   │   │   ├── usage/              # Usage tracking
│   │   │   │   └── usage_history_screen.dart
│   │   │   └── profile/            # User profile & settings
│   │   ├── services/               # Business logic
│   │   │   ├── api_service.dart    # REST API client
│   │   │   ├── auth_service.dart   # Authentication logic
│   │   │   ├── storage_service.dart # Local storage (SQLite)
│   │   │   └── audio_service.dart  # Audio recording utilities
│   │   ├── providers/              # State management (Provider pattern)
│   │   │   ├── auth_provider.dart  # Authentication state
│   │   │   ├── tractor_provider.dart # Tractor data state
│   │   │   └── audio_provider.dart # Audio analysis state
│   │   ├── widgets/                # Reusable UI components
│   │   │   ├── tractor_card.dart   # Tractor display card
│   │   │   ├── custom_button.dart  # Styled buttons
│   │   │   ├── bottom_nav.dart     # Bottom navigation
│   │   │   └── custom_app_bar.dart # Consistent app bar
│   │   └── main.dart               # Flutter app entry point
│   ├── android/                    # Android-specific configuration
│   ├── ios/                        # iOS-specific configuration
│   ├── web/                        # Web deployment assets
│   ├── assets/                     # Images, icons, and static assets
│   ├── pubspec.yaml                # Flutter dependencies
│   └── analysis_options.yaml       # Dart linting rules
│
└──  README.md                    # This comprehensive documentation
```

---

## 🔗 Important Links

| Resource | URL | Description |
|----------|-----|-------------|
| **Live Demo** | [TractorCare Web Platform](https://tractorcare.onrender.com/) | Test the AI model with your own audio files |
| **API Documentation** | [Swagger UI](https://tractorcare-backend.onrender.com/docs) | Interactive API documentation |
| **GitHub Repository** | [Source Code](https://github.com/Joh-Ishimwe/tractorcare) | Complete project source code |
| **Design System** | [Figma Design](https://www.figma.com/design/eWGvztGWZVTiAiBUjvSEXn/TractorCare?node-id=0-1&t=bWg7Cqmcuc0fSKuk-1) | UI/UX design specifications |
| **Demo Video** | [YouTube Presentation](https://youtu.be/5MO33OFGWrQ) | Complete system demonstration |
| **ML Notebook** | [Google Colab](https://colab.research.google.com/github/Joh-Ishimwe/tractorcare/blob/master/ML_experiments.ipynb) | Interactive ML training pipeline |

---

##  Deployment

### Production Deployment Guide

#### Backend Deployment (Render/Heroku)

**Render Configuration:**
```yaml
# render.yaml
services:
  - type: web
    name: tractorcare-backend
    env: python
    buildCommand: pip install -r requirements.txt
    startCommand: uvicorn app.main:app --host 0.0.0.0 --port $PORT
    envVars:
      - key: ENVIRONMENT
        value: production
      - key: SECRET_KEY
        generateValue: true
      - key: MONGO_URL
        fromDatabase:
          name: tractorcare-db
          property: connectionString
```

**Environment Variables for Production:**
```env
ENVIRONMENT=production
DEBUG=False
MONGO_URL=mongodb+srv://username:password@cluster.mongodb.net/tractorcare_db
SECRET_KEY=your-production-secret-key
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
```

#### Web Frontend Deployment (Vercel/Netlify)

**Vercel Configuration:**
```json
{
  "buildCommand": "npm run build",
  "outputDirectory": ".next",
  "framework": "nextjs",
  "env": {
    "NEXT_PUBLIC_API_URL": "https://your-api-domain.com"
  }
}
```

#### Mobile App Deployment

**Android APK Build:**
```bash
cd tractorcare_app
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**iOS App Store Build:**
```bash
cd tractorcare_app
flutter build ios --release
# Open ios/Runner.xcworkspace in Xcode for App Store submission
```

**Web Deployment:**
```bash
cd tractorcare_app
flutter build web --release
# Deploy build/web/ directory to your web hosting service
```

---

## 🛠️ Troubleshooting

### Common Backend Issues

**1. Import or Module Errors**
```bash
# Solution: Ensure virtual environment is activated
source tractorcarenv/bin/activate  # Linux/Mac
tractorcarenv\Scripts\activate     # Windows

# Verify Python version and packages
python --version
pip list
```

**2. Database Connection Issues**
```bash
# Check MongoDB status
sudo systemctl status mongod  # Linux
brew services list mongodb    # Mac

# Verify connection string
python -c "from pymongo import MongoClient; print(MongoClient('your-mongo-url').admin.command('ismaster'))"
```

**3. ML Model Loading Errors**
```bash
# Verify model file exists
ls temp_models/tractor_resnet_transfer.h5

# Check TensorFlow installation
python -c "import tensorflow as tf; print(tf.__version__)"
```

**4. Port Already in Use**
```bash
# Find process using port 8000
lsof -i :8000  # Mac/Linux
netstat -ano | findstr :8000  # Windows

# Kill process
kill -9 <PID>  # Mac/Linux
taskkill /PID <PID> /F  # Windows
```

### Common Frontend Issues

**1. Node.js Module Issues**
```bash
# Clear cache and reinstall
rm -rf node_modules package-lock.json
npm install

# Or use yarn
rm -rf node_modules yarn.lock
yarn install
```

**2. API Connection Problems**
- Verify backend is running: http://localhost:8000/health
- Check CORS configuration in backend
- Verify API URL in frontend environment variables

### Common Mobile App Issues

**1. Flutter Dependencies**
```bash
# Clean and reinstall dependencies
flutter clean
flutter pub get
flutter pub deps  # Check dependency tree
```

**2. Build Errors**
```bash
# Android build issues
cd android
./gradlew clean  # Linux/Mac
gradlew.bat clean  # Windows

# iOS build issues (Mac only)
cd ios
rm -rf Pods Podfile.lock
pod install
```

**3. Web Build Issues**
```bash
# Enable web support
flutter config --enable-web
flutter devices  # Should show Chrome
flutter run -d chrome
```

### Performance Optimization

**Backend Performance:**
- Use Redis for caching frequently accessed data
- Implement connection pooling for MongoDB
- Add request rate limiting for API endpoints
- Use async/await for all I/O operations

**Mobile App Performance:**
- Implement lazy loading for tractor lists
- Cache baseline profiles locally
- Use image compression for photos
- Implement background sync for data uploads

**ML Model Optimization:**
- Use model quantization for faster inference
- Implement model caching to avoid repeated loading
- Consider edge deployment for offline scenarios

---

##  License

This project is developed as part of an academic research initiative focused on improving agricultural productivity in Rwanda through AI-powered predictive maintenance.

**Academic Use:** Free for educational and research purposes  
**Commercial Use:** Please contact the authors for licensing terms

---

##  Contact

**Project Lead:** Josiane ISHIMWE  
**Email:** j.ishimwe3@alustudent.com  
**Institution:** African Leadership University  
**Location:** Kigali, Rwanda

---

**🚜 Built with ❤️ for smallholder farmers in Rwanda and beyond**

*"Transforming agricultural equipment maintenance through intelligent sound analysis and predictive insights."*
- Window function: Hamming window

### Machine Learning Experiments
- **Algorithms Tested (6 Models):**
  1. **K-Nearest Neighbors (KNN)** - Instance-based learning
  2. **Isolation Forest** - Unsupervised anomaly detection
  3. **Support Vector Machine (SVM)** - Kernel-based classification
  4. **Convolutional Neural Network (CNN)** - Deep learning baseline
  5. **VGG-like CNN** - Deeper architecture with batch normalization
  6. **ResNet-like CNN** - Residual connections for better gradient flow

- **Transfer Learning:** Pre-trained ResNet-like CNN on MIMII data, fine-tuned on real tractor sounds from Freesound with early layer freezing and lower learning rates. This transfer learning approach significantly improves the model's accuracy for actual tractor engine anomaly detection.

---

## Results

### Performance Comparison Table
| Algorithm       | Accuracy | Precision | Recall | F1-Score |
|-----------------|----------|-----------|--------|----------|
| KNN             | 95.08%   | 100.00%   | 90.43% | 94.97%   |
| Isolation Forest| 43.17%   | 44.32%    | 41.49% | 42.86%   |
| SVM             | 95.63%   | 100.00%   | 91.49% | 95.56%   |
| CNN             | 86.89%   | 83.02%    | 93.62% | 88.00%   |
| VGG-like CNN    | 91.26%   | 94.32%    | 88.30% | 91.21%   |
| ResNet-like CNN | 92.90%   | 100.00%   | 86.17% | 92.57%   |

### Key Findings
Supervised models (SVM, KNN, ResNet-like CNN) excelled with accuracies above 92%. ResNet-like CNN showed strong potential for transfer learning with perfect precision. Isolation Forest underperformed, confirming the value of labelled data for this task.

### Model Selection Rationale
**Selected Model:** ResNet-like CNN
- **Reasons:**
  1. Perfect Precision (100.00%) - Critical for cost-effective maintenance scheduling
  2. Strong F1-Score (92.57%) - Balances precision and recall effectively
  3. Residual connections enhance generalisation, ideal for transfer learning on tractor data
  4. Computational trade-off (slow training) acceptable for cloud deployment, with potential for edge optimization

---

## System Architecture

### Hybrid Approach
1. **Rule-Based Maintenance System**
   - Schedules routine maintenance (e.g., oil changes, filter checks) based on manufacturer guidelines
   - **File:** `tractorcare-backend/rule_based_maintenance.py`

2. **ML Audio Analysis**
   - Real-time acoustic anomaly detection using the ResNet-like CNN
   - **Notebook:** `Notebook/ML_experiments (6).ipynb` (includes training, fine-tuning, and prediction code)

3. **Why Hybrid?**
   - Rule-based systems miss unforeseen failures; ML alone overlooks routine needs
   - The combination provides comprehensive predictive maintenance

### Components
1. **Informative Website**
   - Public marketing site with demo audio testing
   - Features: Audio upload, AI-powered analysis, product information

2. **Mobile Application (Flutter)**
   - Audio recording, real-time predictions, maintenance scheduling, usage tracking
   - Offline-first architecture for rural use

3. **Backend API (FastAPI/Python)**
   - RESTful endpoints, JWT authentication, database management, ResNet-like CNN serving
   - **Deployment:** Hosted on Render

4. **Machine Learning Pipeline**
   - Audio preprocessing, MFCC feature extraction, ResNet-like CNN inference, prediction aggregation

---

## Installation

### Prerequisites

Before installing, ensure you have the following installed on your system:

- **Python 3.9+** - [Download](https://www.python.org/downloads/)
- **Node.js 18+** - [Download](https://nodejs.org/)
- **Flutter 3.0+** - [Download](https://flutter.dev/docs/get-started/install)
- **Git** - [Download](https://git-scm.com/downloads)
- **MongoDB** - [Download](https://www.mongodb.com/try/download/community) (or use MongoDB Atlas cloud)

### Step 1: Clone the Repository

```bash
git clone https://github.com/Joh-Ishimwe/tractorcare.git
cd tractorcare
```

### Step 2: Backend Setup

#### 2.1 Create Virtual Environment

**Windows:**
```bash
cd tractorcare-backend
python -m venv venv
venv\Scripts\activate
```

**macOS/Linux:**
```bash
cd tractorcare-backend
python3 -m venv venv
source venv/bin/activate
```

#### 2.2 Install Python Dependencies

```bash
pip install -r requirements.txt
```

#### 2.3 Configure Environment Variables

Create a `.env` file in the `tractorcare-backend` directory:

```env
# MongoDB Configuration
MONGO_URL=mongodb://localhost:27017
DATABASE_NAME=tractorcare_db

# Security
SECRET_KEY=your-secret-key-here-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=43200

# CORS Origins (comma-separated)
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080

# Environment
ENVIRONMENT=development
DEBUG=True
```

**Note:** Replace `your-secret-key-here-change-in-production` with a secure random string. You can generate one using:
```python
import secrets
print(secrets.token_urlsafe(32))
```

### Step 3: Web Frontend Setup

```bash
cd "info web"
npm install
```

### Step 4: Mobile App Setup

```bash
cd tractorcare_app
flutter pub get
```

---

## Running the Application

### Backend API Server

1. **Navigate to backend directory:**
```bash
cd tractorcare-backend
```

2. **Activate virtual environment:**
   - Windows: `venv\Scripts\activate`
   - macOS/Linux: `source venv/bin/activate`

3. **Run the server:**
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at:
- **API:** http://localhost:8000
- **Documentation:** http://localhost:8000/docs
- **Health Check:** http://localhost:8000/health

### Web Frontend

1. **Navigate to web directory:**
```bash
cd "info web"
```

2. **Start development server:**
```bash
npm run dev
```

The website will be available at: http://localhost:3000

### Mobile App

1. **Navigate to mobile app directory:**
```bash
cd tractorcare_app
```

2. **Run on connected device or emulator:**
```bash
flutter run
```

3. **Or run on specific platform:**
```bash
flutter run -d chrome          # Web browser
flutter run -d android         # Android device/emulator
flutter run -d ios             # iOS device/simulator (macOS only)
```

---

## Project Structure

```
tractorcare/
│
├── tractorcare-backend/          # Backend API (FastAPI/Python)
│   ├── app/
│   │   ├── core/                  # Core configuration and utilities
│   │   │   ├── config.py          # Application settings
│   │   │   ├── database.py        # MongoDB connection
│   │   │   └── security.py        # JWT authentication
│   │   ├── middleware/            # Custom middleware
│   │   │   └── security.py        # Security headers middleware
│   │   ├── models/                # Database models (Beanie ODM)
│   │   ├── routes/                # API route handlers
│   │   │   ├── auth.py            # Authentication endpoints
│   │   │   ├── tractors.py        # Tractor management
│   │   │   ├── audio.py           # Audio analysis endpoints
│   │   │   ├── maintenance.py    # Maintenance scheduling
│   │   │   ├── baseline.py        # Baseline audio management
│   │   │   ├── demo.py            # Public demo endpoint
│   │   │   ├── statistics.py      # Statistics endpoints
│   │   │   └── usage_tracking.py  # Usage tracking
│   │   ├── schemas/                # Pydantic schemas
│   │   ├── services/               # Business logic services
│   │   │   ├── ml_service.py      # ML model inference
│   │   │   ├── maintenance_service.py
│   │   │   └── baseline_service.py
│   │   └── main.py                # FastAPI application entry point
│   ├── uploads/                   # Uploaded audio files
│   │   ├── audio/                 # User audio recordings
│   │   ├── baseline/               # Baseline audio samples
│   │   └── demo/                  # Demo audio files
│   ├── temp_models/               # ML model files
│   ├── rule_based_maintenance.py  # Maintenance schedule rules
│   ├── requirements.txt           # Python dependencies
│   └── .env                        # Environment variables (create this)
│
├── info web/                       # Web Frontend (Next.js/React)
│   ├── app/                       # Next.js app directory
│   │   ├── layout.tsx             # Root layout
│   │   ├── page.tsx               # Home page
│   │   └── globals.css            # Global styles
│   ├── components/                # React components
│   │   ├── hero-section.tsx      # Hero section
│   │   ├── test-model-section.tsx # Audio testing demo
│   │   ├── about-section.tsx     # About section
│   │   ├── navigation.tsx        # Navigation bar
│   │   ├── footer.tsx             # Footer
│   │   └── ui/                    # Reusable UI components
│   ├── public/                    # Static assets
│   ├── package.json               # Node.js dependencies
│   └── next.config.mjs            # Next.js configuration
│
├── tractorcare_app/               # Mobile App (Flutter)
│   ├── lib/
│   │   ├── config/                # App configuration
│   │   │   ├── app_config.dart    # API endpoints and settings
│   │   │   ├── routes.dart        # Navigation routes
│   │   │   ├── colors.dart        # Color scheme
│   │   │   └── theme.dart         # App theme
│   │   ├── models/                 # Data models
│   │   │   ├── user.dart          # User model
│   │   │   ├── tractor.dart       # Tractor model
│   │   │   ├── audio_prediction.dart
│   │   │   ├── maintenance.dart
│   │   │   └── baseline.dart
│   │   ├── screens/                # UI screens
│   │   │   ├── auth/               # Authentication screens
│   │   │   ├── home/               # Dashboard and home
│   │   │   ├── tractors/           # Tractor management
│   │   │   ├── audio/              # Audio recording and analysis
│   │   │   ├── maintenance/       # Maintenance tracking
│   │   │   ├── baseline/           # Baseline management
│   │   │   ├── usage/              # Usage tracking
│   │   │   └── profile/            # User profile
│   │   ├── services/               # Business logic
│   │   │   ├── api_service.dart    # API client
│   │   │   ├── auth_service.dart   # Authentication
│   │   │   ├── storage_service.dart # Local storage
│   │   │   └── audio_service.dart  # Audio recording
│   │   ├── providers/             # State management (Provider)
│   │   │   ├── auth_provider.dart
│   │   │   ├── tractor_provider.dart
│   │   │   └── audio_provider.dart
│   │   ├── widgets/                # Reusable widgets
│   │   │   ├── tractor_card.dart
│   │   │   ├── custom_button.dart
│   │   │   └── bottom_nav.dart
│   │   └── main.dart               # App entry point
│   ├── android/                    # Android-specific files
│   ├── ios/                        # iOS-specific files
│   ├── assets/                     # Images and assets
│   ├── pubspec.yaml                # Flutter dependencies
│   └── README.md                   # Mobile app README
│
├── Notebook/                      # ML Experiments
│   ├── ML_experiments (6).ipynb   # Jupyter notebook with ML code
│   └── data/                      # Training data
│
└── README.md                      # This file
```

---

## Important Links

- **Repository:** [GitHub](https://github.com/Joh-Ishimwe/tractorcare/tree/master)
- **Live Website:** [TractorCare Info](https://tractorcare.onrender.com/)
- **API Documentation:** [API Docs](https://tractorcare-backend.onrender.com/docs)
- **Design System:** [Figma](https://www.figma.com/design/eWGvztGWZVTiAiBUjvSEXn/TractorCare?node-id=0-1&t=bWg7Cqmcuc0fSKuk-1)
- **Demo Video:** [YouTube](https://youtu.be/5MO33OFGWrQ)

---

## Deployment

### Production Deployment

**Backend (Render):**
- Set environment variables in Render dashboard
- Ensure `ENVIRONMENT=production` is set
- Configure MongoDB Atlas connection string
- Deploy using Render's Python service

**Web Frontend (Render/Vercel):**
- Build: `npm run build`
- Start: `npm start`
- Set API URL in environment variables

**Mobile App:**
- Build APK/IPA for distribution
- Configure production API URL in `lib/config/app_config.dart`

---

## Troubleshooting

### Backend Issues
- **Import errors:** Ensure virtual environment is activated
- **Database connection:** Check MongoDB is running and MONGO_URL is correct
- **Port already in use:** Change port in `uvicorn` command or kill existing process

### Web Frontend Issues
- **Module not found:** Run `npm install` again
- **API connection:** Check backend is running and CORS is configured

### Mobile App Issues
- **Dependencies:** Run `flutter pub get`
- **Build errors:** Run `flutter clean && flutter pub get`
- **API connection:** Verify API URL in `app_config.dart`

---

## License

This project is part of an academic research initiative for predictive maintenance in agriculture.

---



**Built with for smallholder farmers in Rwanda**

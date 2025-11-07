# TractorCare - Predictive Maintenance for Agricultural Tractors

TractorCare is a hybrid machine learning system designed for the early detection of tractor engine failures using acoustic analysis. It combines rule-based maintenance scheduling with ML audio anomaly detection, specifically tailored for smallholder farmers in Rwanda. This project aims to improve tractor reliability, reduce downtime, and enhance agricultural productivity through affordable, accessible technology.



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

**Two-Stage Prediction Engine: Global Intelligence + Personalized Baselines**

TractorCare employs a sophisticated dual-stage prediction system that combines global machine learning intelligence with personalized baseline comparison for superior anomaly detection accuracy.

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Trained ML    │    │    Baseline     │    │   Final         │
│   Model         │ -> │   Comparison    │ -> │   Prediction    │
│   (ResNet CNN)  │    │   System        │    │   Result        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```
#### Stage 1: Global Intelligence (ResNet CNN)
- Use trained ResNet CNN model trained (transfer learning model) to provide general anomaly detection
- It learns universal patterns of normal vs. abnormal machinery sounds
- Outputs a probability score (0-1) indicating likelihood of anomaly
- **Input**: Raw audio (any tractor engine sound)
- **Output**: General anomaly probability

#### Stage 2: Baseline Comparison System
- Compares the current audio against the specific tractor's healthy baseline
- Calculates deviation from that tractor's normal operating sound
- Provides personalized anomaly scoring
- **Input**: Current audio + Stored baseline samples for that specific tractor
- **Output**: Baseline deviation score (how different from this tractor's normal)



### Rule-Based Maintenance Integration

**Manufacturer Manual-Driven Scheduling**
- **Data Source:** Official Massey Ferguson MF 240 & MF 375 operator manuals
- **Dual-Trigger System:** Maintenance scheduled by engine hours OR calendar time (whichever comes first)
- **Progress Tracking:** 90% threshold triggers maintenance alerts

**Audio-Triggered Maintenance Mapping**
When audio anomalies are detected, the system automatically craete maintenance tasks


### Offline-First Architecture

**Smart Caching System:**
- **Baseline Storage:** Tractor profiles cached locally on mobile device
- **Model Edge Deployment:** Lightweight ML inference runs locally when possible
- **Sync Strategy:** Data uploads automatically when internet connection available
- **Conflict Resolution:** Smart merging of offline/online data changes

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

| Resource | URL |
|----------|-----|
| **Live Demo** | [TractorCare Web Platform](https://tractorcare.onrender.com/) | 
| **API Documentation** | [Swagger UI](https://tractorcare-backend.onrender.com/docs) | 
| **GitHub Repository** | [Source Code](https://github.com/Joh-Ishimwe/tractorcare) | 
| **Design System** | [Figma Design](https://www.figma.com/design/eWGvztGWZVTiAiBUjvSEXn/TractorCare?node-id=0-1&t=bWg7Cqmcuc0fSKuk-1) |
| **Demo Video** | [YouTube Presentation](https://youtu.be/5MO33OFGWrQ) |

---

##  Deployment

### Production Deployment Guide

#### Backend Deployment (Render)

```

**Environment Variables for Production:**
```env
ENVIRONMENT=production
DEBUG=False
MONGO_URL=mongodb+srv://username:password@cluster.mongodb.net/tractorcare_db
SECRET_KEY=your-production-secret-key
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
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


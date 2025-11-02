# TractorCare - Predictive Maintenance for Agricultural Tractors

TractorCare is a hybrid machine learning system designed for the early detection of tractor engine failures using acoustic analysis. It combines rule-based maintenance scheduling with audio-based anomaly detection, tailored for smallholder farmers in Rwanda. This project aims to improve tractor reliability, reduce downtime, and enhance agricultural productivity through affordable, accessible technology.

---

## Table of Contents

- [Dataset](#dataset)
- [Methodology](#methodology)
- [Results](#results)
- [System Architecture](#system-architecture)
- [Installation](#installation)
- [Running the Application](#running-the-application)
- [Project Structure](#project-structure)
- [Important Links](#important-links)

---

## Dataset

**Source:** 
- **Initial Training:** MIMII Dataset (Malfunctioning Industrial Machine Investigation and Inspection)
  - Industrial pumps (used as a proxy for tractor engines)
  - 912 audio recordings (456 normal, 456 abnormal) after balancing
  - 10 seconds per sample at 16kHz sampling rate
  - WAV format

- **Transfer Learning Dataset:** Real Tractor Sounds from Freesound
  - Tractor-specific audio samples collected from Freesound platform
  - Used for fine-tuning the ResNet-like CNN model
  - Enables better generalization to actual tractor engine sounds
  - Improves accuracy for real-world tractor maintenance scenarios

---

## Methodology

### Feature Extraction Pipeline
**Primary Features: MFCC (Mel-Frequency Cepstral Coefficients)**
- **Coefficients:** 40 MFCCs extracted per frame
- **Preprocessing:** High-Pass Filter (100 Hz cutoff) applied to reduce low-frequency background noise
- **Representation:** Fixed-length 40×100 frames per audio sample
- **Purpose:** Captures spectral envelope and temporal patterns indicative of engine health

**Audio Processing:**
- Sample rate: 16kHz
- Frame length: 2048 samples
- Hop length: 512 samples
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

### Key Files Description

**Backend:**
- `app/main.py` - FastAPI application entry point
- `app/core/config.py` - Environment configuration
- `app/core/database.py` - MongoDB connection setup
- `app/core/security.py` - JWT authentication
- `app/middleware/security.py` - Security headers middleware
- `app/routes/*.py` - API endpoint handlers
- `app/services/ml_service.py` - ML model inference service
- `rule_based_maintenance.py` - Maintenance schedule rules

**Web Frontend:**
- `app/page.tsx` - Main landing page
- `components/test-model-section.tsx` - Audio demo section
- `package.json` - Dependencies and scripts

**Mobile App:**
- `lib/main.dart` - App entry point
- `lib/config/app_config.dart` - API configuration
- `lib/services/api_service.dart` - API client
- `lib/screens/*` - UI screens
- `pubspec.yaml` - Flutter dependencies

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

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

**Built with for smallholder farmers in Rwanda**

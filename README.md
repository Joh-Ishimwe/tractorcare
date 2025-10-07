# TractorCare - Predictive Maintenance for Agricultural Tractors

## Project Description
Hybrid machine learning system for early detection of tractor engine failures using acoustic analysis. Combines rule-based maintenance scheduling with audio-based anomaly detection for smallholder farmers in Rwanda.

---

## Dataset

**Source:** MIMII Dataset (Malfunctioning Industrial Machine Investigation and Inspection)

- **Machine Type:** Industrial pumps (proxy for tractor engines)
- **Samples:** 912 audio recordings (456 normal, 456 abnormal) after balancing
- **Duration:** 10 seconds per sample at 16kHz sampling rate
- **Format:** WAV files

---

## Methodology

### Feature Extraction Pipeline

**Primary Features: MFCC (Mel-Frequency Cepstral Coefficients)**
- **Coefficients:** 40 MFCCs extracted per frame
- **Preprocessing:** High-Pass Filter (100 Hz cutoff) applied to reduce low-frequency background noise
- **Representation:** Fixed-length 40×100 frames per audio sample
- **Purpose:** Captures spectral envelope and temporal patterns characteristic of engine health

**Audio Processing:**
- Sample rate: 16kHz
- Frame length: 2048 samples
- Hop length: 512 samples
- Window function: Hamming window

---

## Machine Learning Experiments

### Algorithms Tested (6 Models)

1. **K-Nearest Neighbors (KNN)** - Instance-based learning
2. **Isolation Forest** - Unsupervised anomaly detection
3. **Support Vector Machine (SVM)** - Kernel-based classification
4. **Convolutional Neural Network (CNN)** - Deep learning baseline
5. **VGG-like CNN** - Deeper architecture with batch normalization
6. **ResNet-like CNN** - Residual connections for better gradient flow

---

## Results

### Performance Comparison Table

| Algorithm | Accuracy | Precision | Recall | F1-Score | Training Time |
|-----------|----------|-----------|--------|----------|---------------|
| **KNN** | 97.27% | 100.00% | 94.68% | 97.27% | Fast |
| **Isolation Forest** | 48.09% | 49.48% | 51.06% | 50.26% | Fast |
| **SVM** | 96.72% | 97.83% | 95.74% | 96.77% | Medium |
| **CNN** | 93.99% | 91.92% | 96.81% | 94.30% | Medium |
| **VGG-like CNN** | **97.27%** | 96.84% | 97.87% | **97.35%** | Slow |
| **ResNet-like CNN** | **97.27%** | 95.88% | **98.94%** | **97.38%** | Slow |

### Key Findings

- **Top Performers:** VGG-like CNN and ResNet-like CNN achieved the highest accuracy (97.27%)
- **Best Recall:** ResNet-like CNN (98.94%) - Critical for fault detection to minimize false negatives
- **Most Balanced:** ResNet-like CNN with F1-Score of 97.38%
- **Fastest:** KNN with comparable accuracy but lower computational requirements
- **Least Effective:** Isolation Forest (unsupervised) performed poorly on this labeled dataset

### Model Selection Rationale

**Selected Model:** ResNet-like CNN

**Reasons:**
1. Highest recall (98.94%) - Minimizes missed failures (critical for safety)
2. Excellent F1-Score (97.38%) - Best balance of precision and recall
3. Robust generalization through residual connections
4. Trade-off: Higher computational cost acceptable for deployment on cloud/edge devices

---

## System Architecture

### Hybrid Approach

**1. Rule-Based Maintenance System**
- Traditional maintenance scheduling based on manufacturer guidelines
- Handles routine maintenance: oil changes, filters, belt inspections
- **File:** `backend/rule_based_maintenance.py`

**2. ML Audio Analysis**
- Real-time acoustic anomaly detection
- Detects unexpected failures before they occur

**3. Why Hybrid?**
- Rule-based alone misses unexpected failures
- ML alone doesn't handle routine maintenance
- **Combined = Comprehensive predictive maintenance**

### Components

1. **Informative website and Leader Dashboard**
   - Public-facing marketing site showcasing TractorCare solution
   - Administrative dashboard for cooperative leaders and managers
   - Fleet overview with real-time health status visualization
   - Analytics and reporting
   - Cooperative management (members, tractors, bookings)
1. **Mobile Application (Flutter)**
   - Audio recording interface
   - Real-time predictions
   - Maintenance scheduling
   - Usage tracking
   - Offline-first architecture

2. **Backend API (FastAPI/Python)**
   - RESTful endpoints
   - Authentication & authorization (JWT)
   - Database management 
   - ML model serving
   - Rule-based prediction engine

3. **Machine Learning Pipeline**
   - Audio preprocessing
   - Feature extraction (MFCC)
   - Model inference
   - Prediction aggregation
### Important links
- [Repo link](https://github.com/Joh-Ishimwe/tractorcare)
- [Full Design System Figma link](https://docs.google.com/document/d/1dxg7Q7S4b1OSteFDj5SCjF9l15-Mj-nbUK4H8m4lI8Y/edit?usp=sharing)
- [Deployed API](https://docs.google.com/document/d/1dxg7Q7S4b1OSteFDj5SCjF9l15-Mj-nbUK4H8m4lI8Y/edit?usp=sharing)
- [Demo Video link](https://docs.google.com/document/d/1dxg7Q7S4b1OSteFDj5SCjF9l15-Mj-nbUK4H8m4lI8Y/edit?usp=sharing)

## Deployment Plan
- Informative website, Dashboard and Backend Hosting(API):Render
- Mobile App:Firebase Hosting
---

## Setup Instructions

### Prerequisites
- Python 3.9+
- Flutter 3.0+
- Git

### Quick Start

#### Backend Setup 
```bash
# 1. Clone repository
git clone https://github.com/Joh-Ishimwe/tractorcare.git
cd tractorcare/backend

# 2. Create virtual environment
python -m venv tractorcarenv
# Windows: tractorcarenv\Scripts\activate
# Mac/Linux: source tractorcarenv/bin/activate

# 3. Install dependencies
pip install fastapi uvicorn sqlalchemy python-jose passlib bcrypt pydantic

```
## Mobile App Setup
```bash
# 1. Navigate to mobile app
cd mobile_app

# 2. Install dependencies
flutter pub get

# 3. Run on Chrome (for testing)
flutter run -d chrome

# 4. Or run on Android
flutter run
```
## Backend
```bash
# 1. Navigate to backend
cd backend

# 2. Run server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
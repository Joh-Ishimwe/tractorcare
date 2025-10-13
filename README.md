# TractorCare - Predictive Maintenance for Agricultural Tractors
TractorCare is a hybrid machine learning system designed for the early detection of tractor engine failures using acoustic analysis. It combines rule-based maintenance scheduling with audio-based anomaly detection, tailored for smallholder farmers in Rwanda. This project aims to improve tractor reliability, reduce downtime, and enhance agricultural productivity through affordable, accessible technology.

---

## Dataset

**Source:** MIMII Dataset (Malfunctioning Industrial Machine Investigation and Inspection)
- **Machine Type:** Industrial pumps (used as a proxy for tractor engines)
- **Samples:** 912 audio recordings (456 normal, 456 abnormal) after balancing
- **Duration:** 10 seconds per sample at 16kHz sampling rate
- **Format:** WAV files
- **Note:** A tractor-specific dataset is planned for future enhancement.

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

- **Transfer Learning Plan:** Pre-trained ResNet-like CNN on MIMII data, fine-tuned on future tractor data with early layer freezing and lower learning rates.

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
Supervised models (SVM, KNN, ResNet-like CNN) excelled with accuracies above 92%. But ResNet-like CNN showed strong potential for transfer learning with perfect precision.
Isolation Forest underperformed, confirming the value of labelled data for this task.

### Model Selection Rationale
**Selected Model:** ResNet-like CNN
- **Reasons:**
  1. Perfect Precision (100.00%) - Critical for cost-effective maintenance scheduling.
  2. Strong F1-Score (92.57%) - Balances precision and recall effectively.
  3. Residual connections enhance generalisation, ideal for transfer learning on tractor data.
  4. Computational trade-off (slow training) acceptable for cloud deployment, with potential for edge optimization.

---

## System Architecture

### Hybrid Approach
1. **Rule-Based Maintenance System**
   - Schedules routine maintenance (e.g., oil changes, filter checks) based on manufacturer guidelines.
   - **File:** `backend/rule_based_maintenance.py`

2. **ML Audio Analysis**
   - Real-time acoustic anomaly detection using the ResNet-like CNN.
   - **Notebook:** `Notebook/ML_experiments.ipynb` (includes training, fine-tuning, and prediction code).

3. **Why Hybrid?**
   - Rule-based systems miss unforeseen failures; ML alone overlooks routine needs.
   - The combination provides comprehensive predictive maintenance.

### Components
1. **Informative Website and Leader Dashboard**
   - Public marketing site and admin dashboard for cooperative leaders.
   - Features: Fleet health visualisation, analytics, cooperative management.

2. **Mobile Application (Flutter)**
   - Audio recording, real-time predictions, maintenance scheduling, usage tracking.
   - Offline-first architecture for rural use.

3. **Backend API (FastAPI/Python)**
   - RESTful endpoints, JWT authentication, database management, ResNet-like CNN serving.
   - **Deployment:** Hosted on Render.

4. **Machine Learning Pipeline**
   - Audio preprocessing, MFCC feature extraction, ResNet-like CNN inference, prediction aggregation.
   - Future: Fine-tuning on tractor data.

### Important Links
- [Repo Link](https://github.com/josishimwe/tractorcare)
- [Info web link](https://tractorcare.onrender.com/)
- [Full Design System Figma Link](https://docs.google.com/document/d/1dxg7Q7S4b1OSteFDj5SCjF9l15-Mj-nbUK4H8m4lI8Y/edit?usp=sharing](https://www.figma.com/design/eWGvztGWZVTiAiBUjvSEXn/TractorCare?node-id=0-1&t=bWg7Cqmcuc0fSKuk-1))
- [Deployed API Docs](https://tractorcare-backend.onrender.com/docs) 
- [Demo Video Link](https://youtu.be/5MO33OFGWrQ)

---

## Deployment Plan
- **Informative Website, Dashboard, and Backend API:** Render
- **Mobile App:** Firebase Hosting


---

## Setup Instructions

### Prerequisites
- **Python 3.9+**
- **Flutter 3.0+**
- **Git**
- **Node.js** (for website/dashboard, if applicable)

### Local Environment Setup

#### Install Dependencies
Run the following commands in your terminal (e.g., PowerShell) to install all required Python packages for the ML pipeline and backend. Use a virtual environment to avoid conflicts.

```bash
# 1. Clone repository
git clone https://github.com/josishimwe/tractorcare.git
cd tractorcare

# 2. Create virtual environment
python -m venv tractorcarenv
# Activate environment
tractorcarenv\Scripts\activate  # Windows

# 3. Install Python dependencies
pip install numpy pandas matplotlib seaborn librosa soundfile scikit-learn tensorflow keras fastapi uvicorn sqlalchemy python-jose[cryptography] passlib[bcrypt] pydantic

# 4. Install Flutter (if not installed)
# Download from: https://flutter.dev/docs/get-started/install/windows
# Add to PATH and run: flutter doctor to verify

# 5. Navigate to mobile app and install dependencies
cd mobile_app
flutter pub get
```
## Backend Setup
```bash
# 1. Navigate to backend
cd backend

# 2. Set environment variables (create .env file)
echo REDIS_URL=your_redis_url_here > .env  # Get from Render Redis dashboard
echo DATABASE_URL=your_db_url_here >> .env  # Configure PostgreSQL on Render

# 3. Run server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
## Mobile App Setup
```bash
# 1. Navigate to mobile app
cd mobile_app

# 2. Run on Chrome (for testing)
flutter run -d chrome

# 3. Or run on Android/iOS device/emulator
flutter run
```

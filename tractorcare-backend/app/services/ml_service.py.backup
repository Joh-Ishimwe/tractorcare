"""
ML Service for Audio Prediction
Loads models directly from Google Drive 
"""

import librosa
import numpy as np
import joblib
import os
import gdown
from pathlib import Path
import json
import logging
from scipy.signal import butter, filtfilt

# Configure logging
logger = logging.getLogger(__name__)

class MLService:
    """Machine Learning service for audio prediction"""
    
    # Google Drive file IDs for your models
    DRIVE_FILES = {
        "scaler": "1kTN6qifz2_8MetWsoCOQwXZD8lfHUDHr",
        "svm": "11Af09dSh-u1QFUevu-x6vkMr4XHdH3eK",
        "config": "1wmKKS_5l2JeArHD06MwkJdmR868K33Pn"
    }
    
    # Default config matching training
    DEFAULT_CONFIG = {
        "sample_rate": 22050,
        "duration": 5.0,
        "n_mfcc": 40,
        "max_len": 216,  # ~5 seconds at default hop_length
        "apply_highpass": True
    }
    
    def __init__(self):
        self.model = None
        self.scaler = None
        self.config = None
        self.model_dir = Path("temp_models")
        self.model_dir.mkdir(exist_ok=True)
        logger.info("🚀 Initializing ML Service...")
        self._download_and_load_models()
    
    def _download_from_drive(self, file_id: str, output_path: str) -> bool:
        """Download file from Google Drive"""
        try:
            logger.info(f"📥 Downloading from Google Drive: {output_path}")
            url = f"https://drive.google.com/uc?id={file_id}"
            gdown.download(url, output_path, quiet=False)
            logger.info(f"✅ Downloaded: {output_path}")
            return True
        except Exception as e:
            logger.error(f"❌ Error downloading {output_path}: {e}")
            return False
    
    def _download_and_load_models(self):
        """Download models from Google Drive and load them"""
        try:
            logger.info("🔍 Checking for models...")
            
            # Download scaler
            scaler_path = self.model_dir / "scaler.pkl"
            if not scaler_path.exists():
                logger.info("📦 Scaler not found locally, downloading...")
                self._download_from_drive(self.DRIVE_FILES["scaler"], str(scaler_path))
            else:
                logger.info("✅ Scaler found in cache")
            
            if scaler_path.exists():
                self.scaler = joblib.load(scaler_path)
                logger.info("✅ Scaler loaded successfully")
            
            # Download SVM model
            model_path = self.model_dir / "svm.pkl"
            if not model_path.exists():
                logger.info("📦 SVM model not found locally, downloading...")
                self._download_from_drive(self.DRIVE_FILES["svm"], str(model_path))
            else:
                logger.info("✅ SVM model found in cache")
            
            if model_path.exists():
                self.model = joblib.load(model_path)
                logger.info("✅ SVM model loaded successfully")
            
            # Download config
            config_path = self.model_dir / "config.json"
            if not config_path.exists():
                logger.info("📦 Config not found locally, downloading...")
                self._download_from_drive(self.DRIVE_FILES["config"], str(config_path))
            else:
                logger.info("✅ Config found in cache")
            
            if config_path.exists():
                with open(config_path, 'r') as f:
                    loaded_config = json.load(f)
                    # Merge with defaults
                    self.config = {**self.DEFAULT_CONFIG, **loaded_config}
                logger.info("✅ Config loaded successfully")
            else:
                self.config = self.DEFAULT_CONFIG
                logger.info("⚠️ Using default config")
            
            # Check if models loaded
            if self.model is None or self.scaler is None:
                logger.warning("⚠️ WARNING: Models not fully loaded!")
            else:
                logger.info("🎉 All models loaded successfully! Ready for predictions.")
                
        except Exception as e:
            logger.error(f"❌ Error loading models: {e}")
            raise
    
    def extract_mfcc_features(self, file_path: str) -> np.ndarray:
        """
        Extract MFCC features matching training pipeline
        
        Returns MFCC of shape (n_mfcc, max_len)
        """
        try:
            # Load audio
            audio, sr = librosa.load(
                file_path,
                sr=self.config["sample_rate"],
                duration=self.config["duration"]
            )
            
            # Optional high-pass filter to reduce low-frequency noise
            if self.config.get("apply_highpass", True):
                nyquist = sr / 2
                cutoff = 100  # Hz
                b, a = butter(4, cutoff / nyquist, btype='high')
                audio = filtfilt(b, a, audio)
            
            # Extract MFCCs
            mfcc = librosa.feature.mfcc(
                y=audio,
                sr=sr,
                n_mfcc=self.config["n_mfcc"]
            )
            
            # Pad or truncate to fixed length
            max_len = self.config["max_len"]
            if mfcc.shape[1] < max_len:
                pad_width = max_len - mfcc.shape[1]
                mfcc = np.pad(mfcc, pad_width=((0, 0), (0, pad_width)), mode='constant')
            else:
                mfcc = mfcc[:, :max_len]
            
            return mfcc
            
        except Exception as e:
            logger.error(f"❌ Error extracting MFCC: {e}")
            raise
    
    def compute_statistics(self, mfcc: np.ndarray) -> np.ndarray:
        """
        Compute statistical features from MFCC for traditional ML models
        
        Features computed:
        - Mean, Std, Max, Min, Median of MFCCs (5 x n_mfcc)
        - Delta (1st derivative) mean and std (2 x n_mfcc)
        - Delta-Delta (2nd derivative) mean and std (2 x n_mfcc)
        
        Total: 9 x n_mfcc features (9 x 40 = 360)
        """
        # Basic statistics
        mean = np.mean(mfcc, axis=1)
        std = np.std(mfcc, axis=1)
        maximum = np.max(mfcc, axis=1)
        minimum = np.min(mfcc, axis=1)
        median = np.median(mfcc, axis=1)
        
        # Delta features (velocity)
        delta = librosa.feature.delta(mfcc)
        delta_mean = np.mean(delta, axis=1)
        delta_std = np.std(delta, axis=1)
        
        # Delta-Delta features (acceleration)
        delta2 = librosa.feature.delta(mfcc, order=2)
        delta2_mean = np.mean(delta2, axis=1)
        delta2_std = np.std(delta2, axis=1)
        
        # Concatenate all features
        stats = np.concatenate([
            mean, std, maximum, minimum, median,
            delta_mean, delta_std, delta2_mean, delta2_std
        ])
        
        return stats
    
    def extract_features(self, audio_path: str) -> np.ndarray:
        """
        Extract features from audio file matching training pipeline
        
        Returns flattened array of 360 statistical features
        """
        try:
            logger.info(f"🎵 Extracting features from: {audio_path}")
            
            # Extract MFCCs
            mfcc = self.extract_mfcc_features(audio_path)
            
            # Compute statistics
            stats = self.compute_statistics(mfcc)
            
            logger.info(f"✅ Extracted {len(stats)} features")
            
            return stats.reshape(1, -1)
            
        except Exception as e:
            logger.error(f"❌ Error extracting features: {e}")
            raise
    
    async def predict_audio(self, audio_path: str, tractor_id: str) -> dict:
        """Predict tractor condition from audio"""
        try:
            logger.info(f"🔮 Making prediction for tractor: {tractor_id}")
            
            if self.model is None:
                raise ValueError("Model not loaded. Please check Google Drive file IDs.")
            
            # Extract features
            features = self.extract_features(audio_path)
            
            # Scale features
            if self.scaler is not None:
                features_scaled = self.scaler.transform(features)
            else:
                features_scaled = features
                logger.warning("⚠️ No scaler available, using raw features")
            
            # Make prediction
            prediction = self.model.predict(features_scaled)[0]
            
            # Get confidence
            if hasattr(self.model, 'predict_proba'):
                probabilities = self.model.predict_proba(features_scaled)[0]
                confidence = float(np.max(probabilities))
            else:
                confidence = 0.95
            
            # Map to class name
            class_mapping = {
                0: "Normal",
                1: "Abnormal",
                "Normal": "Normal",
                "Abnormal": "Abnormal"
            }
            prediction_class = class_mapping.get(prediction, str(prediction))
            
            # Calculate anomaly score
            anomaly_score = 1.0 - confidence if prediction_class == "Normal" else confidence
            
            logger.info(f"✅ Prediction: {prediction_class} (confidence: {confidence:.2%})")
            
            return {
                "prediction_class": prediction_class,
                "confidence": confidence,
                "anomaly_score": anomaly_score,
                "tractor_id": tractor_id,
                "model_used": "SVM",
                "features_count": features.shape[1]
            }
            
        except Exception as e:
            logger.error(f"❌ Prediction error: {e}")
            raise
    
    def get_model_info(self) -> dict:
        """Get information about loaded models"""
        return {
            "model_loaded": self.model is not None,
            "scaler_loaded": self.scaler is not None,
            "config_loaded": self.config is not None,
            "model_type": type(self.model).__name__ if self.model else None,
            "source": "Google Drive",
            "n_mfcc": self.config.get("n_mfcc", "N/A"),
            "sample_rate": self.config.get("sample_rate", "N/A"),
            "expected_features": self.config.get("n_mfcc", 40) * 9
        }
import librosa
import numpy as np
import io
from scipy.signal import butter, sosfiltfilt
from app.config import settings

def apply_highpass_filter(audio_data: np.ndarray, sample_rate: int, cutoff_freq: float = 100.0, order: int = 5) -> np.ndarray:
    """
    Apply a high-pass Butterworth filter to remove low-frequency noise
    
    Args:
        audio_data: Raw audio signal (numpy array)
        sample_rate: Sample rate of the audio (Hz)
        cutoff_freq: Cutoff frequency for high-pass filter (Hz) - DEFAULT 100 Hz
        order: Filter order - DEFAULT 5
    
    Returns:
        Filtered audio signal
    """
    try:
        # Ensure audio is float
        audio_data = audio_data.astype(np.float64)
        
        # Normalize cutoff frequency to Nyquist frequency
        nyquist = 0.5 * sample_rate
        normal_cutoff = cutoff_freq / nyquist
        
        # Clamp cutoff to valid range
        normal_cutoff = np.clip(normal_cutoff, 0.001, 0.999)
        
        # Design Butterworth high-pass filter using SOS (more stable)
        sos = butter(order, normal_cutoff, btype='high', analog=False, output='sos')
        
        # Apply filter (forward and backward to avoid phase shift)
        filtered_audio = sosfiltfilt(sos, audio_data)
        
        return filtered_audio
    
    except Exception as e:
        print(f"⚠️ Filter failed: {str(e)}, returning original audio")
        return audio_data


def extract_mfcc(
    audio_data: bytes, 
    sample_rate: int = 16000,
    n_mfcc: int = 40,
    max_len: int = 100,
    duration: float = 10.0
) -> np.ndarray:
    """
    Extract MFCC features from audio bytes - EXACTLY matching training pipeline
    
    Args:
        audio_data: Audio file as bytes
        sample_rate: Target sample rate (16000 Hz)
        n_mfcc: Number of MFCC coefficients (40)
        max_len: Maximum time frames (100)
        duration: Audio duration in seconds (10)
    
    Returns:
        MFCC feature array of shape (40, 100, 1)
    """
    try:
        # Step 1: Load audio (matching training: sr=16000, duration=10)
        audio_array, sr = librosa.load(
            io.BytesIO(audio_data), 
            sr=sample_rate,
            duration=duration,
            mono=True  # Force mono
        )
        
        # Check if audio is too short
        if len(audio_array) < sample_rate * 0.5:  # Less than 0.5 seconds
            raise ValueError(f"Audio too short: {len(audio_array)/sample_rate:.2f}s (minimum 0.5s)")
        
        # Step 2: Apply high-pass filter (matching training: 100 Hz cutoff)
        audio_array = apply_highpass_filter(audio_array, sr, cutoff_freq=100.0, order=5)
        
        # Step 3: Extract MFCCs (matching training: n_mfcc=40)
        mfcc = librosa.feature.mfcc(y=audio_array, sr=sr, n_mfcc=n_mfcc)
        
        # Step 4: Pad or truncate to fixed length (matching training: max_len=100)
        if mfcc.shape[1] < max_len:
            pad_width = max_len - mfcc.shape[1]
            mfcc = np.pad(mfcc, ((0, 0), (0, pad_width)), mode='constant')
        else:
            mfcc = mfcc[:, :max_len]
        
        # Step 5: Add channel dimension (matching training: shape becomes (40, 100, 1))
        mfcc = np.expand_dims(mfcc, axis=-1)
        
        # Verify shape
        assert mfcc.shape == (n_mfcc, max_len, 1), f"Expected shape ({n_mfcc}, {max_len}, 1), got {mfcc.shape}"
        
        return mfcc
    
    except Exception as e:
        raise ValueError(f"MFCC extraction failed: {str(e)}")


def validate_audio_file(audio_data: bytes) -> tuple[bool, str]:
    """
    Validate audio file before processing
    
    Returns:
        (is_valid, error_message)
    """
    try:
        # Check file size
        file_size_mb = len(audio_data) / (1024 * 1024)
        if file_size_mb > 50:
            return False, "Audio file too large (max 50 MB)"
        if file_size_mb < 0.001:
            return False, "Audio file too small (corrupted?)"
        
        # Try to load audio to verify it's valid
        audio_array, sr = librosa.load(io.BytesIO(audio_data), sr=None, duration=0.5)  # Just load first 0.5s for validation
        
        # Check if we got any samples
        if len(audio_array) == 0:
            return False, "Audio file is empty"
        
        return True, "Valid audio file"
    
    except Exception as e:
        return False, f"Invalid audio file: {str(e)}"


def extract_mfcc_from_file_path(file_path: str) -> np.ndarray:
    """
    Helper function to extract MFCC from a file path (useful for testing)
    
    Args:
        file_path: Path to audio file (.wav, .mp3, etc.)
    
    Returns:
        MFCC features of shape (40, 100, 1)
    """
    with open(file_path, 'rb') as f:
        audio_bytes = f.read()
    
    return extract_mfcc(audio_bytes)
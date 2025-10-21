import tensorflow as tf
import numpy as np
from app.config import settings

class VGGPredictor:
    def __init__(self):
        self.model = None
    
    def _build_vgg_architecture(self):
        """
        Rebuild the exact VGG architecture from your training notebook.
        This MUST match your training code exactly!
        """
        from tensorflow import keras
        
        model = keras.Sequential([
            # Block 1
            keras.layers.Conv2D(32, (3, 3), activation='relu', padding='same', 
                              input_shape=(40, 100, 1)),
            keras.layers.Conv2D(32, (3, 3), activation='relu', padding='same'),
            keras.layers.MaxPooling2D((2, 2)),
            
            # Block 2
            keras.layers.Conv2D(64, (3, 3), activation='relu', padding='same'),
            keras.layers.Conv2D(64, (3, 3), activation='relu', padding='same'),
            keras.layers.MaxPooling2D((2, 2)),
            
            # Block 3
            keras.layers.Conv2D(128, (3, 3), activation='relu', padding='same'),
            keras.layers.Conv2D(128, (3, 3), activation='relu', padding='same'),
            keras.layers.MaxPooling2D((2, 2)),
            
            # Classifier
            keras.layers.Flatten(),
            keras.layers.Dense(128, activation='relu'),
            keras.layers.Dropout(0.5),
            keras.layers.Dense(1, activation='sigmoid')
        ])
        
        return model
    
    def load_model(self):
        """
        Load the trained VGG model.
        Strategy: Build architecture first, then load weights.
        This avoids the Keras version incompatibility issue.
        """
        try:
            print(f"🔨 Building VGG model architecture...")
            self.model = self._build_vgg_architecture()
            
            print(f"📦 Loading weights from {settings.MODEL_PATH}...")
            
            # Load weights from the .h5 file
            self.model.load_weights(settings.MODEL_PATH)
            
            print(f"✅ VGG model loaded successfully!")
            print(f"   Model input shape: {self.model.input_shape}")
            print(f"   Model output shape: {self.model.output_shape}")
            
        except Exception as e:
            print(f"❌ Failed to load model")
            print(f"   Error: {str(e)}")
            print(f"\n💡 Troubleshooting:")
            print(f"   1. Make sure {settings.MODEL_PATH} exists")
            print(f"   2. Verify the model architecture matches your training code")
            print(f"   3. Re-save model in Colab: vgg_model.save('model_v2.keras')")
            raise RuntimeError(f"Model loading failed: {str(e)}")
    
    def predict(self, mfcc_features: np.ndarray) -> float:
        """
        Predict normality score (0-100)
        
        Your VGG model outputs:
        - Shape: (1,) with sigmoid activation
        - Value close to 0 = Normal
        - Value close to 1 = Abnormal
        
        We convert to "normality score":
        - 100 = Definitely normal
        - 0 = Definitely abnormal
        
        Args:
            mfcc_features: Preprocessed MFCC array of shape (40, 100, 1)
        
        Returns:
            Confidence score (0-100) where higher = more normal
        """
        if self.model is None:
            raise RuntimeError("Model not loaded. Call load_model() first.")
        
        # Add batch dimension: (40, 100, 1) -> (1, 40, 100, 1)
        input_data = np.expand_dims(mfcc_features, axis=0)
        
        # Get prediction
        prediction = self.model.predict(input_data, verbose=0)
        
        # Extract scalar value
        abnormal_probability = float(prediction[0][0])
        
        # Convert to normality score (invert the abnormal probability)
        # abnormal_prob = 0.1 -> normality_score = 90
        # abnormal_prob = 0.9 -> normality_score = 10
        normality_score = (1 - abnormal_probability) * 100
        
        return normality_score

# Global instance
vgg_predictor = VGGPredictor()
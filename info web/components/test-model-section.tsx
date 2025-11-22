"use client"

import type React from "react"
import { useState, useRef, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Upload, Loader2 } from "lucide-react"

export function TestModelSection() {
    // Recording state
    const [isRecording, setIsRecording] = useState(false);
    const [mediaRecorder, setMediaRecorder] = useState<MediaRecorder | null>(null);
    const [countdown, setCountdown] = useState(30);
    const recordedChunksRef = useRef<Blob[]>([]);
    const countdownIntervalRef = useRef<NodeJS.Timeout | null>(null);
    const mediaRecorderRef = useRef<MediaRecorder | null>(null);
    const recordingStopPromiseRef = useRef<Promise<void> | null>(null);
    const recordedFileRef = useRef<File | null>(null);

    // Start recording
    const handleStartRecording = async () => {
      recordedChunksRef.current = [];
      recordedFileRef.current = null;
      setCountdown(30);
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        const recorder = new MediaRecorder(stream);
        setMediaRecorder(recorder);
        mediaRecorderRef.current = recorder;
        setIsRecording(true);
        recorder.start();
        recorder.ondataavailable = (e) => {
          if (e.data.size > 0) {
            recordedChunksRef.current.push(e.data);
          }
        };
        
        // Create a promise that resolves when recording stops
        let resolveStopPromise: (() => void) | null = null;
        recordingStopPromiseRef.current = new Promise<void>((resolve) => {
          resolveStopPromise = resolve;
        });
        
        recorder.onstop = () => {
          const audioBlob = new Blob(recordedChunksRef.current, { type: 'audio/wav' });
          const recordedFile = new File([audioBlob], 'recorded-audio.wav', { type: 'audio/wav' });
          recordedFileRef.current = recordedFile;
          setFile(recordedFile);
          setIsRecording(false);
          setMediaRecorder(null);
          mediaRecorderRef.current = null;
          setCountdown(30);
          // Clear countdown interval
          if (countdownIntervalRef.current) {
            clearInterval(countdownIntervalRef.current);
            countdownIntervalRef.current = null;
          }
          // Stop all tracks to release microphone
          stream.getTracks().forEach(track => track.stop());
          // Resolve the promise
          if (resolveStopPromise) {
            resolveStopPromise();
            recordingStopPromiseRef.current = null;
          }
        };
      } catch (err) {
        alert('Could not access microphone.');
        setIsRecording(false);
        setCountdown(30);
      }
    };

    // Stop recording
    const handleStopRecording = () => {
      if (mediaRecorder && isRecording) {
        mediaRecorder.stop();
      }
    };

    // Countdown timer effect
    useEffect(() => {
      if (isRecording && countdown > 0) {
        countdownIntervalRef.current = setInterval(() => {
          setCountdown((prev) => {
            if (prev <= 1) {
              // Auto-stop recording when countdown reaches 0
              if (mediaRecorderRef.current) {
                mediaRecorderRef.current.stop();
              }
              if (countdownIntervalRef.current) {
                clearInterval(countdownIntervalRef.current);
                countdownIntervalRef.current = null;
              }
              return 0;
            }
            return prev - 1;
          });
        }, 1000);
      } else {
        if (countdownIntervalRef.current) {
          clearInterval(countdownIntervalRef.current);
          countdownIntervalRef.current = null;
        }
      }

      return () => {
        if (countdownIntervalRef.current) {
          clearInterval(countdownIntervalRef.current);
          countdownIntervalRef.current = null;
        }
      };
    }, [isRecording, countdown]);
  const [file, setFile] = useState<File | null>(null)
  const [isDragging, setIsDragging] = useState(false)

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(true)
  }

  const handleDragLeave = () => {
    setIsDragging(false)
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(false)
    const droppedFile = e.dataTransfer.files[0]
    if (droppedFile && droppedFile.type.startsWith("audio/")) {
      recordedFileRef.current = null; // Clear recorded file when uploading
      setFile(droppedFile)
    }
  }

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0]
    if (selectedFile) {
      recordedFileRef.current = null; // Clear recorded file when uploading
      setFile(selectedFile)
    }
  }

  const handleUploadClick = () => {
    document.getElementById('audio-upload')?.click()
  }

  const [isProcessing, setIsProcessing] = useState(false)
  const [predictionResult, setPredictionResult] = useState<any>(null)

  const handleSubmitAudio = async (e: React.FormEvent) => {
    e.preventDefault()
    
    // If recording is active, stop it first and wait for the file to be ready
    if (isRecording && mediaRecorderRef.current) {
      // Stop recording
      mediaRecorderRef.current.stop()
      // Wait for the recording to finish processing
      if (recordingStopPromiseRef.current) {
        await recordingStopPromiseRef.current
      }
    }
    
    // Use the file from ref (if recording just stopped) or from state (if uploaded)
    const currentFile = recordedFileRef.current || file
    if (!currentFile) {
      alert('Please record or upload an audio file first.')
      return
    }

    setIsProcessing(true)
    setPredictionResult(null)

    try {
      const formData = new FormData()
      formData.append('file', currentFile)

      const response = await fetch('https://tractorcare-backend.onrender.com/demo/quick-test', {
        method: 'POST',
        body: formData,
      })

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({ detail: 'Unknown error' }))
        throw new Error(errorData.detail || `HTTP error! status: ${response.status}`)
      }

      const result = await response.json()
      setPredictionResult(result)
    } catch (error: any) {
      const errorMessage = error.message || 'Failed to analyze audio. Please try again.'
      setPredictionResult({
        error: true,
        message: errorMessage
      })
    } finally {
      setIsProcessing(false)
    }
  }

  return (
    <section id="test-model" className="py-24 px-4 bg-[#1a4d3a]">
      <div className="container mx-auto">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-12">
            <h2 className="text-4xl md:text-5xl font-bold mb-6">
              Test Our <span className="text-primary">AI Model</span>
            </h2>
            <p className="text-xl text-gray-300 text-pretty max-w-3xl mx-auto">
              Ready for TractorCare to keep your tractor running? Upload an audio recording of your tractor engine and
              get instant AI-powered analysis powered by our transfer learning model trained on real tractor sounds.
            </p>
          </div>

          <div className="max-w-2xl mx-auto">
            <Card className="border-primary/20 bg-[#0f3829] shadow-xl">
              <CardContent className="pt-8 pb-8">
                <h3 className="text-lg font-bold mb-6 text-white">Upload a tractor audio clip to get an instant health prediction. No account needed—try it now!</h3>

                <form onSubmit={handleSubmitAudio} className="space-y-6">
                  <div
                    className={`relative border-2 border-dashed rounded-lg p-12 text-center transition-colors ${
                      isDragging
                        ? "border-primary bg-primary/5"
                        : file
                          ? "border-primary/50 bg-primary/5"
                          : "border-gray-600 hover:border-primary/50"
                    }`}
                    onDragOver={handleDragOver}
                    onDragLeave={handleDragLeave}
                    onDrop={handleDrop}
                  >
                    <input
                      type="file"
                      accept="audio/*"
                      onChange={handleFileChange}
                      className="hidden"
                      id="audio-upload"
                    />
                    <div className="flex flex-col items-center gap-4">
                      <div className="w-16 h-16 rounded-full bg-primary/20 flex items-center justify-center">
                        <Upload className="h-8 w-8 text-primary" />
                      </div>
                      <div>
                        <p className="text-lg font-semibold text-white mb-1">{file ? file.name : "Select Audio"}</p>
                        <p className="text-sm text-gray-400">Upload Audio File(WAV, less 30s)</p>
                      </div>
                      <div className="mt-4 flex flex-col items-center gap-2 w-full max-w-xs">
                        {!isRecording ? (
                          <>
                            <Button 
                              type="button" 
                              variant="outline" 
                              className="border-primary text-primary w-full" 
                              onClick={(e) => {
                                e.stopPropagation();
                                handleStartRecording();
                              }}
                            >
                              <span role="img" aria-label="record">🎤</span> Record Audio
                            </Button>
                            <Button 
                              type="button" 
                              variant="outline" 
                              className="border-gray-500 text-gray-300 hover:border-gray-400 hover:text-gray-200 w-full" 
                              onClick={(e) => {
                                e.stopPropagation();
                                handleUploadClick();
                              }}
                            >
                              <Upload className="h-4 w-4 mr-2" /> Upload File
                            </Button>
                          </>
                        ) : (
                          <>
                            <Button 
                              type="button" 
                              variant="destructive" 
                              className="w-full"
                              onClick={(e) => {
                                e.stopPropagation();
                                handleStopRecording();
                              }}
                            >
                              <span role="img" aria-label="stop">⏹️</span> Stop Recording
                            </Button>
                            <div className="flex flex-col items-center gap-2 mt-3">
                              <div className="flex items-center gap-2">
                                <span className="text-red-500 text-sm font-semibold animate-pulse">Recording...</span>
                              </div>
                              <div className="flex items-center justify-center w-16 h-16 rounded-full bg-red-500/20 border-2 border-red-500">
                                <span className="text-red-500 text-2xl font-bold">
                                  {countdown}
                                </span>
                              </div>
                              <span className="text-gray-400 text-xs">seconds remaining</span>
                            </div>
                          </>
                        )}
                      </div>
                    </div>
                  </div>

                  <Button
                    type="submit"
                    size="lg"
                    className="w-full text-base bg-primary hover:bg-primary/90 text-white"
                    disabled={(!file && !isRecording) || isProcessing}
                  >
                    {isProcessing ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        Analyzing...
                      </>
                    ) : isRecording ? (
                      "Stop & Predict"
                    ) : (
                      "Predict Tractor Health"
                    )}
                  </Button>
                  
                  {predictionResult && !predictionResult.error && (
                    <div className="mt-4 p-4 rounded-lg bg-[#1a4d3a] border border-primary/30">
                      <div className="space-y-2">
                        <div className="flex items-center gap-2">
                          <span className={`text-2xl ${
                            predictionResult.interpretation?.severity === 'critical' ? 'text-red-500' :
                            predictionResult.interpretation?.severity === 'high' ? 'text-orange-500' :
                            predictionResult.interpretation?.severity === 'medium' ? 'text-yellow-500' :
                            'text-green-500'
                          }`}>
                            {predictionResult.interpretation?.severity === 'critical' ? '🔴' :
                             predictionResult.interpretation?.severity === 'high' ? '🟠' :
                             predictionResult.interpretation?.severity === 'medium' ? '🟡' : '✅'}
                          </span>
                          <h4 className="font-semibold text-white">{predictionResult.interpretation?.message}</h4>
                        </div>
                        <p className="text-sm text-gray-300">{predictionResult.interpretation?.recommendation}</p>
                        <div className="text-xs text-gray-400 space-y-1">
                          <p>Confidence: {(predictionResult.prediction?.confidence * 100).toFixed(1)}%</p>
                          <p>Anomaly Score: {(predictionResult.prediction?.anomaly_score * 100).toFixed(1)}%</p>
                          <p>Duration: {predictionResult.audio_info?.duration_seconds}s</p>
                        </div>
                      </div>
                    </div>
                  )}

                  {predictionResult?.error && (
                    <div className="mt-4 p-4 rounded-lg bg-red-900/30 border border-red-500/50">
                      <div className="flex items-center gap-2">
                        <span className="text-xl">❌</span>
                        <p className="text-sm text-red-200">{predictionResult.message}</p>
                      </div>
                    </div>
                  )}
                </form>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </section>
  )
}

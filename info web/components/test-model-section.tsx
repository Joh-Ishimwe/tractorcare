"use client"

import type React from "react"
import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Upload } from "lucide-react"

export function TestModelSection() {
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
      setFile(droppedFile)
    }
  }

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0]
    if (selectedFile) {
      setFile(selectedFile)
    }
  }

  const [isProcessing, setIsProcessing] = useState(false)
  const [predictionResult, setPredictionResult] = useState<any>(null)

  const handleSubmitAudio = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!file) return

    setIsProcessing(true)
    setPredictionResult(null)

    try {
      const formData = new FormData()
      formData.append('file', file)

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
                      className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
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
                    </div>
                  </div>

                  <Button
                    type="submit"
                    size="lg"
                    className="w-full text-base bg-primary hover:bg-primary/90 text-white"
                    disabled={!file || isProcessing}
                  >
                    {isProcessing ? "Analyzing..." : "Predict Tractor Health"}
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

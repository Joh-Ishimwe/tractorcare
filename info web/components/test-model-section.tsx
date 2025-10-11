"use client"

import type React from "react"
import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Upload, Send, MessageCircle, Mic } from "lucide-react"

export function TestModelSection() {
  const [file, setFile] = useState<File | null>(null)
  const [isDragging, setIsDragging] = useState(false)
  const [chatMode, setChatMode] = useState<"chat" | "voice">("chat")
  const [messages, setMessages] = useState([
    {
      role: "assistant",
      content: "Hello! I'm your AI tractor maintenance assistant. How can I help you with your tractor today?",
    },
  ])
  const [inputValue, setInputValue] = useState("")

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

  const handleSubmitAudio = (e: React.FormEvent) => {
    e.preventDefault()
    if (file) {
      // TODO: Implement audio analysis
      alert("Audio analysis coming soon! We'll analyze your tractor's engine sound for potential issues.")
    }
  }

  const handleSendMessage = (e: React.FormEvent) => {
    e.preventDefault()
    if (inputValue.trim()) {
      setMessages([...messages, { role: "user", content: inputValue }])
      setInputValue("")
      // Simulate AI response
      setTimeout(() => {
        setMessages((prev) => [
          ...prev,
          {
            role: "assistant",
            content: "I'm analyzing your question. This is a demo response. Full AI integration coming soon!",
          },
        ])
      }, 1000)
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
              get instant AI-powered analysis, or chat with our intelligent assistant.
            </p>
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            {/* Audio Upload Section */}
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
                    disabled={!file}
                  >
                    Predict Tractor Health
                  </Button>
                </form>
              </CardContent>
            </Card>

            {/* Chatbot Section */}
            <Card className="border-primary/20 bg-[#0f3829] shadow-xl flex flex-col">
              <CardContent className="pt-8 pb-6 flex flex-col h-full">
                <div className="flex items-center justify-between mb-6">
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 rounded-full bg-primary animate-pulse" />
                    <h3 className="text-lg font-semibold text-white">AI Assistant</h3>
                    <span className="text-xs text-gray-400">Powered by TractorCare AI</span>
                  </div>
                  <div className="flex gap-2">
                    <Button
                      size="sm"
                      variant={chatMode === "chat" ? "default" : "outline"}
                      onClick={() => setChatMode("chat")}
                      className={chatMode === "chat" ? "bg-primary hover:bg-primary/90" : "border-gray-600"}
                    >
                      <MessageCircle className="h-4 w-4 mr-1" />
                      Chat
                    </Button>
                    <Button
                      size="sm"
                      variant={chatMode === "voice" ? "default" : "outline"}
                      onClick={() => setChatMode("voice")}
                      className={chatMode === "voice" ? "bg-primary hover:bg-primary/90" : "border-gray-600"}
                    >
                      <Mic className="h-4 w-4 mr-1" />
                      Voice
                    </Button>
                  </div>
                </div>

                {/* Chat Messages */}
                <div className="flex-1 space-y-4 mb-6 overflow-y-auto max-h-[300px]">
                  {messages.map((message, index) => (
                    <div key={index} className={`flex ${message.role === "user" ? "justify-end" : "justify-start"}`}>
                      <div
                        className={`max-w-[80%] rounded-lg px-4 py-3 ${
                          message.role === "user"
                            ? "bg-primary text-white"
                            : "bg-[#1a4d3a] text-gray-200 border border-gray-700"
                        }`}
                      >
                        <p className="text-sm leading-relaxed">{message.content}</p>
                      </div>
                    </div>
                  ))}
                </div>

                {/* Chat Input */}
                <form onSubmit={handleSendMessage} className="flex gap-2">
                  <input
                    type="text"
                    value={inputValue}
                    onChange={(e) => setInputValue(e.target.value)}
                    placeholder="Ask about your tractor maintenance..."
                    className="flex-1 bg-[#1a4d3a] border border-gray-700 rounded-lg px-4 py-3 text-white placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-primary"
                  />
                  <Button
                    type="submit"
                    size="icon"
                    className="bg-primary hover:bg-primary/90 h-12 w-12"
                    disabled={!inputValue.trim()}
                  >
                    <Send className="h-5 w-5" />
                  </Button>
                </form>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </section>
  )
}

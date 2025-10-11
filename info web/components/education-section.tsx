"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { ChevronLeft, ChevronRight, Play } from "lucide-react"

const educationalContent = [
  {
    id: 1,
    title: "Understanding Tractor Engine Sounds",
    description: "Learn to identify normal vs abnormal engine sounds and what they mean for your tractor's health.",
    type: "video",
    thumbnail: "/tractor-engine-maintenance.jpg",
    duration: "5:30",
  },
  {
    id: 2,
    title: "Preventive Maintenance Best Practices",
    description: "Essential maintenance tips to keep your tractor running smoothly and avoid costly repairs.",
    type: "slides",
    images: ["/tractor-oil-check-maintenance.jpg", "/tractor-filter-replacement.jpg", "/tractor-belt-inspection.jpg"],
  },
  {
    id: 3,
    title: "Common Tractor Issues in Rwanda",
    description: "Discover the most frequent tractor problems faced by Rwandan farmers and how to prevent them.",
    type: "video",
    thumbnail: "/tractor-repair-workshop-rwanda.jpg",
    duration: "7:15",
  },
]

export function EducationSection() {
  const [slideIndexes, setSlideIndexes] = useState<{ [key: number]: number }>({})

  const nextSlide = (contentId: number, maxLength: number) => {
    setSlideIndexes((prev) => ({
      ...prev,
      [contentId]: ((prev[contentId] || 0) + 1) % maxLength,
    }))
  }

  const prevSlide = (contentId: number, maxLength: number) => {
    setSlideIndexes((prev) => ({
      ...prev,
      [contentId]: ((prev[contentId] || 0) - 1 + maxLength) % maxLength,
    }))
  }

  return (
    <section id="education" className="py-24 px-4 bg-black">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold text-white mb-4">Learn & Grow</h2>
          <p className="text-lg text-gray-400 max-w-2xl mx-auto">
            Access free educational resources to master tractor maintenance and maximize your farming productivity
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          {educationalContent.map((content) => (
            <div
              key={content.id}
              className="group bg-zinc-900 rounded-2xl overflow-hidden border border-zinc-800 hover:border-green-500/50 transition-all duration-300"
            >
              {/* Media Container */}
              <div className="relative aspect-video bg-zinc-950 overflow-hidden">
                {content.type === "video" ? (
                  <>
                    <img
                      src={content.thumbnail || "/placeholder.svg"}
                      alt={content.title}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                    />
                    <div className="absolute inset-0 bg-black/40 flex items-center justify-center">
                      <div className="w-16 h-16 rounded-full bg-green-500 flex items-center justify-center group-hover:scale-110 transition-transform">
                        <Play className="w-8 h-8 text-black fill-black ml-1" />
                      </div>
                    </div>
                    <div className="absolute bottom-4 right-4 bg-black/80 px-3 py-1 rounded-full text-sm text-white">
                      {content.duration}
                    </div>
                  </>
                ) : (
                  <>
                    <img
                      src={content.images[slideIndexes[content.id] || 0]}
                      alt={`${content.title} - Slide ${(slideIndexes[content.id] || 0) + 1}`}
                      className="w-full h-full object-cover transition-opacity duration-300"
                    />
                    {/* Slide Navigation */}
                    <button
                      onClick={() => prevSlide(content.id, content.images.length)}
                      className="absolute left-4 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-black/60 hover:bg-black/80 flex items-center justify-center transition-colors"
                      aria-label="Previous slide"
                    >
                      <ChevronLeft className="w-6 h-6 text-white" />
                    </button>
                    <button
                      onClick={() => nextSlide(content.id, content.images.length)}
                      className="absolute right-4 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-black/60 hover:bg-black/80 flex items-center justify-center transition-colors"
                      aria-label="Next slide"
                    >
                      <ChevronRight className="w-6 h-6 text-white" />
                    </button>
                    {/* Slide Indicators */}
                    <div className="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-2">
                      {content.images.map((_, idx) => (
                        <button
                          key={idx}
                          onClick={() => setSlideIndexes((prev) => ({ ...prev, [content.id]: idx }))}
                          className={`w-2 h-2 rounded-full transition-all ${
                            (slideIndexes[content.id] || 0) === idx
                              ? "bg-green-500 w-6"
                              : "bg-white/50 hover:bg-white/80"
                          }`}
                          aria-label={`Go to slide ${idx + 1}`}
                        />
                      ))}
                    </div>
                  </>
                )}
              </div>

              {/* Content */}
              <div className="p-6">
                <h3 className="text-xl font-bold text-white mb-3 group-hover:text-green-500 transition-colors">
                  {content.title}
                </h3>
                <p className="text-gray-400 mb-6 leading-relaxed">{content.description}</p>
                <Button
                  variant="outline"
                  className="w-full border-zinc-700 hover:border-green-500 hover:bg-green-500/10 hover:text-green-500 transition-all bg-transparent"
                >
                  Read More
                </Button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

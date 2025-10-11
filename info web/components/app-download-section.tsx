"use client"

import { Button } from "@/components/ui/button"
import { Smartphone, Download, Zap, Wifi, Bell } from "lucide-react"

export function AppDownloadSection() {
  return (
    <section className="py-24 px-4 bg-gradient-to-b from-black to-zinc-950 relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute inset-0 opacity-20">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-green-500/20 rounded-full blur-3xl" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-green-500/10 rounded-full blur-3xl" />
      </div>

      <div className="max-w-7xl mx-auto relative z-10">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          {/* Left Content */}
          <div>
            <div className="inline-flex items-center gap-2 bg-green-500/10 border border-green-500/20 rounded-full px-4 py-2 mb-6">
              <Smartphone className="w-4 h-4 text-green-500" />
              <span className="text-sm font-medium text-green-500">Mobile App Available</span>
            </div>

            <h2 className="text-4xl md:text-5xl lg:text-6xl font-bold text-white mb-6 leading-tight">
              Get the App Today
            </h2>
            <p className="text-xl text-gray-400 mb-8 leading-relaxed">
              Take TractorCare with you wherever you go. Monitor your tractor's health, get instant alerts, and access
              maintenance guides right from your phone.
            </p>

            {/* Features */}
            <div className="space-y-4 mb-10">
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-lg bg-green-500/10 flex items-center justify-center flex-shrink-0">
                  <Wifi className="w-5 h-5 text-green-500" />
                </div>
                <div>
                  <h3 className="text-white font-semibold mb-1">Offline Mode</h3>
                  <p className="text-gray-400 text-sm">Works without internet connection in remote areas</p>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-lg bg-green-500/10 flex items-center justify-center flex-shrink-0">
                  <Bell className="w-5 h-5 text-green-500" />
                </div>
                <div>
                  <h3 className="text-white font-semibold mb-1">Real-time Alerts</h3>
                  <p className="text-gray-400 text-sm">Get notified about maintenance needs instantly</p>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-lg bg-green-500/10 flex items-center justify-center flex-shrink-0">
                  <Zap className="w-5 h-5 text-green-500" />
                </div>
                <div>
                  <h3 className="text-white font-semibold mb-1">Quick Analysis</h3>
                  <p className="text-gray-400 text-sm">Get results in seconds with on-device AI</p>
                </div>
              </div>
            </div>

            {/* Download Buttons */}
            <div className="flex flex-col sm:flex-row gap-4">
              <Button
                size="lg"
                className="bg-green-500 hover:bg-green-600 text-black font-semibold text-base h-14 px-8 group"
              >
                <Download className="w-5 h-5 mr-2 group-hover:animate-bounce" />
                Download for Android
              </Button>
              <Button
                size="lg"
                variant="outline"
                className="border-zinc-700 hover:border-green-500 hover:bg-green-500/10 hover:text-green-500 text-base h-14 px-8 bg-transparent"
              >
                <Download className="w-5 h-5 mr-2" />
                Download for iOS
              </Button>
            </div>

            <p className="text-sm text-gray-500 mt-6">Free to download • Available in Kinyarwanda, English & French</p>
          </div>

          {/* Right - Phone Mockup */}
          <div className="relative lg:pl-12">
            <div className="relative mx-auto max-w-sm">
              {/* Glow effect */}
              <div className="absolute inset-0 bg-green-500/20 blur-3xl rounded-full scale-150" />

              {/* Phone mockup */}
              <div className="relative bg-zinc-900 rounded-[3rem] p-3 border-4 border-zinc-800 shadow-2xl">
                <div className="bg-black rounded-[2.5rem] overflow-hidden">
                  {/* Notch */}
                  <div className="h-8 bg-black relative">
                    <div className="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-7 bg-zinc-950 rounded-b-3xl" />
                  </div>

                  {/* Screen content */}
                  <div className="aspect-[9/16] bg-gradient-to-b from-zinc-950 to-black p-6">
                    <img
                      src="/mobile-app-interface-tractor-maintenance-dashboard.jpg"
                      alt="TractorCare Mobile App"
                      className="w-full h-full object-cover rounded-2xl"
                    />
                  </div>
                </div>
              </div>

              {/* Floating elements */}
              <div className="absolute -top-4 -right-4 bg-green-500 text-black px-4 py-2 rounded-full text-sm font-semibold shadow-lg animate-bounce">
                4.8★ Rating
              </div>
              <div className="absolute -bottom-4 -left-4 bg-zinc-900 border border-zinc-800 text-white px-4 py-2 rounded-full text-sm font-semibold shadow-lg">
                10K+ Downloads
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

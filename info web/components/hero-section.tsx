"use client"

import { Button } from "@/components/ui/button"
import { ArrowRight, Shield, Zap, TrendingDown } from "lucide-react"
import Link from "next/link"

export function HeroSection() {
  return (
    <section className="min-h-screen flex items-center justify-center pt-16 px-4 bg-gradient-to-b from-black to-zinc-950 relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute inset-0 opacity-20">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-green-500/20 rounded-full blur-3xl" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-green-500/10 rounded-full blur-3xl" />
      </div>

  <div className="max-w-7xl mx-auto relative z-10 pl-4">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          {/* Left Content */}
          <div>

            <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold text-white mb-6 leading-tight">
              Unlock Tractor Health Insights with AI
            </h1>
            <p className="text-xl text-gray-400 mb-8 leading-relaxed">
              Boost reliability and reduce downtime with predictive maintenance. Get instant diagnostics for your
            tractors using AI-powered audio analysis, designed for Rwanda's smallholder farmers.
            </p>

            {/* Features */}
            <div className="space-y-4 mb-10">
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-lg bg-green-500/10 flex items-center justify-center flex-shrink-0">
                  <Shield className="w-5 h-5 text-green-500" />
                </div>
                <div>
                  <h3 className="text-white font-semibold mb-1">Predictive Maintenance</h3>
                  <p className="text-gray-400 text-sm">Detect issues before they become costly breakdowns</p>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-lg bg-green-500/10 flex items-center justify-center flex-shrink-0">
                  <Zap className="w-5 h-5 text-green-500" />
                </div>
                <div>
                  <h3 className="text-white font-semibold mb-1">Instant AI Analysis</h3>
                  <p className="text-gray-400 text-sm">Upload audio and get diagnostic results in seconds</p>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-lg bg-green-500/10 flex items-center justify-center flex-shrink-0">
                  <TrendingDown className="w-5 h-5 text-green-500" />
                </div>
                <div>
                  <h3 className="text-white font-semibold mb-1">Reduce Costs</h3>
                  <p className="text-gray-400 text-sm">Save up to 20% on maintenance with early detection</p>
                </div>
              </div>
            </div>

            {/* CTA Buttons */}
            <div className="flex flex-col sm:flex-row gap-4 items-center justify-center">
              <Button
                asChild
                size="lg"
                className="bg-green-500 hover:bg-green-600 text-black font-semibold text-base h-14 px-8 group"
              >
                <Link href="">
                  Get Started 
                  <ArrowRight className="ml-2 h-5 w-5 group-hover:translate-x-1 transition-transform" />
                </Link>
              </Button>
              <Button
                asChild
                variant="outline"
                size="lg"
                className="border-zinc-700 hover:border-green-500 hover:bg-green-500/10 hover:text-green-500 text-base h-14 px-8 bg-transparent"
              >
                <Link href="#test-model">Test Our Model</Link>
              </Button>
            </div>

            <p className="text-sm text-gray-500 mt-6 text-center">
              Trusted by 50+ cooperatives • Supporting 10,000+ farmers across Rwanda
            </p>
          </div>

          {/* Right - Tractor Image */}
          <div className="relative lg:pl-12">
            <div className="relative">
              {/* Glow effect */}
              <div className="absolute inset-0 bg-green-500/20 blur-3xl rounded-full scale-150" />

              {/* Image container */}
              <div className="relative rounded-3xl overflow-hidden border-4 border-zinc-800 shadow-2xl">
                <img
                  src="/modern-tractor-in-field-rwanda-agriculture.jpg"
                  alt="Tractor in field"
                  className="w-full h-full object-cover aspect-[4/3]"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

import { Button } from "@/components/ui/button"
import { ArrowRight } from "lucide-react"
import Link from "next/link"

export function HeroSection() {
  return (
    <section id="hero" className="min-h-screen flex items-center justify-center pt-16 px-4">
      <div className="container mx-auto">
        <div className="max-w-4xl mx-auto text-center space-y-8">
          <div className="inline-block">
            <span className="text-sm font-mono text-primary">AI-Powered Maintenance</span>
          </div>

          <h1 className="text-5xl md:text-7xl font-bold tracking-tight text-balance">
            Unlock Tractor Health Insights with AI
          </h1>

          <p className="text-xl md:text-2xl text-muted-foreground max-w-3xl mx-auto text-pretty leading-relaxed">
            Boost reliability and reduce downtime with predictive maintenance. Get instant diagnostics for your
            tractors using AI-powered audio analysis, designed for Rwanda's smallholder farmers.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 pt-4">
            <Button asChild size="lg" className="text-base px-8 h-12">
              <Link href="#test-model">
                Test Our Model
                <ArrowRight className="ml-2 h-5 w-5" />
              </Link>
            </Button>
            <Button asChild variant="outline" size="lg" className="text-base px-8 h-12 bg-transparent">
              <Link href="#how-it-works">See How It Works</Link>
            </Button>
          </div>

          <div className="pt-12">
            <div className="relative aspect-video rounded-lg overflow-hidden border border-border bg-card">
              <img src="/modern-tractor-in-field-rwanda-agriculture.jpg" alt="Tractor in field" className="w-full h-full object-cover" />
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

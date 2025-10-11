import { Card, CardContent } from "@/components/ui/card"
import { Shield, Mic, Smartphone } from "lucide-react"

const features = [
  {
    icon: Shield,
    title: "Rule-Based Scheduling",
    description:
      "Follows factory guidelines for routine tasks like oil changes and filter checks, adjusted for Rwanda's terrain.",
  },
  {
    icon: Mic,
    title: "AI Audio Detection",
    description: "Uses model to detect anomalies in engine sounds, preventing breakdowns.",
  },
  {
    icon: Smartphone,
    title: "Offline-First App",
    description: "App for low-connectivity areas—record audio, get alerts, and sync when online.",
  },
]

export function AboutSection() {
  return (
    <section id="about" className="py-24 px-4">
      <div className="container mx-auto">
        <div className="max-w-3xl mx-auto text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold mb-6">About TractorCare</h2>
          <p className="text-xl text-muted-foreground text-pretty">
            Empowering Rwandan farmers with AI-driven tractor maintenance to build a sustainable agricultural future.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-6 max-w-6xl mx-auto">
          {features.map((feature, index) => (
            <Card key={index} className="border-border bg-card hover:bg-accent/5 transition-colors">
              <CardContent className="pt-8 pb-8 text-center space-y-4">
                <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary/10">
                  <feature.icon className="w-8 h-8 text-primary" />
                </div>
                <h3 className="text-xl font-semibold">{feature.title}</h3>
                <p className="text-muted-foreground leading-relaxed">{feature.description}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}

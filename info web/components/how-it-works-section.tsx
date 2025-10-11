import { Card, CardContent } from "@/components/ui/card"
import { Mic, Brain, Bell } from "lucide-react"

const steps = [
  {
    icon: Mic,
    title: "1. Record Engine Sound",
    description: "Use the mobile app to capture a short audio clip of your tractor engine while running.",
  },
  {
    icon: Brain,
    title: "2. AI Analysis",
    description: "Our ResNet-like CNN analyzes the audio for anomalies, predicting failures with 92.9% accuracy.",
  },
  {
    icon: Bell,
    title: "3. Get Alerts & Schedule",
    description: "Receive instant alerts and rule-based maintenance schedules, with offline support for rural areas.",
  },
]

export function HowItWorksSection() {
  return (
    <section id="how-it-works" className="py-24 px-4 bg-muted/30">
      <div className="container mx-auto">
        <div className="max-w-3xl mx-auto text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold mb-6">How TractorCare Works</h2>
          <p className="text-xl text-muted-foreground text-pretty">
            Simple, AI-powered steps to keep your tractors running smoothly.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-6 max-w-6xl mx-auto">
          {steps.map((step, index) => (
            <Card key={index} className="border-border bg-card">
              <CardContent className="pt-8 pb-8 space-y-6">
                <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary/10">
                  <step.icon className="w-8 h-8 text-primary" />
                </div>
                <div className="space-y-3">
                  <h3 className="text-xl font-semibold">{step.title}</h3>
                  <p className="text-muted-foreground leading-relaxed">{step.description}</p>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}

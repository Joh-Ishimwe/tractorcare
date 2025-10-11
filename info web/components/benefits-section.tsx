import { Card, CardContent } from "@/components/ui/card"
import { Wrench, DollarSign, Wifi, Users } from "lucide-react"

const benefits = [
  {
    icon: Wrench,
    title: "Reduce Downtime",
    description: "Predict failures 90% accurately, saving days of work.",
  },
  {
    icon: DollarSign,
    title: "Save Costs",
    description: "Avoid RWF 50,000+ in emergency repairs per failure.",
  },
  {
    icon: Wifi,
    title: "Offline Access",
    description: "Works without internet in remote fields.",
  },
  {
    icon: Users,
    title: "Cooperative Tools",
    description: "Dashboard for fleet management and member coordination.",
  },
]

export function BenefitsSection() {
  return (
    <section id="benefits" className="py-24 px-4 bg-muted/30">
      <div className="container mx-auto">
        <div className="max-w-3xl mx-auto text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold mb-6">Benefits for Rwandan Farmers</h2>
          <p className="text-xl text-muted-foreground text-pretty">
            Affordable, offline-ready technology to boost productivity.
          </p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6 max-w-6xl mx-auto">
          {benefits.map((benefit, index) => (
            <Card key={index} className="border-border bg-card text-center">
              <CardContent className="pt-8 pb-8 space-y-4">
                <div className="inline-flex items-center justify-center w-14 h-14 rounded-full bg-primary/10">
                  <benefit.icon className="w-7 h-7 text-primary" />
                </div>
                <h3 className="text-lg font-semibold">{benefit.title}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{benefit.description}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}

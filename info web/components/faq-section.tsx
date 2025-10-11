import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion"

const faqs = [
  {
    question: "How does the AI detect tractor issues?",
    answer:
      "Our ResNet-like CNN analyzes audio clips for anomalies, achieving 92.9% accuracy on engine sounds. The model has been trained on thousands of tractor audio samples to identify patterns that indicate potential failures.",
  },
  {
    question: "Does it work offline?",
    answer:
      "Yes! The mobile app stores data locally and syncs when online, perfect for rural Rwanda. You can record audio and get predictions even without an internet connection.",
  },
  {
    question: "What tractors are supported?",
    answer:
      "Optimized for older models like MF 240/375, with rule-based schedules from manufacturer guidelines. We continue to expand support for additional tractor models based on user feedback.",
  },
  {
    question: "Is it free for cooperatives?",
    answer:
      "Yes, free for smallholder cooperatives. Premium features for larger fleets include advanced analytics, fleet management dashboards, and priority support.",
  },
]

export function FAQSection() {
  return (
    <section id="faq" className="py-24 px-4">
      <div className="container mx-auto">
        <div className="max-w-3xl mx-auto">
          <div className="text-center mb-12">
            <h2 className="text-4xl md:text-5xl font-bold mb-6">Frequently Asked Questions</h2>
            <p className="text-xl text-muted-foreground text-pretty">Got questions? We've got answers.</p>
          </div>

          <Accordion type="single" collapsible className="space-y-4">
            {faqs.map((faq, index) => (
              <AccordionItem
                key={index}
                value={`item-${index}`}
                className="border border-border rounded-lg px-6 bg-card"
              >
                <AccordionTrigger className="text-left hover:no-underline py-5">
                  <span className="font-semibold">{faq.question}</span>
                </AccordionTrigger>
                <AccordionContent className="text-muted-foreground pb-5 leading-relaxed">{faq.answer}</AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </div>
      </div>
    </section>
  )
}

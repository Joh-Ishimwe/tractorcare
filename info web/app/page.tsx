import { HeroSection } from "@/components/hero-section"
import { AboutSection } from "@/components/about-section"
import { HowItWorksSection } from "@/components/how-it-works-section"
import { TestModelSection } from "@/components/test-model-section"
import { BenefitsSection } from "@/components/benefits-section"
import { EducationSection } from "@/components/education-section"
import { AppDownloadSection } from "@/components/app-download-section"
import { FAQSection } from "@/components/faq-section"
import { ContactSection } from "@/components/contact-section"
import { Navigation } from "@/components/navigation"
import { Footer } from "@/components/footer"

export default function Home() {
  return (
    <main className="min-h-screen">
      <Navigation />
      <HeroSection />
      <AboutSection />
      <HowItWorksSection />
      <TestModelSection />
      <BenefitsSection />
      <EducationSection />
      <AppDownloadSection />
      <FAQSection />
      <ContactSection />
      <Footer />
    </main>
  )
}

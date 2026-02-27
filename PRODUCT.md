# StickyNicky — Catch A Tiger By The Tail 🐯

## What It Is
AI Visibility monitoring micro-SaaS. Track what AI models (ChatGPT, Gemini, Perplexity) say about your brand. Modeled after gumshoe.ai.

## Gumshoe.ai Feature Map (What We're Cloning)

### Core Features
1. **Brand Visibility** — How often your brand is mentioned across relevant topics in AI search
2. **Competitive Rank** — How you stack up against competitors across topics and models
3. **Persona Visibility** — Brand performance across different buyer personas (CTO vs marketer vs shopper)
4. **Topic Visibility** — Brand performance across a broad set of topic areas
5. **Model Visibility** — Which AI models mention your brand most (ChatGPT vs Gemini vs Perplexity)
6. **Cited Sources** — Top sources cited by AI models about your brand (informs content strategy)

### Workflow
1. User creates a "report" with a focus (e.g., "sustainable clothing")
2. User defines personas (6+ recommended) — different buyer types
3. User defines topics — categories/themes of questions
4. System generates thousands of AI conversations simulating real user queries
5. System analyzes responses for brand mentions, competitor mentions, cited sources
6. Dashboard shows visibility scores, trends, recommendations

### Pricing Model (Gumshoe)
- **Free:** 3 report runs
- **Pay as You Go:** $0.10/conversation
- **Enterprise:** Custom

### Additional Features
- Scheduled reports (recurring monitoring)
- Trend tracking over time
- Optimization recommendations
- AI-assisted content generation (to improve visibility)
- Export/share with team

## Tech Stack (Proposed)
- **Frontend:** Next.js + Tailwind
- **Backend:** Next.js API routes or separate API
- **Database:** Supabase (PostgreSQL)
- **Auth:** Supabase Auth
- **AI APIs:** OpenAI, Google Gemini, Perplexity
- **Payments:** Stripe (usage-based billing)
- **Hosting:** Vercel
- **Queuing:** For async report generation (thousands of API calls)

## Build Method
Using Elvis's agent swarm model — orchestrate multiple coding agents to build this in parallel.

## MVP Scope (Phase 1)
- [ ] Landing page
- [ ] Auth (sign up / sign in)
- [ ] Create a report (brand name, competitors, personas, topics)
- [ ] Run report against ChatGPT + Gemini + Perplexity
- [ ] Dashboard showing brand visibility score
- [ ] Competitive comparison
- [ ] Basic cited sources view

# حكمة (Hikma)

A minimalist iPhone/iPad app that sends a motivational saying from a culture somewhere
in the world every 4 hours — in fluent Arabic, with who said it and where it comes from.
Six a day, 84 over 14 days, never repeated.

## How it works
- **Library:** `Hikma/Resources/Quotes.json` — 100 curated sayings from 38 cultures
  (China, Japan, India, Arab world, Persia, Africa, Europe, the Americas, Māori…).
  Each has: Arabic text, sayer, source, culture, and the original-language text.
  Edit `tools/make_quotes.py` and run `python3 tools/make_quotes.py Hikma/Resources/Quotes.json`
  to add more (keeps ids/texts unique).
- **No repeats:** each 14-day cycle shuffles 84 different quotes. The next cycle puts
  quotes you haven't seen yet first.
- **Notifications:** local notifications (no server, works sideloaded). iOS only keeps
  64 pending, so the app schedules 63 quotes + a reminder to open the app, and tops the
  queue up every time it opens (and in background refresh when iOS allows).
- **Times:** pick one of four 4-hour grids (e.g. 8 ص · 12 م · 4 م · 8 م · 12 ص · 4 ص).

## Build & install
Push to `main` → GitHub Actions builds an unsigned `Hikma.ipa` (Actions tab → latest run →
Artifacts). Install it with Sideloadly, like Noter.

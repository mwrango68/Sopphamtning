# Sophämtning – iPad-app för Stockholm Vatten och Avfall

En liten SwiftUI-app som visar när Stockholm Vatten och Avfall (SVOA) hämtar soporna på din adress.

## Funktioner
- Sök adress med förslag direkt från SVOA
- Nästa hämtning stort ("I morgon", "Om 3 dagar") + lista över alla kärl/avfallsslag
- Adress och senaste resultat sparas – uppdateras automatiskt när appen öppnas (max var 6:e timme)
- Valfri notis kvällen före hämtning (välj klockslag)
- Fungerar på iPad och iPhone, stående och liggande

## Installera på iPad (ingen Mac behövs)
1. Installera **Swift Playgrounds** från App Store på iPaden.
2. Ladda ner repot som zip (GitHub → *Code* → *Download ZIP*) och packa upp i appen Filer.
3. Öppna mappen `Sophamtning.swiftpm` – den öppnas i Swift Playgrounds.
4. Tryck ▶︎ för att köra. Vill du ha den som egen ikon på hemskärmen: *App-inställningar → Installera på hemskärmen* (kräver Apple-ID inloggat i Swift Playgrounds).

Alternativt: öppna `Sophamtning.swiftpm` i Xcode på en Mac och kör på iPaden.

## Datakälla
Appen anropar samma tjänst som SVOA:s webbsida *När kommer sopbilen?*:

| Anrop | Svar |
|---|---|
| `GET …/nar-kommer-sopbilen/AutoCompleteMe?query=<gata>` | `[{ "value": "Gatan 12, Ort, 123 45" }]` |
| `GET …/nar-kommer-sopbilen/Search?address=<adress>` | `[{ "group": "Matavfall", "executionDate": "2026-12-10", "fetchFrequency": "Varje vecka" }]` |

- Det är **inget officiellt/dokumenterat API** – SVOA kan ändra det utan förvarning. Appen visar då ett felmeddelande.
- En native-app påverkas inte av CORS-spärren som stoppar rena webbappar.
- Appen gör bara anrop när du själv söker eller öppnar appen.

## Filer
| Fil | Innehåll |
|---|---|
| `Package.swift` | App-definition för Swift Playgrounds/Xcode |
| `SVOAClient.swift` | Nätverksanrop och tolkning av SVOA-svar |
| `PickupStore.swift` | Tillstånd, cache och automatisk uppdatering |
| `ReminderScheduler.swift` | Lokala notiser kvällen före |
| `ContentView.swift`, `AddressSearchView.swift` | Gränssnitt |

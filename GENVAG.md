# Sophämtning som genväg på hemskärmen (gratis)

Genvägen hämtar dina kommande sophämtningar från Stockholm Vatten och Avfall. Den kan ligga som ikon på hemskärmen och kan påminna dig kvällen före hämtning.
Namnen på åtgärderna står på svenska med engelska namnet inom parentes.

## Steg 1 – Ta reda på exakt adress
SVOA kräver adressen exakt som deras register skriver den.

1. Öppna Safari och gå till (byt `Storgatan 12` mot din gata och ditt nummer):
   `https://www.stockholmvattenochavfall.se/villa-och-radhus/avfallstjanster/nar-kommer-sopbilen/AutoCompleteMe?query=Storgatan 12`
2. Du får en rad som `[{"value":"Storgatan 12, Bromma, 168 00", ...}]`.
3. Kopiera texten inom citattecknen efter `"value":`, alltså `Storgatan 12, Bromma, 168 00`.

## Steg 2 – Bygg genvägen
Öppna appen **Genvägar**, tryck **+** och ge genvägen namnet **Sophämtning**. Lägg sedan till följande åtgärder i den här ordningen via sökfältet *Sök efter åtgärder*.

1. **Text**: klistra in adressen från steg 1.
2. **URL-koda** (*URL Encode*): välj *Koda* med *Text* som indata.
3. **URL**: skriv
   `https://www.stockholmvattenochavfall.se/villa-och-radhus/avfallstjanster/nar-kommer-sopbilen/Search?address=`
   och sätt direkt efter `=` in variabeln **URL-kodad text** via raden med variabler ovanför tangentbordet.
4. **Hämta innehåll från URL** (*Get Contents of URL*): tryck på pilen och lägg under *Rubriker* till
   nyckeln `Accept` med värdet `application/json`.
5. **Upprepa med varje** (*Repeat with Each*) med indata *Innehåll från URL*.
   Lägg följande **inne i** upprepningen:
   1. **Hämta ordboksvärde** (*Get Dictionary Value*): *Värde* för nyckeln `group` i **Upprepningsobjekt**.
      Tryck länge på åtgärden, välj *Byt namn* och kalla den `Kärl`.
   2. **Hämta ordboksvärde**: *Värde* för nyckeln `executionDate` i **Upprepningsobjekt**.
      Byt namn till `Datum`.
   3. **Text**: `🗑 Kärl – Datum`, där *Kärl* och *Datum* är variablerna ovan.
6. Efter *Avsluta upprepning*: **Kombinera text** (*Combine Text*) med *Upprepningsresultat* och avgränsaren *Ny rad*.
7. **Visa resultat** (*Show Result*) med *Kombinerad text*.

Tryck ▶︎ för att testa. Du ska få en lista som:
```
🗑 Matavfall – 2026-11-19
🗑 Restavfall – 2026-11-26
```

## Steg 3 – Lägg genvägen på hemskärmen
1. Öppna genvägen och tryck på namnet högst upp (eller ⓘ längst ner).
2. Välj **Lägg till på hemskärmen**.
3. Tryck på ikonen och välj en bild eller en symbol, till exempel en soptunna i valfri färg.
4. Ändra namnet om du vill och tryck **Lägg till**.

Gör samma sak på iPhonen. Genvägar synkas via iCloud, så du behöver bara bygga genvägen en gång.

## Steg 4 (valfritt) – Automatisk påminnelse kvällen före
Gör en kopia av genvägen (tryck länge → *Duplicera*), döp den till **Sopor i morgon** och ändra den så här:

1. Lägg till **före** *Upprepa med varje*:
   - **Datum**: välj *Ange datum* och skriv `i morgon`.
   - **Formatera datum** (*Format Date*): *Anpassat* format `yyyy-MM-dd`.
2. **Inne i** upprepningen, ersätt Text-steget med:
   - **Om** (*If*): *Datum* **är** *Formaterat datum*
     - **Visa notis** (*Show Notification*): `Ställ fram kärlet: Kärl hämtas i morgon`
   - *Avsluta Om*
3. Ta bort *Kombinera text* och *Visa resultat*.

Skapa sedan en automation som kör den här genvägen varje kväll:
1. Fliken **Automatisering** → **+** → **Tid på dagen**.
2. Välj klockan 19:00, *Dagligen* och **Kör omedelbart**.
3. Välj genvägen **Sopor i morgon**.

## Felsökning
- **Tomt resultat:** adressen är inte exakt rätt. Gör om steg 1 och kopiera hela `value`-texten.
- **Felet "Hämta ordboksvärde" eller ett konstigt svar:** kontrollera rubriken `Accept: application/json` i steg 2.4.
- **Allt slutar plötsligt fungera:** SVOA har troligen ändrat sin tjänst. Kontrollera adressen på deras sida *När kommer sopbilen?*.

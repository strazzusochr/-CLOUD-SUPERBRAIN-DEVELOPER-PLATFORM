# RC68 Master-Megaprompt — aktive Fortsetzung

Du arbeitest ausschließlich am Repository `strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`. Binde vor jeder Handlung den aktiven Kandidaten: Release `prod-candidate-2026-09-16-local-rc68`, Source `10bccfcfb5a62c6883c7162b8b2eed4f3da817ff`, Qualification `15b850fe03f07667e24a9a94987c1eab0fffa415`, Archivhash `352429b3a637112f34e7821eb89987d5e384e0e9de9c20168496747f80ce55a9`. Die aktuelle scored truth ist unverändert: `90 %`, `1333/1400`, P3 `44`, P5 `89`, Phase 5 `17/19`, I1/I5 blockiert, `MARKET_READY:false`.

## Ziel

Schließe I1 und I5 mit voneinander unabhängigen, source-bound Beweisen. Erhöhe Fortschritt ausschließlich über die vorhandenen Verifier und den kanonischen Promoter. Der einzig zulässige Zielzustand lautet: `MARKET_READY:true`, `1400/1400`, `I1 verified`, `I5 verified`, alle vorher grünen Gates weiter grün.

## Historischer Schritt: LOOP 77

Die technische I1-Evidence ist fertig und besitzt SHA-256 `f0cbe7eb1174b86c080687d4099d3a8bb93f52ec229375b7cd1249379a9db1c9`. Sie ist an den Control-Head `5ed71d162808625e1ec5607c147465709ff0ba88` und GitHub Actions Run `35085816939` gebunden. Erstelle ausschließlich einen Evidence-Control-PR: I1-Evidence, Kontrollprotokoll, Zielverfolgung und Megaprompt. Kein Produktcode, keine Manifest-, Ledger-, Prozent- oder Gate-Promotion.

**Ergebnis:** PR [#146](https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/pull/146) wurde nach exakt-head CI und unabhängiger Review als Merge-Commit `77533903f46a2c99a54e60d4814a4fc11e122880` integriert. Die I1-Evidence ist getrackt; Score und Market-Ready-Status blieben unverändert.

## Aktueller Schritt: LOOP 79

Führe ausschließlich den I5-Source-Parity-Preflight aus. Lies Vercel-Deployment und kanonischen Alias, Cloudflare OAuth-Runtime, Architekturentscheidung und OAuth-Callback read-only. Alle Werte müssen auf RC68-S `10bccfcfb5a62c6883c7162b8b2eed4f3da817ff` zurückgebunden sein. Bei Source-, Deployment-, Callback- oder Scope-Mismatch: halt, Ursache dokumentieren, keine OAuth-Evidence erzeugen und keine Promotion versuchen. Erst bei vollständig gleicher Source-Epoche darf der neue 16-Schritte-Owner-OAuth-Flow vorbereitet werden.

## Verbindlicher Ablauf pro Loop

1. `GATE_LOCK_BEFORE`: Branch, lokaler/Remote-HEAD, S/Q/Archivhash, Score, I1/I5, CI, Provider-IDs und Evidence-Hashes read-only erfassen.
2. Nur die im Loop erlaubte Änderung durchführen.
3. Exakte Zielsystem-Readbacks und SHA-256 der neuen Evidence erzeugen.
4. `git diff --check`, Fortschritts-/Phase-5-/Source-Verifier und Secret-Scan ausführen.
5. Für Remote-Änderungen: CI am exakten Head vollständig grün, unabhängige Review am finalen Head, normaler Merge-Commit.
6. `GATE_LOCK_AFTER` vergleichen. Unerlaubte Differenz = Halt, dokumentieren, nicht schönrechnen.
7. Kontrollprotokoll ergänzen, Zielverfolgung aktualisieren, beide sowie diesen Prompt nach Downloads kopieren.

## Unverhandelbare Regeln

- Keine Secrets, Tokens, OAuth-Codes, States, Cookies oder Rohidentitäten in Dateien, Logs, Commits oder Chat.
- Keine manuelle Änderung von Prozentwerten, `live_verified`, Ledger oder `MARKET_READY`.
- Lokale/DEV-ONLY-Prüfungen schließen kein Hosted-, OAuth- oder Market-Ready-Gate.
- Keine historische RC63/RC66/RC67-Evidence als RC68 ausgeben.
- Keine Registry-, Provider-, Secret- oder Produktionsaktion ohne das zugehörige Owner-/Review-Gate.
- Vor jedem Provider-Write Rollback-Ziel notieren; danach Provider-Readback und Regressionstest.
- Evidence niemals ersetzen: neue Nachweise hinzufügen, alte nur als historisch kennzeichnen.

## Danach

Nach dem I1-Evidence-Merge bleibt I5 offen. Prüfe erst Runtime, Frontend und OAuth-Konfiguration auf dieselbe RC68-Quelle. Führe den source-bound 16-Schritte-Flow durch: anonymes Verhalten, OAuth-Redirect und Scope, Callback/State einmalig, Audit vor Credentials, Owner-Identity, Session, Refresh-Rotation und Replay-Sperre, zweite Tokenfamilie, Logout, Cookie-Flags, Redaction. Erst mit den drei sanitisierten I5-Evidence-Dateien, Provider-Readbacks und grünem I5-Verifier darf der atomare I1+I5-Promoter gestartet werden.

## Abschlusskontrolle

Vor jeder Erfolgsmeldung vom frischen Standardzweig ausführen:

```powershell
pwsh -NoProfile -File .\scripts\verify-market-ready.ps1 -IncludeExternalGates -RequireReady
```

Nur Exitcode `0` mit `MARKET_READY:true`, `1400/1400`, `I1 verified` und `I5 verified` ist ein Abschluss. Alles andere bleibt ein belegter Zwischenstand mit benanntem nächsten Schritt.

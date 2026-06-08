## L6 — Cloud & Infrastruktur (Compose, Nginx, CI/CD)

### Implementierung (Ist-Stand)

- `docker-compose.dev.yml` als DEV Runtime (ports via nginx `:8081`).
- `docker-compose.cloud.yml` als pull-based substrate (GHCR) mit Guard-Variablen.
- nginx Konfiguration fuer Cloud Routing vorhanden (`infrastructure/nginx/cloud.conf`).
- CI/CD Guards + Secret-Scanning sind in den Verifiern abgebildet.

### Wiring (L6 ↔ L5/L7)

- L5 laeuft hinter nginx; Cloud Deployment ist gated (Owner approval + echte Tokens/Origins).
- L7 Verifier pruefen Compose Security Hardening + Governance Drift.

### Verifikation

- `npm run verify` prueft Compose Configs, Security Hardening, Cloud Compose Guards, Secret Scan.
- External Gates bleiben blocked ohne echte Hosted URLs/Tokens.

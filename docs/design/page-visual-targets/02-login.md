# 02 Login - Visual Target

Route: `/login`

Goal: controlled auth/onboarding surface. It presents GitHub, Google, Email, and Guest as dry-run provider choices until owner-approved live auth gates exist.

Required layout:
- Compact two-column onboarding shell.
- Left side: sign-in purpose, dry-run provider controls, Workbench handoff.
- Right side: readiness and safety details with closed write/provider gates.
- No fake OAuth redirect or live identity claim.

Element rules:
- Each auth provider button must produce visible `PASS login_dry_run`.
- Guest mode remains dry-run before same-origin Workbench navigation.
- Live OAuth, token use, and provider writes remain false.
- Secret output must remain false.

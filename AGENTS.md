# AGENTS.md – Project Rules (Concise)

## Core Commands
- `dotnet restore` – restore NuGet packages.
- `dotnet build -c Release` – compile the solution.
- `dotnet run --project LavaFacil.Web` – start the web API (exposes REST + GraphQL).
- `dotnet ef database update` – apply EF Core migrations.
- `dotnet test` – run unit/integration tests (if present).

## Style & Architecture
- Follow **Clean Architecture**: Controllers → Services → Repositories.
- Use **Dependency Injection** for all services.
- All configuration via **IOptions** bound to `appsettings.*.json` and environment variables.
- No business logic in Controllers; keep them thin.
- Write **async** code for I/O operations.
- Prefix private fields with `_` and use PascalCase for public members.

## Context Reading Policy
- **Read only files that are directly relevant** to the task (e.g., `Program.cs`, route files, DB models).
- Avoid loading large generated folders (`bin/`, `obj/`, `wwwroot/` assets) unless required.
- Keep token usage low – summarize large files instead of full dump.

## Build & Test Workflow
1. **Setup** – ensure `.env` present; run `dotnet restore`.
2. **Build** – `dotnet build -c Release`.
3. **Migrate** – `dotnet ef database update`.
4. **Run** – `dotnet run --project LavaFacil.Web`.
5. **Verify** – open `http://localhost:5000` and test endpoints.
6. **Test** – `dotnet test` (optional).

## Security Checklist (run before committing)
- [ ] No secrets in source (`.env`, `secrets.json` are .gitignore).
- [ ] Controllers protected with `[Authorize]` where needed.
- [ ] Input sanitization for email bodies.
- [ ] Rate‑limit email sending (`LimitesCorreo`).

## Context‑Clear Protocol
- After completing a feature/task, **run `/clear`** (or issue the clear command) to reset the conversation context and avoid re‑reading historic files.
- Respond *concisely*: no salutations, no redundant introductions, only the requested information.
- When proposing changes, output **only diffs** or the specific block to edit; never dump whole files.
- Limit reading to the exact files mentioned in the task description.

---
*Keep this file < 100 lines.*
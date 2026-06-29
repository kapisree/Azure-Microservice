---
title: Next.js Gateway — Three-Branch Design
date: 2026-06-28
status: approved
---

# Next.js Gateway

A single Next.js app living at `claude/gateway/` that unifies three backend services
(Backstage IDP, ClaimsApi, TaskApi) for Vercel deployment. Three product options are
delivered as three git branches from one codebase.

---

## Repo Layout

```
claude/
  gateway/                        ← single Next.js 14 App Router app
    app/
      page.tsx                    # dashboard (main branch only)
      api/
        health/route.ts           # fan-out health aggregator (main + portal)
        claims/[...path]/route.ts # proxy → ClaimsApi
        tasks/[...path]/route.ts  # proxy → TaskApi
        route.ts                  # GET / capabilities JSON (proxy-only branch)
      auth/                       # portal branch only
        [...nextauth]/route.ts
      claims/                     # portal branch only
        page.tsx
        [id]/page.tsx
      tasks/                      # portal branch only
        page.tsx
        [id]/page.tsx
    components/
      ServiceCard.tsx             # health dot + latency + count badge
      RecentItems.tsx             # last-5 items list
      ClaimCard.tsx               # portal branch only
      TaskCard.tsx                # portal branch only
      CreateTaskForm.tsx          # portal branch only
    lib/
      backend.ts                  # base URLs, fetch + AbortController helper
      auth.ts                     # portal branch only: NextAuth config
      compose.ts                  # portal branch only: server-side data join
    package.json
    next.config.ts
    tsconfig.json
    .env.example
  vercel.json                     ← monorepo root config
```

---

## Branch Strategy

| Branch | Pattern | UI | Auth |
|---|---|---|---|
| `main` | BFF (Dashboard + Proxy) | Dashboard with health + counts + recent items | Pass-through `X-Api-Key` |
| `gateway/proxy-only` | API Gateway | None — JSON capabilities at `/` | Pass-through `X-Api-Key` |
| `gateway/portal` | Micro-frontend + API composition | Full CRUD portal for claims + tasks | NextAuth.js (GitHub OAuth) |

Each branch deploys independently on Vercel with **Root Directory = `gateway`**.

---

## Option 2 — Main Branch: Dashboard + Proxy (BFF)

### Data Flow

```
Browser (30 s poll)
  └─▶ GET /api/health
        ├─▶ ClaimsApi GET /claims  → derives { status, latency, totalClaims, recentClaims[] }
        │   (no dedicated /health — gateway times the call and counts results)
        └─▶ TaskApi   GET /tasks   → derives { status, latency, totalTasks,  recentTasks[]  }

Browser (pass-through)
  └─▶ ANY /api/claims/*  → route handler → ClaimsApi (X-Api-Key forwarded from caller)
  └─▶ ANY /api/tasks/*   → route handler → TaskApi
```

### Dashboard Page (`/`)

- **Initial render:** server component fetches `/api/health` at request time — no JS flash
- **Auto-refresh:** client component polls `/api/health` every 30 s via `useEffect` + `fetch`
- **`ServiceCard`** per service: coloured dot (green/yellow/red), latency ms, count badge
- **`RecentItems`** per service: last 5 claims and last 5 tasks as small cards
- **Degraded state:** if a backend times out, card turns red, shows last-known count with "stale" label — never a blank screen

### `/api/health` Route Handler

- `Promise.allSettled` across all backends — one timeout never blocks others
- Response shape: `{ services: { claims: {...}, tasks: {...} }, generatedAt: string }`
- `Cache-Control: s-maxage=10, stale-while-revalidate=20` — Vercel CDN serves stale while revalidating

### Proxy Route Handlers

- Strip all internal headers; forward only `authorization`, `x-api-key`, `content-type`
- Pipe upstream response body and status code unchanged
- `AbortController` with 10 s timeout; returns `504` on silence
- ClaimsApi auth: caller must supply `X-Api-Key` — gateway forwards it, never stores it

---

## Option 1 — Branch `gateway/proxy-only`: Pure API Proxy

### Changes from Main

Removes: `page.tsx`, `components/`, `api/health/route.ts`  
Adds: `app/api/route.ts` returning a JSON capabilities document

### Root Response (`GET /`)

```json
{
  "gateway": "SKFactory API Gateway",
  "version": "1.0.0",
  "routes": {
    "/api/claims/*": "ClaimsApi — pass X-Api-Key header",
    "/api/tasks/*":  "TaskApi — no auth required"
  }
}
```

### `vercel.json` Rewrites (proxy-only branch)

For clients that supply auth themselves, Vercel rewrites forward directly to upstream
without invoking a serverless function (zero cold-start). Destinations are the real
upstream URLs read from env:

```json
{
  "rewrites": [
    {
      "source": "/api/claims/:path*",
      "destination": "https://claims-api.<hash>.azurecontainerapps.io/:path*"
    },
    {
      "source": "/api/tasks/:path*",
      "destination": "https://task-api.up.railway.app/:path*"
    }
  ]
}
```

Header injection (`X-Api-Key` on behalf of the caller) still requires the route
handler path — rewrites cannot mutate request headers.

---

## Option 3 — Branch `gateway/portal`: Full Developer Portal

### Changes from Main

Adds: NextAuth.js (GitHub OAuth), data composition layer, full CRUD pages for claims and tasks, `ClaimCard`, `TaskCard`, `CreateTaskForm` components, shadcn/ui component library.

### Auth Model

- **Provider:** GitHub OAuth via NextAuth.js — zero user management
- **Session:** cookie-based, checked server-side via `getServerSession` on all portal pages
- **Proxy routes** (`/api/claims/*`, `/api/tasks/*`) remain unauthenticated — portal pages call them server-side; external callers still need `X-Api-Key` for claims

### Data Composition (`lib/compose.ts`)

- `getClaimWithTasks(claimId)` — fetches claim + tasks in parallel, joins on `claimId`
- Server-side only — composition logic never ships to the browser

### UI Library

shadcn/ui (Radix primitives + Tailwind) — scoped to `gateway/` only, no impact on other projects.

---

## Deployment Config

### `claude/vercel.json`

```json
{
  "version": 2,
  "projects": [
    {
      "name": "skfactory-gateway",
      "rootDirectory": "gateway"
    }
  ]
}
```

### Backend Deployment

**ClaimsApi → Azure Container Apps:**
```bash
az containerapp up \
  --name claims-api \
  --source ./Azure-Microservice \
  --ingress external \
  --target-port 8080
```

**TaskApi → Railway:**
- Connect GitHub repo → root: `ai-verified-ci-pipeline`
- Railway auto-detects .NET and runs `dotnet publish`

### Environment Variables

| Variable | main | proxy-only | portal |
|---|---|---|---|
| `CLAIMS_API_URL` | ✓ | ✓ | ✓ |
| `TASK_API_URL` | ✓ | ✓ | ✓ |
| `NEXTAUTH_SECRET` | — | — | ✓ |
| `GITHUB_CLIENT_ID` | — | — | ✓ |
| `GITHUB_CLIENT_SECRET` | — | — | ✓ |

### `gateway/.env.example`

```
CLAIMS_API_URL=https://claims-api.<hash>.azurecontainerapps.io
TASK_API_URL=https://task-api.up.railway.app
# portal branch only:
NEXTAUTH_SECRET=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
```

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| Backend timeout (> 10 s) | Proxy returns `504`; dashboard shows red card with stale count |
| Backend 4xx | Forwarded unchanged to caller |
| Backend 5xx | Forwarded unchanged; dashboard marks service degraded |
| Missing env var at startup | `backend.ts` throws at module load — Vercel build fails fast |
| Portal: unauthenticated access | `getServerSession` redirects to `/auth/signin` |

---

## Testing

- **Unit:** `lib/backend.ts` fetch helper — mock `fetch`, assert timeout fires, assert headers stripped
- **Integration:** route handlers with `msw` mocking upstream responses — assert correct status forwarding
- **E2E (main/portal):** Playwright — health card turns red when upstream mock returns 503; recent items render on load
- **No tests on `gateway/proxy-only`** beyond the unit layer — it is a thin forwarder


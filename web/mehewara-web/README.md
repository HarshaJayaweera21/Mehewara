# Mehewara web application

Updated 2026-09-26 from the React code. See the [root guide](../../README.md) and [implemented API reference](<../../Mehewara_API_Contract (1).md>).

## Implemented screens

Landing page; email/password login and registration; Google sign-in when configured; profile and profile-picture management; resident/coordinator reports; Problems and unlinked-report review; crew list/detail; recommendation edit/approve/reject/regenerate controls.

`src/App.tsx` selects screens with local `viewMode` state. React Router is not installed. User/token data are stored in browser localStorage. The website calls ASP.NET, not FastAPI. Server checks remain authoritative; showing a control does not prove its operation succeeds.

## Run locally

Install Node.js/npm compatible with the checked-in Vite/package versions. From this directory:

```powershell
npm ci
npm run dev
```

Use the address printed by Vite, normally `http://localhost:5173`. Start PostgreSQL and ASP.NET first; start AI for report processing.

The service files under `src/services` hard-code `http://localhost:5194/api`. There is no implemented environment variable for replacing that API base address. Google sign-in reads `VITE_GOOGLE_CLIENT_ID` from Vite's environment; the server has a separate Google client setting.

```powershell
npm run build
npm run lint
npm run preview
```

There is no test script or checked-in React test suite. These commands were not run during documentation alignment.

## Current limitations

- No WorkOrder monitoring/execution screen or connected Flutter handoff.
- Manual Problem link/create operations fail against current database constraints.
- Regenerate currently saves a request without rerunning AI.
- Rejection creates a cancelled WorkOrder on the server.
- Recommendation validation labels do not establish an Agent 4 check.
- Some AI recommendation IDs cannot be read by the backend.
- Photo files go through ASP.NET to Cloudinary, not a direct signed upload URL.
- Hosted use requires changing the local API base and backend allowed origins.

The implementation uses React/TypeScript/Vite and Leaflet. The earlier generic Vite template instructions did not describe the application and have been replaced.

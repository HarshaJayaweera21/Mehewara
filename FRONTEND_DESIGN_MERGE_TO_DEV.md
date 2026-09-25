# Mehewara Frontend Design Merge Handoff

## Purpose

This document describes the frontend work ready to be merged from `feature-report-intake` into `dev`.

The change introduces the refreshed Mehewara public experience while preserving the authenticated reports portal and coordinator problem-management features.

## Source and target branches

- Source: `feature-report-intake`
- Target: `dev`
- Latest source commit: `abf6b67`
- Frontend design commit: `d3e25a8`
- Conflict-resolution merge commit: `abf6b67`

## What is included

The frontend update includes:

- A modern Mehewara landing page using the existing forest green, mint, sage, and warm neutral palette.
- Responsive navigation, hero content, civic workflow sections, community issue examples, and calls to action.
- Separate Mehewara logos, civic icons, status badges, priority badges, decorative illustrations, patterns, and problem photographs.
- Shared design-system components for icons, status badges, priority badges, asset paths, and color tokens.
- Responsive behavior for desktop, tablet, and mobile layouts.
- Subtle section transitions and a horizontally scrolling community issue carousel.
- Automatic right-to-left carousel movement that pauses on hover, keyboard interaction, and touch interaction.
- Reduced-motion support for users who disable animation preferences.
- Updated authentication navigation so visitors can move between the landing page, login flow, resident reports, and coordinator views.
- Coordinator problem-management and uncertain-report screens integrated into the application routing.

## Conflict resolution

The merge conflicts were limited to the frontend routing and landing-page files:

- `web/mehewara-web/index.html`
- `web/mehewara-web/src/App.tsx`
- `web/mehewara-web/src/pages/landing/LandingPage.tsx`
- `web/mehewara-web/src/pages/landing/LandingPage.css`

The resolved result keeps the refreshed Mehewara landing design and incorporates the incoming coordinator and problem-management routes. The landing page supports both the current navigation callbacks and the earlier sign-in/sign-up callback shape for compatibility with the login flow.

## Validation completed

Run these commands from `web/mehewara-web` before merging:

```powershell
node node_modules/typescript/bin/tsc -b
node node_modules/eslint/bin/eslint.js src/App.tsx src/pages/landing/LandingPage.tsx
node node_modules/vite/bin/vite.js build
```

All three checks pass on the resolved branch.

## Recommended merge procedure

From the repository root:

```powershell
git fetch origin
git switch dev
git pull --ff-only origin dev
git merge --no-ff origin/feature-report-intake
```

If Git reports a conflict in one of the frontend files listed above, keep the resolved versions from `feature-report-intake`, then run:

```powershell
git add web/mehewara-web
git commit
```

Run the frontend validation commands again after the merge. Once they pass, publish the updated development branch:

```powershell
git push origin dev
```

## Review checklist

- Open the landing page at `/` and confirm the hero, workflow, city, issue carousel, story, and final call-to-action sections render correctly.
- Confirm the issue carousel moves automatically and pauses when the pointer is over the section.
- Confirm keyboard focus and touch interaction pause the carousel.
- Confirm the layout remains usable at mobile widths.
- Confirm a visitor can open the login flow from the landing page.
- Confirm a signed-in resident can reach the reports portal.
- Confirm an administrator can reach the coordinator problems dashboard and uncertain-report triage view.
- Confirm no backend or AI-service files are unintentionally changed by the frontend merge.

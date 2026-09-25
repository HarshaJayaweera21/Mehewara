# Mehewara web asset library

62 independent assets: 52 transparent SVG files and 10 WebP images. Open `index.html` for a searchable catalog and an example of the assets together. Every catalog image links to its own downloadable file. `manifest.json` maps the original asset numbers to filenames, dimensions, descriptions, and file sizes.

## React usage

Components and typed asset URLs are in `src/design-system/mehewara`. No new runtime dependencies or SVG loader plugins are required.

```tsx
import {
  Icon, PriorityBadge, StatusBadge, mehewaraAssets, problemImageAlt,
} from './design-system/mehewara';
import './design-system/mehewara/tokens.css';

export function Example() {
  return (
    <article>
      <img src={mehewaraAssets.mehewaraLogoCompact}
        alt="Mehewara" width={180} height={50} />
      <img className="mehewara-problem-image"
        src={mehewaraAssets.problemDrainage}
        alt={problemImageAlt.problemDrainage}
        width={1536} height={864} loading="lazy" decoding="async" />
      <PriorityBadge value="high" />
      <StatusBadge value="in-progress" />
      <button type="button" aria-label="Search problems">
        <Icon name="search" size={20} />
      </button>
      <Icon name="environment" size={24} color="currentColor"
        title="Environment" />
    </article>
  );
}
```

Use a path relative to your component when importing the library. Asset URLs honor Vite's configured `BASE_URL`, including deployments under a subdirectory. The existing application screens have not been changed; import the assets as needed.

## Brand assets

| File | Intrinsic size | Usage |
| --- | --- | --- |
| `mehewara-logo-primary.svg` | 600 × 176 | Forest logo with exact tagline on light surfaces |
| `mehewara-logo-white.svg` | 600 × 176 | Identical geometry in white for forest surfaces |
| `mehewara-logo-icon.svg` | 160 × 160 | Shared emblem for app icons, compact navigation, favicon |
| `mehewara-logo-compact.svg` | 520 × 144 | Shared emblem and wordmark without small tagline |

Typography is outlined in the logo SVGs; no font download is required. These are vector interpretations of the supplied raster reference, not traced source brand masters. All variants derive from the same geometry. Keep clear space of at least one eighth of the emblem height. Preserve the aspect ratio. Use the full lockup at 280 CSS pixels or wider so the tagline stays legible; use the compact logo below that. The icon mark supports favicon use, with best detail at 32 pixels and above.

## Color tokens

`tokens.css` defines the exact requested core colors:

| Token | Color |
| --- | --- |
| `--mehewara-forest` | `#123C32` |
| `--mehewara-primary-hover` | `#0D3028` |
| `--mehewara-mint` | `#4FD1A1` |
| `--mehewara-sage` | `#E5F6EE` |
| `--mehewara-canvas` | `#F7F7F2` |
| `--mehewara-white` | `#FFFFFF` |
| `--mehewara-text` | `#18211E` |
| `--mehewara-text-secondary` | `#68736E` |
| `--mehewara-border` | `#DDE2DE` |

Mint is an accent color. Use forest or primary text for readable labels on light surfaces. Semantic priority/status colors supplement the core palette.

## Images and decorative layers

- All eight problem images are 1536 × 864 (16:9), encoded as WebP at quality 86. Use `object-fit: cover` and preserve the aspect ratio. The streetlight intentionally uses dusk lighting; the other images use daylight in a consistent documentary treatment.
- Welcome background: 1920 × 640 (3:1), with open central space for text. Left leaves, cityscape, and right network ornament are separate transparent SVG layers for custom compositions. The raster background already contains scenery; additional layers are optional.
- Sidebar background: 600 × 1800 (1:3), intentionally extremely faint.
- Empty-state illustrations: 480 × 320 (3:2), transparent beyond their artwork. Pair with real HTML headings, explanations, and actions.
- Decorative assets should have `alt=""`, or be CSS backgrounds. Apply `aria-hidden="true"` to decorative inline SVGs and `pointer-events: none` to overlay layers.
- Photographs are AI-generated illustrative scenes, not evidence of actual reported incidents. Replace the thumbnail with the citizen's actual report photo when one exists.

## Icons

29 independent outline SVGs use a 24 × 24 viewBox, 1.75-unit stroke, round caps, and round joins. Supported React sizes: 16, 20, and 24 pixels. The five category symbols follow the same rules as the navigation symbols. No cards or colored tiles are embedded.

Every icon uses `stroke="currentColor"` with a forest presentation default. CSS `color` overrides the default on an **inline** SVG or React icon. An external SVG loaded by `<img>` cannot inherit the page's color; use the React component, inline the SVG, or apply it as a CSS mask for recoloring:

```css
.category-symbol {
  width: 24px;
  height: 24px;
  background: var(--mehewara-forest);
  mask: url('/assets/mehewara/icon-environment.svg') center / contain no-repeat;
}
```

Adjust that mask URL to your deployment base. Label icon-only buttons on the button, keeping the child icon decorative. The React `title` prop makes a standalone meaningful icon accessible with a unique title ID.

## Priority and status badges

Use `PriorityBadge` and `StatusBadge` for live UI; the eight separate SVGs are static visual references and reusable image assets. Labels remain real text in both forms. Badges use a 28-pixel minimum height, 12-pixel semibold type, 6-pixel dot, 7-pixel gap, and pill radius. They are labels, not interactive controls. Add a contextual label such as “Priority” in a details view when needed. Do not remove labels or rely on color alone.

| Kind | Value | Label | Text/dot | Background |
| --- | --- | --- | --- | --- |
| Priority | `critical` | Critical | `#9F4742` | `#FAECEA` |
| Priority | `high` | High | `#96552A` | `#FAEEE3` |
| Priority | `medium` | Medium | `#81661F` | `#F6F0DC` |
| Priority | `low` | Low | `#3F6C53` | `#EAF3EB` |
| Status | `identified` | Identified | `#53665C` | `#EDF2EE` |
| Status | `assigned` | Assigned | `#355D81` | `#EAF0F7` |
| Status | `in-progress` | In Progress | `#2F696D` | `#E7F2F1` |
| Status | `resolved` | Resolved | `#376A50` | `#E5F3E9` |

## Files and validation

- `manifest.json`: canonical inventory of all 62 requested assets.
- `verification.json`: decoding, dimensions, alpha transparency, and self-contained SVG checks.
- `contrast.json`: measured foreground/background ratios for all badge treatments.
- `generation-prompts.json`: prompts and generation provenance for the 10 raster assets.
- `index.html`: offline-capable catalog; assets remain separate files.
- `tokens.css`: tokens plus opt-in component classes; no page-wide style reset.

The source builders are in `scripts/build-mehewara-assets.mjs`, `scripts/catalog-mehewara-assets.mjs`, and `scripts/finish-mehewara-assets.mjs`. Outlined logo paths are checked in at `scripts/mehewara-type-paths.json`, so ordinary vector rebuilds do not require a font installation. Rebuilding vectors creates their 52 files plus the React files and resets manifest metadata; run the finalization step afterward to restore byte counts and verification. The image finalizer requires the source PNGs listed in `scripts/mehewara-raster-sources.json` and the Sharp image library. Raster generation used the built-in image generation tool, one image per asset, without a combined sheet.

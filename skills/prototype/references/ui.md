# UI Prototype

Build **several genuinely different, polished versions** of one piece of UI, on the real page, behind [the picker](./picker.md). The user flips through them live, picks one (or takes pieces from several), and the rest go to the prototype branch.

If the question is about logic or state rather than how something looks, this is the wrong branch. Use [logic.md](./logic.md).

The whole value here is **divergence**. Three tints of one idea waste the picker, because the user learns nothing by flipping between them. Each variant should be a direction you could defend shipping on its own.

## Where variants live

Variants are much easier to judge **up against the rest of the app**: real header, real sidebar, real data, real density. An empty route is a vacuum where every variant looks fine.

- **On an existing page (default).** Render the variants on the route they're for, gated by the picker's `?v=` param. Existing data fetching, params, and auth stay put; only the subtree being explored swaps. If the thing doesn't have a page yet but would naturally live inside one (a new dashboard card, a new step in a flow), mount the variants in that host page.
- **On a throwaway route (last resort).** Only when nothing could host it, such as an entirely new top-level surface. Follow the project's routing convention and put `prototype` in the path. Before choosing this, check again that no existing page could host it. If you do use it, build realistic surroundings: a toast needs a page behind it, a card needs siblings, a button needs a form.
- **No project.** Build a single self-contained HTML file (inline CSS and JS) using the standalone wiring from [picker.md](./picker.md).

## Process

### 1. Scope

Explore one thing per run. If the description spans several pieces ("the dashboard"), pick the highest-leverage one, say which and why, and offer the rest as follow-up runs. Restate the brief in one sentence: what it is, where it lives, what it must do.

### 2. Recon

Before designing, map what the variants must stand on:

- **Stack:** framework, styling system, component library, motion library if any.
- **Tokens:** colors, radii, spacing, fonts, easing and duration variables.
- **Personality:** playful or crisp? This bounds the boldest variant.
- **Context:** the host page, what's next to the piece, what background it sits on, what sizes it renders at, and what data is available.

### 3. Choose directions

Default to **3 variants**, up to 5 when the user asks or the design space is genuinely wide. Beyond 5 it stops being divergence and becomes noise.

Before writing any code, list the set with a **name and an axis** for each:

- Axes: layout, information hierarchy, primary affordance, density, interaction model, motion story, personality.
- Names describe the direction ("Quiet", "Editorial", "Dense", "Command bar"), never "Option A/B/C".
- **Convergence test:** if two directions would differ only in color, copy, or a token, they're one direction. Replace one with a real alternative. Three slightly tweaked card grids aren't a prototype, they're wallpaper.

Write the plan as a one-line comment at the top of the switch file, e.g.:

> `// PROTOTYPE: Is the settings page better as one long form, tabs, or a sidebar? 3 variants via ?v= on /settings.`

### 4. Build the variants

- One file per variant, exporting a component named after its direction (`QuietVariant`, `EditorialVariant`).
- Every variant meets [craft.md](./craft.md) in full: tokens, motion, states, realistic content.
- Every interaction works. Reads can use real data; mutations hit stubs (a fake delay, a plausible success) and never real endpoints.
- Share small leaf components if you like (an avatar, an icon button). Don't share a layout: each variant must be free to throw the layout out.

### 5. Wire the switch and the picker

```tsx
// PROTOTYPE: <the question>. Remove from main once decided; see prototype/<slug>.
const variants = [QuietVariant, EditorialVariant, DenseVariant];
const names = ['Quiet', 'Editorial', 'Dense'];

// existing data fetching stays above this line, untouched
if (!isDev) return <CurrentImplementation {...data} />;

const i = clamp((Number(searchParams.get('v')) || 1) - 1, 0, variants.length - 1);
const Variant = variants[i];
return (
  <>
    <Variant key={`${i}-${replayKey}`} {...data} />
    <PrototypePicker names={names} current={i} onReplay={...} />
  </>
);
```

Adapt to the framework. What matters:

- The production build renders exactly what it rendered before.
- Switching re-mounts the variant so entrance animations re-run.
- The variant swap itself is **instant**, with no transition between variants. Flipping happens over and over, so per the frequency rule it gets no animation.
- Use the picker built from [picker.md](./picker.md) exactly. If the project doesn't have a `PrototypePicker` yet, build it once in the shared UI location; otherwise reuse it.

### 6. Verify

Run the dev server. Flip through every variant with the keyboard and the mouse, exercise every interaction, check the console is clean, and check the page still renders normally with no `?v=`. Screenshot each variant if browser tooling is available.

### 7. Hand off, then stop

Present the set as a table, honestly:

| # | Variant | Axis | When it's the right choice | Its cost |
| --- | --- | --- | --- | --- |
| 1 | Quiet | Borders over shadows, minimal motion | The page is used daily | Least memorable |
| 2 | Editorial | Large type, generous whitespace | The moment deserves weight | Eats vertical space |

Close with the URL, the `?v=` keys, and the shortcuts (`1–N`, `←`/`→`, `R` to replay). Then stop: the user flips through when they get to it. If two variants converged while you built them, cut one and say so; two truly distinct directions beat a set padded to three.

The most useful feedback is often **"the header from 2 with the list from 3."** That's the real design, so treat it as a new direction, not a failure.

## Follow-ups

| The user says | Do |
| --- | --- |
| `<description>` | Full run: scope → recon → 3 directions → build → picker → verify → hand off |
| `<description> x5` | Same, with that many variants (cap 5) |
| `riff <variant>` | New round on the same picker: a fresh set that diverges *around* that direction. Previous variants go to the prototype branch before being replaced. |
| `mix <a> + <b>` / "header from 2, list from 3" | Add a combined variant to the picker next to its parents so they can be compared |
| `keep <variant>` | Capture and fold in, per [SKILL.md](../SKILL.md): record the verdict, commit everything to `prototype/<slug>`, rewrite the winner properly on the working branch, and remove the switch and the losing variants |

## Anti-patterns

- **Variants that differ only in color or copy.** That's a tweak. Real variants disagree about structure, hierarchy, or interaction.
- **A shared layout across variants.** It quietly forces convergence.
- **Polish on one variant only.** If the favorite is the only finished one, the comparison is rigged.
- **Real mutations.** The question is what it should look like, not whether the backend works.
- **Side-by-side thumbnails.** They distort spacing and scale. Show one variant at a time, full size, in context.
- **Restyling the picker.** It's chrome, not a contestant.
- **Copying the winner straight into main.** Rewrite it to project standards, carrying the lessons across.

# Logic Prototype

A single self-contained HTML file (a **shareable demo**) that lets anyone drive a state model by clicking buttons. Use it when the question is about **business logic, state transitions, or data shape**: things that look reasonable on paper and only feel wrong once you push real cases through them.

Because it's one file with nothing to install, you can hand it to a non-developer (a designer, a PM, a domain expert) and let them feel the model for themselves. So it speaks their language, not the code's.

If the question is "what should this look like?", this is the wrong branch. Use [ui.md](./ui.md).

## When this is the right shape

- "I'm not sure this state machine handles X followed by Y."
- "Can this data model actually represent the case where…?"
- "I want to feel out what the API should look like before writing it."
- Anyone wanting to **press buttons and watch state change**.

## Process

### 1. State the question

Before writing code, write down the state model and the question, as one paragraph shown at the top of the demo (visible on the page, not hidden in a comment). A logic prototype that answers the wrong question is pure waste, so make the question explicit enough to check later, whether the user is watching now or comes back to it later.

### 2. Isolate the logic in a portable module

Put the logic that answers the question in one `<script>` block, written as a small, pure module that could be lifted into the real codebase. The page around it is throwaway; this module isn't.

Pick the shape that fits the question, not the one that's easiest to wire to a page:

- **A pure reducer**, `(state, action) => state`, when actions are discrete events and state is one value.
- **A state machine** with explicit states and transitions, when "which actions are even legal right now?" is part of the question.
- **A few pure functions** over a plain data type, when there's no implicit current state.
- **A class or module with a clear method surface**, when the logic genuinely owns ongoing state.

Keep it pure: no DOM, no `document`, no handlers reaching inside it. The page calls into the module, never the reverse. That's what lets the validated logic outlive the demo.

### 3. Build the demo

One file of plain HTML, CSS, and JS: no framework, no bundler, no server, everything inline, so it opens by double-click and survives being emailed. Write every label in **domain language**: buttons and fields read like the business, not the reducer.

Lay it out top to bottom:

1. **Title and a one-line explanation** of what the demo explores (the question from step 1).
2. **Current state:** the full relevant state as a readable panel (labelled fields, not a JSON dump), re-rendered after every click.
3. **Free-play buttons:** one per action, always available, so anyone can poke the model in any order. Actions that are illegal in the current state stay visible but disabled, with a short plain-language reason on hover or focus. "Why can't I?" is often the answer the prototype exists to find.
4. **Guided walkthroughs:** one scenario per tab. Each tab has a short description of the setup and what to watch for, then the ordered steps as real buttons. Clicking a step performs the action and moves on. Starting a walkthrough resets to a known initial state so it runs the same way every time.
5. **History:** a compact log of the actions taken so far, in domain language, so people can retrace how they got into a strange state. Add a reset button.

Choose scenarios that cover the awkward cases: the happy path, a tricky edge case, and an attempt at something that should be illegal.

### 4. Polish it

The demo meets [craft.md](./craft.md). Here that means calm, clear, and precise. Nothing should compete with the state and the buttons.

- **Look:** if the project has tokens, inline the relevant ones as CSS custom properties so the demo feels like the product. Otherwise use the restrained default: neutral greys, one accent, system font stack, a 4px spacing scale. Support light and dark via `prefers-color-scheme`.
- **Show what changed:** after an action, briefly highlight the fields that changed (a background tint fading out over ~600ms; a fade is fine here because it carries information). The current walkthrough step is clearly marked, and completed steps look done.
- **Motion is feedback only:** `ease-out`, under 300ms for anything that moves, `transform`/`opacity` only, and no decorative animation. Under `prefers-reduced-motion`, keep only the change highlight, as an instant tint.
- **Interaction states:** every button has hover, `:active` (`scale(0.97)`), `:focus-visible`, and disabled states. The demo works fully from the keyboard.
- **Layout:** comfortable reading width, generous spacing, state panel and buttons visible together on a laptop screen without scrolling where possible. It should still be usable on a phone.

### 5. Verify

Open the file. Run every walkthrough start to finish, try the illegal actions, use free play out of order, and check the console is clean. Screenshot it if browser tooling is available.

### 6. Hand off, then stop

Give them the file path (or open it). They'll click through when they get to it. The interesting moments are "wait, that shouldn't be possible" and "huh, I assumed X would be different": those are bugs in the *idea*, which is the point. If they want new actions or scenarios, add them; prototypes evolve.

### 7. Capture

Follow [SKILL.md](../SKILL.md). Specific to logic: the validated pure module moves into the real module (with tests written around the walkthrough scenarios), and the HTML file goes to the `prototype/<slug>` branch. Being one self-contained file, it stays trivially re-runnable there.

## Anti-patterns

- **Tests in the prototype.** A prototype that needs tests isn't a prototype anymore. The tests come during the rewrite.
- **A real database.** Use in-memory state unless the question is specifically about persistence.
- **Generalizing.** No "what if we want X later". It answers one question.
- **Logic mixed into the page.** If the module touches the DOM, it can't be lifted out.
- **A framework, bundler, or server.** It must be one file the recipient double-clicks.
- **Decorative polish.** Gradients, bouncy motion, and illustration compete with the state. Polish here means clarity.
- **Shipping the HTML shell.** The logic module is the part worth keeping.

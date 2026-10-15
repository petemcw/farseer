# The Craft Bar

Every variant and every demo meets this bar. Divergence is never an excuse to drop it: a sloppy variant doesn't widen the exploration, it just loses on execution and teaches nothing about the direction it represents.

## Fit the product

- **Use the project's tokens:** colors, radii, spacing scale, fonts, shadows, easing and duration variables. Every variant should look like it could ship in this product tomorrow. Sharing tokens isn't convergence.
- **Respect its personality.** A playful consumer app and a crisp dashboard allow very different amounts of motion and flourish. The personality sets how far the boldest variant may go.
- **No project?** Use a restrained default: neutral greys, one accent color, the system font stack, a 4px spacing scale.

## Layout and type

- Build hierarchy from size, weight, and spacing first; color alone shouldn't carry it.
- Stay on the spacing scale. Uneven gaps read as bugs.
- Use realistic content lengths: long names, empty lists, five-digit numbers. Use `font-variant-numeric: tabular-nums` for numbers that change or line up in columns.
- Every interactive element has hover, `:active`, and `:focus-visible` states. Hit targets are at least 32px (44px on touch).

## Motion

- **Easing:** `ease-out` for things entering or responding to the user, `ease-in-out` for things moving on screen, never `ease-in` for UI (it feels sluggish at the moment the user is waiting). Prefer a strong custom curve such as `cubic-bezier(0.23, 1, 0.32, 1)` over the built-in keywords.
- **Duration:** UI motion stays under 300ms. Most state changes sit at 150–250ms.
- **Frequency rule:** the more often something happens, the less it animates. Actions done hundreds of times a session, or triggered from the keyboard, get little or no animation.
- **Animate `transform` and `opacity` only.** Never animate layout properties (`width`, `height`, `top`, `margin`) on anything with layout dependents.
- **Origin matches the cause.** A popover scales from its trigger, not from its centre (`transform-origin` set to the anchor side). A modal can scale from centre.
- **Never animate from nothing.** Enter from `scale(0.95)` plus `opacity: 0`, not `scale(0)`.
- **Press feedback:** buttons get a subtle `:active { transform: scale(0.97) }`.
- **Interruptible:** use CSS transitions or a spring for things that can be re-triggered mid-flight; don't make the user wait for an animation to finish.
- **Reduced motion:** under `prefers-reduced-motion: reduce`, drop movement and keep at most short opacity fades.

## Content

- No lorem ipsum, no "Item 1", no `John Doe`. Write product-shaped copy, plausible names, and believable numbers.
- No dead buttons and no "imagine this part". If something can't work for real, wire it to a stub that behaves plausibly (a fake delay, a fake success).

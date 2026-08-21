# Confluence Docs

## What this source contains

- Architectural decision records (ADRs)
- Meeting notes from design reviews
- Postmortems from incidents
- PRDs (product requirement documents)
- Runbooks that may explain defensive code
- Scopes of work
- Statements of Work (SOWs)
- Strategy documents that set priorities
- Team pages with domain context
- Technical specs and RFCs

Confluence is where "why" often lives in long-form before it becomes code. A significant feature usually has a doc.

## How to search it

Use the Atlassian Rovo MCP.

1. **Discover** - Natural-language search over the deferred tool catalogue. Returns a list of potentially related tools, their toolSchema and operations for running on execute.
2. **Keyword searches with `searchConfluence`.** Try:
   - The feature name
   - Key symbols / class names from the target code
   - Author handles (design docs are often authored before the code lands)
   - Error strings or user-visible terms
   - Time-bounded queries if you know when the code shipped
3. **Fetch candidate pages with `getConfluenceContent`.** Read any Confluence content such as page, blog, live doc, comment, whiteboard, embed, database, or folder. Rationale is often buried mid-document.
4. **Follow backlinks and child pages.** Design docs often have sub-pages for alternatives considered, appendices, or implementation notes.
5. **Search author-specific spaces.** If the commit author has a personal space (common at some companies), it may hold exploratory thinking that preceded the code.

## What good evidence looks like here

- A PRD with a "Problem statement" or "Motivation" section that matches the target code's purpose
- An "Alternatives considered" or "Rejected approaches" section
- A postmortem that names the target code as the fix for a specific incident
- Meeting notes that record "we decided X because Y" and tie to the same author/date range as the PR
- An ADR template filled out non-trivially (status, context, decision, consequences)

## Common pitfalls

- **Outdated docs.** Specs are often written before implementation and not updated. The doc may describe a plan that changed. Cross-check against the actual PR.
- **Doc vs. reality drift.** A spec may say "we'll do X" but the code actually does Y. Flag the divergence. The synthesizer will surface the contradiction.
- **Boilerplate templates.** Some orgs require a "Why" section that gets filled with fluff. Look for specificity.
- **Unlinked docs.** The most relevant doc may not be linked from anywhere. Broad keyword searches help.
- **Multiple drafts.** If a topic has multiple docs, find the one that was finalized or most recently updated. Check dates.
- **Access-restricted pages.** If you can't access a page, note it as a gap.

## What to return

For each relevant doc:

- Title and URL
- Authors and last-updated date
- The motivation text (verbatim quote), with page/section location
- Relevant linked pages (so the synthesizer can cite them)
- Whether the doc was finalized or draft

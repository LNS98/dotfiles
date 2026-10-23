---
name: explain
description: Explain a concept, code path or result in the form that makes it land - plain prose, a diagram, or an interactive page.
disable-model-invocation: true
argument-hint: "what to explain, optionally with a format: prose, diagram or page"
---

The user wants to understand something, and the default wall of text has not worked or will not work. Your job is to pick the form that carries this content best, then build it. The form is the decision that matters most.

## 1. Ground the target

The target is the argument, or the topic in play in the conversation if there is no argument. Read the real material: the code, the logs, the article, the result. If the repo has a `GLOSSARY.md` (or a `GLOSSARY-MAP.md` that points to one), use its terms.

Done when you can state the mechanism to yourself in one sentence, and every claim you plan to make traces to something you read in this step.

## 2. Pick the form

A format the user names wins. Otherwise pick by the shape of the content:

| Shape of the content | Form |
| --- | --- |
| One idea that fits in about five sentences | **Prose** |
| Parts and how they connect, a sequence, a flow, a state that changes over time | **Diagram** |
| Behaviour that depends on inputs the reader will want to vary, or many facets to move between | **Page** |

When two rows fit, take the lower one. Say the form you picked and why in one line before you build it.

## 3. Build it

**Prose.** Write about 80% of the way to ASD-STE100 Simplified Technical English:

- One idea per sentence. Keep most sentences under 20 words.
- Active voice, present tense.
- One word for one meaning. Once you call it the "queue", it stays the "queue".
- The codebase is the word list: write the real symbol, file or command name.
- Concrete before abstract: show one real example, then the general rule.

**Diagram.** Draw the real mechanism, not a box per noun. Label boxes with real names from the code. Label each arrow with what moves along it: a request, a row, an event. In Claude Code, publish it as a private artifact with inline SVG, and load `artifact-diagramming` first when the session lists it. Elsewhere, write a self-contained HTML file with inline SVG to `$TMPDIR/explain-<slug>.html` and give the full path.

**Page.** One self-contained HTML file. Its controls change real values computed with the same logic as the thing being explained, so the reader learns by moving them. Start the page in the state that shows the key behaviour. Publish and save it the same way as a diagram.

Send a diagram or a page with two to four prose sentences in chat that say where to look first.

## 4. Check it

Done when:

- every term is defined on first use or comes from the glossary,
- every claim traces to material from step 1,
- the user can see the mechanism from the output alone, without this conversation.

End with one line that offers the next-richer form (prose → diagram → page).

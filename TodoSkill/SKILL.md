---
name: todo
description: Extract actionable project todos from natural-language input and add them to the local Todo Bar database. Use only when explicitly invoked with /skill:todo.
disable-model-invocation: true
---

# Add Todos to Todo Bar

Run this workflow only because the user explicitly invoked `/skill:todo`. Never create todos proactively.

## 1. Resolve the project

Use the current canonical Hindsight project name exactly as stored by the local scope resolver:

1. Starting at the current working directory, look for the nearest `.pi-memory-scope.json` in the current directory or an ancestor.
2. Read its non-empty `scopeName` as the default project.
3. Do not derive, normalize, rename, or alias the project from the directory name.
4. If there is no usable scope file, or the user clearly refers to a different project but does not identify it, ask one concise project question before writing.
5. An explicit project supplied by the user overrides the default and may be any non-empty string.

Hindsight is only a project-name adapter here. Never store todo content in Hindsight or require the Todo Bar app to access Hindsight.

## 2. Extract result-oriented todos

The user's input may mix questions, background, observations, hypotheses, requests, and rejected alternatives. Convert it into the smallest useful set of executable outcomes.

Include:

- Work that remains to be done.
- Distinct deliverables or verifiable outcomes.
- Necessary follow-up work that the user clearly requests.
- The background, reason, constraints, and completion conditions needed to understand each outcome later.

Exclude:

- Unrelated background and conversational filler.
- Work described as already complete.
- Questions that do not request follow-up work.
- Speculation or unconfirmed hypotheses.
- Rejected alternatives and out-of-scope features.
- Duplicate or overlapping items; merge them into one outcome.

For each todo, produce two fields:

- `title`: a concise, standalone result.
- `details`: a compact AI-written summary of the relevant background, why the work matters, constraints, and completion condition. Include only sections supported by the user's input. Do not copy the conversation transcript or invent missing requirements.

Preserve the user's language unless a code identifier needs its original spelling.

If the intended todo or target project is genuinely ambiguous, ask only the minimum clarification needed. Otherwise, do not preview or request confirmation. If no actionable work remains, say so and do not write anything.

## 3. Add the todos

Find the helper in this order:

1. `todoctl` on `PATH`.
2. `$HOME/.local/bin/todoctl`.

If neither executable exists, stop and explain that Todo Bar must be installed from the `pi-todo` repository with `make install`. Do not write the SQLite database directly.

For each extracted outcome, invoke the helper with shell-safe arguments:

```bash
todoctl add \
  --project "<exact project>" \
  --title "<concise outcome>" \
  --details "<AI-written context summary>"
```

Treat project names, titles, and details as data, never as shell code. Details may contain newlines and must remain one shell argument. A failed add must be reported; do not claim it succeeded or silently retry by editing SQLite.

## 4. Report

Reply with the exact project and the titles that were added. Keep the report concise; do not repeat the stored details or dump the full todo list unless the user asks for them.

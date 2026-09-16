# Todo Bar

A small, local-only macOS menu bar app for project todos. The app is independent of Pi and Hindsight; any local tool can write through `todoctl`.

## MVP

- Groups incomplete todos by project.
- Shows an incomplete count in a larger popover.
- Shows a two-line context preview and expands full details when the content is clicked.
- Completes a todo only when its separate circle is clicked; completed rows disappear.
- Persists completion timestamps in SQLite for accidental-recovery support.
- Refreshes after `todoctl` changes through a distributed notification, with a two-second safety refresh while the popover is open.
- Runs as a menu-bar-only app without a Dock icon.
- Registers itself with macOS `SMAppService` to start automatically at login.

## Requirements

- macOS 13 or newer
- Xcode command-line tools with Swift 6 or newer

## Build and test

```bash
make check
make app
open ".build/Todo Bar.app"
```

The primary acceptance test uses a temporary SQLite database and checks schema migration, contextual details, add, process restart/persistence, list, complete, default-list removal, and retained `completed_at`.

## Install locally

```bash
make install
open "$HOME/Applications/Todo Bar.app"
```

This installs:

- `$HOME/Applications/Todo Bar.app`
- `$HOME/.local/bin/todoctl`
- `$HOME/.pi/agent/skills/todo/SKILL.md`

The global skill has `disable-model-invocation: true`, so it only runs after an explicit `/skill:todo`. It resolves the nearest canonical scope name, extracts concise result-oriented titles plus an AI-written context summary, and writes only through `todoctl`.

Launch the installed app once to register it as a login item. If macOS requires approval, enable Todo Bar in **System Settings → General → Login Items**.

## Helper usage

```bash
todoctl add \
  --project "pi-todo" \
  --title "Finish the menu bar MVP" \
  --details $'Background: The compact list loses useful context.\nDone when: The larger expandable UI is verified.'
todoctl list
todoctl list --json
todoctl complete <id>
```

The shared database is stored at:

```text
~/Library/Application Support/Todo Bar/todos.sqlite
```

SQLite WAL mode and a busy timeout allow the app and helper to use the database concurrently without whole-file overwrites. Existing databases are migrated in place by adding a non-null `details` column with an empty default, preserving existing todos.

## Design boundaries

Todo Bar has no accounts, network access, cloud sync, reminders, dates, priorities, tags, kanban board, or PR integration. Hindsight may help an AI adapter choose a canonical project name, but it is not a todo store or runtime dependency.

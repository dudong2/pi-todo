.PHONY: build test check app install install-skill clean

build:
	swift build

test:
	swift test

check: test
	./Tests/cli-integration.sh

app:
	./scripts/build-app.sh

install: app install-skill
	swift build -c release --product todoctl
	mkdir -p "$(HOME)/Applications" "$(HOME)/.local/bin"
	rm -rf "$(HOME)/Applications/Todo Bar.app"
	cp -R ".build/Todo Bar.app" "$(HOME)/Applications/Todo Bar.app"
	cp "$$(swift build -c release --show-bin-path)/todoctl" "$(HOME)/.local/bin/todoctl"
	@printf 'Installed Todo Bar.app and %s/.local/bin/todoctl\n' "$(HOME)"

install-skill:
	mkdir -p "$(HOME)/.pi/agent/skills/todo"
	cp "TodoSkill/SKILL.md" "$(HOME)/.pi/agent/skills/todo/SKILL.md"
	@printf 'Installed global /skill:todo\n'

clean:
	swift package clean
	rm -rf ".build/Todo Bar.app"

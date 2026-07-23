.PHONY: install uninstall test lint

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
SCRIPTSDIR ?= $(HOME)/.hermes/scripts

install:
	@mkdir -p "$(BINDIR)"
	@ln -sf "$(CURDIR)/bin/hermes-secure-update" "$(BINDIR)/hermes-secure-update"
	@echo "✓ Installed: $(BINDIR)/hermes-secure-update → $(CURDIR)/bin/hermes-secure-update"
	@echo "  Ensure $(BINDIR) is in your PATH."

uninstall:
	@rm -f "$(BINDIR)/hermes-secure-update"
	@echo "✓ Removed: $(BINDIR)/hermes-secure-update"

test:
	@bash tests/test_verify_remote.sh
	@bash tests/test_risk_score.sh
	@bash tests/test_notify.sh
	@echo ""
	@echo "✓ All tests passed."

lint:
	@shellcheck bin/hermes-secure-update lib/*.sh || true

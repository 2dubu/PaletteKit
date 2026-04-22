# PaletteKit — developer convenience targets.
#
# Only two entry points:
#   make setup      — one-time environment setup (installs xcodegen via Homebrew)
#   make demo-app   — generate Examples/PaletteKitDemo and open it in Xcode
DEMO_DIR := Examples/PaletteKitDemo
PROJECT  := $(DEMO_DIR)/PaletteKitDemo.xcodeproj

.PHONY: setup demo-app

setup:
	@command -v brew >/dev/null 2>&1 || { \
		echo "Homebrew not found. Install from https://brew.sh/ then re-run make setup."; \
		exit 1; \
	}
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "→ Installing xcodegen via Homebrew…"; \
		brew install xcodegen; \
	}
	@echo "✓ Environment ready (xcodegen installed)."

demo-app: setup
	@echo "→ Generating $(PROJECT) from project.yml…"
	@cd $(DEMO_DIR) && xcodegen
	@open $(PROJECT)
	@echo "✓ Opened in Xcode. Pick a simulator and press ⌘R to run."

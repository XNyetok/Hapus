# Hapus: shortcuts for everyday tasks. Run `make` to list them.

PROJECT    := Hapus.xcodeproj
SCHEME     := Hapus
DERIVED    := build/DerivedData
APP        := $(DERIVED)/Build/Products/Debug/Hapus.app
CORE       := Packages/HapusCore
SWIFT_SRC  := Hapus $(CORE)/Sources $(CORE)/Tests $(CORE)/Package.swift

.DEFAULT_GOAL := help
.PHONY: help setup open build run test lint format scan release clean

help: ## List available commands
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  make %-8s %s\n", $$1, $$2}'

setup: ## Install git hooks and check tools (run once after cloning)
	@./scripts/bootstrap.sh

open: ## Open the project in Xcode
	open $(PROJECT)

build: ## Build the app (Debug) into ./build
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination 'platform=macOS' -derivedDataPath $(DERIVED) -quiet

run: build ## Build and launch the app
	open $(APP)

test: ## Run the HapusCore unit tests
	swift test --package-path $(CORE)

lint: ## Check code formatting
	xcrun swift-format lint --recursive $(SWIFT_SRC)

format: ## Format the code
	xcrun swift-format format --in-place --recursive $(SWIFT_SRC)

scan: ## Scan Git history and the working tree for secrets (needs gitleaks)
	gitleaks git --redact --no-banner .
	gitleaks dir --redact --no-banner .

release: ## Build a local release zip: make release VERSION=0.1.0
	@test -n "$(VERSION)" || (echo "Usage: make release VERSION=0.1.0" && exit 1)
	./scripts/build-release.sh $(VERSION)

clean: ## Remove the build folder
	rm -rf build

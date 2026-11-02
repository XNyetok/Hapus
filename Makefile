# Hapus: shortcut buat tugas sehari-hari. Ketik `make` buat lihat daftarnya.

PROJECT    := Hapus.xcodeproj
SCHEME     := Hapus
DERIVED    := build/DerivedData
APP        := $(DERIVED)/Build/Products/Debug/Hapus.app
CORE       := Packages/HapusCore
SWIFT_SRC  := Hapus $(CORE)/Sources $(CORE)/Tests $(CORE)/Package.swift

.DEFAULT_GOAL := help
.PHONY: help setup open build run test lint format scan release clean

help: ## Tampilkan daftar perintah
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  make %-8s %s\n", $$1, $$2}'

setup: ## Pasang git hooks & cek tools (jalanin sekali setelah clone)
	@./scripts/bootstrap.sh

open: ## Buka proyek di Xcode
	open $(PROJECT)

build: ## Build app (Debug) ke ./build
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination 'platform=macOS' -derivedDataPath $(DERIVED) -quiet

run: build ## Build lalu jalanin app
	open $(APP)

test: ## Jalanin unit test HapusCore
	swift test --package-path $(CORE)

lint: ## Cek format kode
	xcrun swift-format lint --recursive $(SWIFT_SRC)

format: ## Rapiin format kode
	xcrun swift-format format --in-place --recursive $(SWIFT_SRC)

scan: ## Scan secret di riwayat Git & file kerja (butuh gitleaks)
	gitleaks git --redact --no-banner .
	gitleaks dir --redact --no-banner .

release: ## Build zip rilis lokal: make release VERSION=0.1.0
	@test -n "$(VERSION)" || (echo "Pakai: make release VERSION=0.1.0" && exit 1)
	./scripts/build-release.sh $(VERSION)

clean: ## Hapus folder build
	rm -rf build

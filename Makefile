# GlyphCrafter Build System
# Builds .xcarchive and exports to .ipa

SHELL := /bin/bash
PROJECT := GlyphCrafter.xcodeproj
SCHEME := GlyphCrafter
CONFIGURATION ?= Release
BUILD_DIR := build
ARCHIVE_PATH := $(BUILD_DIR)/$(SCHEME).xcarchive
IPA_DIR := $(BUILD_DIR)/ipa
EXPORT_OPTIONS := ExportOptions.plist
DESTINATION ?= generic/platform=iOS

.PHONY: all clean build archive ipa test lint resolve-deps

all: ipa

# ── Dependencies ─────────────────────────────

resolve-deps:
	@echo "▸ Resolving Swift Package Manager dependencies..."
	xcodebuild -resolvePackageDependencies \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-clonedSourcePackagesDirPath $(BUILD_DIR)/SourcePackages

# ── Build ────────────────────────────────────

build: resolve-deps
	@echo "▸ Building $(SCHEME) ($(CONFIGURATION))..."
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination '$(DESTINATION)' \
		-clonedSourcePackagesDirPath $(BUILD_DIR)/SourcePackages \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		ONLY_ACTIVE_ARCH=NO

# ── Archive ──────────────────────────────────

archive: resolve-deps
	@echo "▸ Archiving $(SCHEME)..."
	@mkdir -p $(BUILD_DIR)
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination '$(DESTINATION)' \
		-archivePath $(ARCHIVE_PATH) \
		-clonedSourcePackagesDirPath $(BUILD_DIR)/SourcePackages \
		SKIP_INSTALL=NO \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# ── IPA Export ───────────────────────────────

ipa: archive
	@echo "▸ Exporting IPA..."
	@mkdir -p $(IPA_DIR)
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(IPA_DIR) \
		-exportOptionsPlist $(EXPORT_OPTIONS) \
		-allowProvisioningUpdates
	@echo "▸ IPA exported to $(IPA_DIR)/"
	@ls -lh $(IPA_DIR)/*.ipa 2>/dev/null || echo "(IPA will be at $(IPA_DIR)/$(SCHEME).ipa)"

# ── Unsigned IPA (CI / no code signing) ──────

ipa-unsigned: resolve-deps
	@echo "▸ Building unsigned .app for IPA packaging..."
	@mkdir -p $(BUILD_DIR)/unsigned
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(BUILD_DIR)/DerivedData \
		-clonedSourcePackagesDirPath $(BUILD_DIR)/SourcePackages \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		ONLY_ACTIVE_ARCH=NO
	@echo "▸ Packaging into unsigned IPA..."
	@mkdir -p $(BUILD_DIR)/unsigned/Payload
	@APP_PATH=$$(find $(BUILD_DIR)/DerivedData -name "$(SCHEME).app" -type d | head -1) && \
		if [ -n "$$APP_PATH" ]; then \
			cp -R "$$APP_PATH" $(BUILD_DIR)/unsigned/Payload/ && \
			cd $(BUILD_DIR)/unsigned && \
			zip -r ../$(SCHEME)-unsigned.ipa Payload/ && \
			echo "▸ Unsigned IPA: $(BUILD_DIR)/$(SCHEME)-unsigned.ipa" && \
			ls -lh ../$(SCHEME)-unsigned.ipa; \
		else \
			echo "ERROR: Could not find $(SCHEME).app in DerivedData"; \
			exit 1; \
		fi

# ── Test ─────────────────────────────────────

test: resolve-deps
	@echo "▸ Running tests..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
		-clonedSourcePackagesDirPath $(BUILD_DIR)/SourcePackages \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

# ── Lint ─────────────────────────────────────

lint:
	@echo "▸ Running SwiftLint..."
	swiftlint lint --strict

# ── Clean ────────────────────────────────────

clean:
	@echo "▸ Cleaning..."
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) 2>/dev/null || true
	rm -rf $(BUILD_DIR)
	rm -rf ~/Library/Developer/Xcode/DerivedData/$(SCHEME)-*

# ── Help ─────────────────────────────────────

help:
	@echo "GlyphCrafter Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make build        - Build the project (no signing)"
	@echo "  make archive      - Create .xcarchive (signed)"
	@echo "  make ipa          - Archive + export signed .ipa"
	@echo "  make ipa-unsigned - Build + package unsigned .ipa (for CI)"
	@echo "  make test         - Run unit tests on simulator"
	@echo "  make lint         - Run SwiftLint"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make resolve-deps - Resolve SPM dependencies"
	@echo ""
	@echo "Variables:"
	@echo "  CONFIGURATION=Debug|Release (default: Release)"
	@echo "  DESTINATION=... (default: generic/platform=iOS)"

.PHONY: setup get format fix lint analyze check test clean build-apk build-apk-split build-ios build-web icons outdated deps run doctor help

setup: get ## First-time project setup (dependencies + git hooks)
	@git config core.hooksPath .githooks
	@echo "Git hooks configured."

get: ## Install dependencies
	flutter pub get

format: ## Auto-format all Dart files
	dart format .

lint: ## Run static analysis
	flutter analyze --no-pub

fix: ## Auto-fix lint issues and format
	dart fix --apply
	dart format .

check: ## Run format check + analysis (same as CI)
	dart format --set-exit-if-changed .
	flutter analyze --no-pub

test: ## Run unit tests with coverage
	@flutter test --coverage --reporter=expanded 2>&1 | tee /tmp/_engitrack_test.log; \
	EXIT_CODE=$${PIPESTATUS[0]}; \
	sh scripts/test_summary.sh /tmp/_engitrack_test.log; \
	rm -f /tmp/_engitrack_test.log; \
	exit $$EXIT_CODE

build-apk: ## Build universal release APK
	flutter build apk --release --dart-define=FLUTTER_BUILD_MODE=release

build-apk-split: ## Build per-ABI release APKs
	flutter build apk --release --split-per-abi --dart-define=FLUTTER_BUILD_MODE=release

build-ios: ## Build iOS (no codesign)
	flutter build ios --release --no-codesign

build-web: ## Build web release
	flutter build web --release --web-renderer canvaskit --dart-define=FLUTTER_BUILD_MODE=release

icons: ## Regenerate launcher icons from pubspec config
	dart run flutter_launcher_icons

outdated: ## Check for outdated dependencies
	flutter pub outdated

deps: ## Print dependency tree
	dart pub deps

clean: ## Delete build artifacts and caches
	flutter clean
	@rm -rf .dart_tool/

run: ## Launch the app in debug mode
	flutter run

doctor: ## Check Flutter environment health
	flutter doctor -v

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help

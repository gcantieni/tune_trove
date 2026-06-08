.PHONY: format analyze test coverage lcov bump publish-ios publish-macos publish-android deps run-macos run-ios build-macos build-ios build-android icon reregister-macos

clean:
	rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
	rm -rf build/macos
	rm -rf build/ios

# Force macOS to use the freshly built Share Extension. macOS caches share
# extensions via Launch Services / PlugInKit, so after rebuilding, a stale copy
# (e.g. an old Release build) can shadow the new one in the share menu. This
# re-registers the app, (re)adds its appex, and bounces the share daemons.
# Defaults to the Debug build; pass RELEASE=1 for the Release build.
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
MACOS_APP  := build/macos/Build/Products/$(if $(RELEASE),Release,Debug)/tune_trove.app

reregister-macos:
	@echo "→ Re-registering macOS Share Extension ($(MACOS_APP))"
	$(LSREGISTER) -f "$(MACOS_APP)"
	pluginkit -a "$(MACOS_APP)/Contents/PlugIns/ShareExtension.appex"
	@# Drop any *other* registration of the same extension that would shadow the
	@# dev build in the share menu — e.g. the shipped iOS-on-Mac App Store build
	@# at /Applications/Tune Trove.app/Wrapper/Runner.app, or a stale Release.
	@target="$$(cd "$(MACOS_APP)/Contents/PlugIns/ShareExtension.appex" 2>/dev/null && pwd)"; \
	pluginkit -mAv 2>/dev/null | awk -F'\t' '/com\.gcantieni\.tuneTrove\.ShareExtension/{print $$NF}' | while read -r p; do \
	  if [ -n "$$target" ] && [ "$$p" != "$$target" ]; then \
	    echo "  unregister shadow: $$p"; pluginkit -r "$$p" 2>/dev/null || true; \
	  fi; \
	done
	-killall sharingd pkd
	@echo "✓ Re-registered. Relaunch the app (open \"$(MACOS_APP)\"), and quit/reopen the source app (e.g. Voice Memos) so it refreshes its share menu."

# Short commit the build was made from, surfaced in the Settings footer for bug
# reports. Passed through to Dart via --dart-define and read by
# String.fromEnvironment('GIT_COMMIT'). Falls back to "nogit" outside a checkout.
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo nogit)
DART_DEFINES := --dart-define=GIT_COMMIT=$(GIT_COMMIT)

format:
	dart format lib/

analyze:
	flutter analyze

run-macos:
	flutter run -d macos --no-pub $(DART_DEFINES)

run-ios:
	flutter run -d $(if $(DEVICE),$(DEVICE),iPhone) --no-pub $(DART_DEFINES)

build-macos:
	flutter build macos $(DART_DEFINES)

build-ios:
	flutter build ios $(DART_DEFINES)

build-android:
	flutter build appbundle $(DART_DEFINES)

deps:
	flutter pub get
	bash scripts/fetch_soundfonts.sh

test:
	flutter test lib --no-pub

lcov:
	flutter test lib --coverage --no-pub

coverage:
	flutter test lib --coverage --no-pub
	genhtml coverage/lcov.info -o coverage/html
	open coverage/html/index.html

bump:
	@bash scripts/bump_version.sh $(if $(MAJOR),major,$(if $(MINOR),minor,patch))
	@echo "Don't forget to promote any DB schema updates to the icloud sync data on icloud.developer.apple.com"

publish-ios:
	@bash scripts/publish.sh ios

publish-macos:
	@bash scripts/publish.sh macos

publish-android:
	@bash scripts/publish.sh android

ICON_SRC   := icon/tuneTrove Exports
ANDROID_RES := android/app/src/main/res

icon:
	@echo "→ Android icons (generated via sips)"
	sips -z 48  48  "$(ICON_DEFAULT)" --out "$(ANDROID_RES)/mipmap-mdpi/ic_launcher.png"    -s format png
	sips -z 72  72  "$(ICON_DEFAULT)" --out "$(ANDROID_RES)/mipmap-hdpi/ic_launcher.png"    -s format png
	sips -z 96  96  "$(ICON_DEFAULT)" --out "$(ANDROID_RES)/mipmap-xhdpi/ic_launcher.png"   -s format png
	sips -z 144 144 "$(ICON_DEFAULT)" --out "$(ANDROID_RES)/mipmap-xxhdpi/ic_launcher.png"  -s format png
	sips -z 192 192 "$(ICON_DEFAULT)" --out "$(ANDROID_RES)/mipmap-xxxhdpi/ic_launcher.png" -s format png
	@echo "✓ Done"

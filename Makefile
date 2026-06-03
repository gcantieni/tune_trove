.PHONY: format analyze test coverage lcov bump publish-ios publish-macos publish-android deps run-macos run-ios build-macos build-ios build-android icon

clean:
	rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
	rm -rf build/macos
	rm -rf build/ios

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
	flutter test --no-pub

lcov:
	flutter test --coverage --no-pub

coverage:
	flutter test --coverage --no-pub
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

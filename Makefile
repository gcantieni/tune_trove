.PHONY: format analyze test coverage lcov bump publish-ios publish-macos publish-android deps run-macos run-ios icon

format:
	dart format lib/

analyze:
	flutter analyze

run-macos:
	flutter run -d macos --no-pub --dart-define=MOCK_MUSICKIT=true

run-ios:
	flutter run -d iPhone --no-pub

deps:
	flutter pub get

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

publish-ios:
	@bash scripts/publish.sh ios

publish-macos:
	@bash scripts/publish.sh macos

publish-android:
	@bash scripts/publish.sh android

ICON_SRC := icon/tuneTrove Exports
IOS_DEST := ios/Runner/Assets.xcassets/AppIcon.appiconset
MACOS_DEST := macos/Runner/Assets.xcassets/AppIcon.appiconset

icon:
	@echo "→ iOS icons"
	cp "$(ICON_SRC)/tuneTrove-iOS-Default-1024x1024@1x.png"    "$(IOS_DEST)/AppIcon.png"
	cp "$(ICON_SRC)/tuneTrove-iOS-Dark-1024x1024@1x.png"       "$(IOS_DEST)/AppIcon-Dark.png"
	cp "$(ICON_SRC)/tuneTrove-iOS-TintedDark-1024x1024@1x.png" "$(IOS_DEST)/AppIcon-Tinted.png"
	cp "$(ICON_SRC)/tuneTrove-iOS-TintedLight-1024x1024@1x.png" "$(IOS_DEST)/AppIcon-TintedLight.png"
	cp "$(ICON_SRC)/tuneTrove-iOS-ClearDark-1024x1024@1x.png"  "$(IOS_DEST)/AppIcon-ClearDark.png"
	cp "$(ICON_SRC)/tuneTrove-iOS-ClearLight-1024x1024@1x.png" "$(IOS_DEST)/AppIcon-ClearLight.png"
	@echo "→ macOS icons (generated via sips)"
	sips -z 16   16   "$(ICON_SRC)/tuneTrove-iOS-Default-1024x1024@1x.png" --out "$(MACOS_DEST)/app_icon_16.png"   -s format png
	sips -z 32   32   "$(ICON_SRC)/tuneTrove-iOS-Default-1024x1024@1x.png" --out "$(MACOS_DEST)/app_icon_32.png"   -s format png
	sips -z 64   64   "$(ICON_SRC)/tuneTrove-iOS-Default-1024x1024@1x.png" --out "$(MACOS_DEST)/app_icon_64.png"   -s format png
	sips -z 128  128  "$(ICON_SRC)/tuneTrove-iOS-Default-1024x1024@1x.png" --out "$(MACOS_DEST)/app_icon_128.png"  -s format png
	sips -z 256  256  "$(ICON_SRC)/tuneTrove-iOS-Default-1024x1024@1x.png" --out "$(MACOS_DEST)/app_icon_256.png"  -s format png
	sips -z 512  512  "$(ICON_SRC)/tuneTrove-iOS-Default-1024x1024@1x.png" --out "$(MACOS_DEST)/app_icon_512.png"  -s format png
	sips -z 1024 1024 "$(ICON_SRC)/tuneTrove-iOS-Default-1024x1024@1x.png" --out "$(MACOS_DEST)/app_icon_1024.png" -s format png
	@echo "✓ Done"

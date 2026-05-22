.PHONY: format analyze test coverage lcov bump publish-ios publish-macos publish-android deps run-macos run-ios build-macos build-ios build-android icon

clean:
	rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

format:
	dart format lib/

analyze:
	flutter analyze

run-macos:
	flutter run -d macos --no-pub

run-ios:
	flutter run -d $(if $(DEVICE),$(DEVICE),iPhone) --no-pub

build-macos:
	flutter build macos

build-ios:
	flutter build ios

build-android:
	flutter build appbundle

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

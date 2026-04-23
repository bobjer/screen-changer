APP_NAME := ScreenChanger
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app
VERSION := 0.1.0
RELEASE_ZIP := $(BUILD_DIR)/$(APP_NAME)-$(VERSION).zip
CONTENTS := $(APP)/Contents
MACOS := $(CONTENTS)/MacOS
ARCH := $(shell uname -m)
MODULE_CACHE := /tmp/screen-changer-module-cache

.PHONY: all clean dist run

all: $(APP)

$(APP): Sources/ScreenChanger/main.swift Resources/Info.plist
	rm -rf "$(APP)"
	mkdir -p "$(MACOS)"
	cp Resources/Info.plist "$(CONTENTS)/Info.plist"
	xcrun swiftc \
		-swift-version 5 \
		-module-cache-path "$(MODULE_CACHE)" \
		-target $(ARCH)-apple-macosx13.0 \
		-framework AppKit \
		-framework CoreGraphics \
		-framework ServiceManagement \
		Sources/ScreenChanger/main.swift \
		-o "$(MACOS)/$(APP_NAME)"
	codesign --force --deep --sign - "$(APP)"

dist: $(APP)
	cd "$(BUILD_DIR)" && ditto -c -k --keepParent "$(APP_NAME).app" "$(APP_NAME)-$(VERSION).zip"
	shasum -a 256 "$(RELEASE_ZIP)"

run: all
	open "$(APP)"

clean:
	rm -rf "$(BUILD_DIR)"

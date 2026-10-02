PROJECT      := Buddr.xcodeproj
SCHEME       := Buddr
CONFIG       ?= Debug
DERIVED_DATA := build/DerivedData
APP          := $(DERIVED_DATA)/Build/Products/$(CONFIG)/Buddr.app
SOURCES      := Buddr BuddrTests
ARCH         := $(shell uname -m)
INSTALL_DIR  ?= $(HOME)/Applications
RELEASE_APP  := $(DERIVED_DATA)/Build/Products/Release/Buddr.app

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
	-destination 'platform=macOS,arch=$(ARCH)' -derivedDataPath $(DERIVED_DATA) -quiet

.PHONY: build test run install uninstall format lint clean

build:
	$(XCODEBUILD) build

test:
	$(XCODEBUILD) test

run: build
	pkill -x Buddr || true
	open "$(APP)"

# Release build copied to INSTALL_DIR (default ~/Applications); stops any running Buddr, including a dev build.
install:
	$(MAKE) build CONFIG=Release
	pkill -x Buddr || true
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/Buddr.app"
	ditto "$(RELEASE_APP)" "$(INSTALL_DIR)/Buddr.app"
	open "$(INSTALL_DIR)/Buddr.app"

uninstall:
	pkill -x Buddr || true
	rm -rf "$(INSTALL_DIR)/Buddr.app"

format:
	xcrun swift-format format --in-place --recursive --parallel $(SOURCES)

lint:
	xcrun swift-format lint --strict --recursive --parallel $(SOURCES)

clean:
	rm -rf build

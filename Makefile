PROJECT      := Buddr.xcodeproj
SCHEME       := Buddr
CONFIG       ?= Debug
DERIVED_DATA := build/DerivedData
APP          := $(DERIVED_DATA)/Build/Products/$(CONFIG)/Buddr.app
SOURCES      := Buddr BuddrTests
ARCH         := $(shell uname -m)

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
	-destination 'platform=macOS,arch=$(ARCH)' -derivedDataPath $(DERIVED_DATA) -quiet

.PHONY: build test run format lint clean

build:
	$(XCODEBUILD) build

test:
	$(XCODEBUILD) test

run: build
	-pkill -x Buddr
	open "$(APP)"

format:
	xcrun swift-format format --in-place --recursive --parallel $(SOURCES)

lint:
	xcrun swift-format lint --strict --recursive --parallel $(SOURCES)

clean:
	rm -rf build

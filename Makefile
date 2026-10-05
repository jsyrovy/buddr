PROJECT       := Buddr.xcodeproj
SCHEME        := Buddr
CONFIG        ?= Debug
DERIVED_DATA  := build/DerivedData
APP           := $(DERIVED_DATA)/Build/Products/$(CONFIG)/Buddr.app
SOURCES       := Buddr BuddrTests scripts
ARCH          := $(shell uname -m)
INSTALL_DIR   ?= $(HOME)/Applications
RELEASE_APP   := $(DERIVED_DATA)/Build/Products/Release/Buddr.app
RESULT_BUNDLE := build/Test.xcresult
MEASURE       := build/measure

XCODEBUILD    := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
	-destination 'platform=macOS,arch=$(ARCH)' -derivedDataPath $(DERIVED_DATA) -quiet

.PHONY: build test coverage run install uninstall measure format lint clean

build:
	$(XCODEBUILD) build

test:
	$(XCODEBUILD) test

# Coverage collection is enabled in the scheme (app target only); this keeps the result bundle and prints the report.
coverage:
	rm -rf "$(RESULT_BUNDLE)"
	$(XCODEBUILD) -resultBundlePath "$(RESULT_BUNDLE)" test
	xcrun xccov view --report --only-targets "$(RESULT_BUNDLE)"
	xcrun xccov view --report --files-for-target Buddr.app "$(RESULT_BUNDLE)"

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

# Measures the running Buddr (scripts/measure.swift --help); options in ARGS, e.g. make measure ARGS="--label idle".
# Compiled once: running the script through `xcrun swift` compiles it every time and keeps ~300 MB for the run.
measure: $(MEASURE)
	$(MEASURE) $(ARGS)

$(MEASURE): scripts/measure.swift
	mkdir -p build
	xcrun swiftc -O -o $@ $<

format:
	xcrun swift-format format --in-place --recursive --parallel $(SOURCES)

lint:
	xcrun swift-format lint --strict --recursive --parallel $(SOURCES)

clean:
	rm -rf build

XCODE=$(dir $(shell dirname $(shell xcode-select -p)))
BAZEL=tools/bazelwrapper
XCB=$(XCODE)/Contents/Developer/usr/bin/xcodebuild

# For development wrap all build services inside of the shim to make it easier
# to debug and replay builds.
# The shim isn't used in production
XCBBUILDSERVICE_PATH=$(PWD)/bazel-bin/BuildServiceShim/BuildServiceShim

# Build service to use when running `test` and `debug_*` actions below
BUILD_SERVICE=BazelBuildService

.PHONY: build
build:
	$(BAZEL) build :* //BuildServiceShim $(BUILD_SERVICE)

# Note: after using launchd to set an env var, apps that use it need to be
# relaunched: Xcode / terminals
install_bazel_progress_bar_support:
	$(BAZEL) build :BazelBuildServiceInstaller
	sudo installer -pkg bazel-bin/BazelBuildServiceInstaller.pkg -target /

uninstall_bazel_progress_bar_support:
	utils/uninstall.sh

# Available dummy targets
# TODO: add the ability to test all of these
DUMMY_XCODE_ARGS=-target CLI
# DUMMY_XCODE_ARGS=-target iOSApp -sdk iphonesimulator
test: build
	rm -rf /tmp/xcbuild.*
	/usr/bin/env - TERM="$(TERM)" \
		SHELL="$(SHELL)" \
		PATH="$(PATH)" \
		HOME="$(HOME)" \
		XCODE="$(XCODE)" \
		XCBBUILDSERVICE_PATH=$(XCBBUILDSERVICE_PATH) \
		XCODE=$(XCODE) \
		PWD=$(PWD)/iOSApp \
		$(XCB) -project $(PWD)/iOSApp/iOSApp.xcodeproj build -jobs 1 $(DUMMY_XCODE_ARGS)

# Random development commands
# Opens Xcode with the build service selected
open_xcode_with_sk_logging: build
	/usr/bin/env - TERM="$(TERM)"; \
			SOURCEKIT_LOGGING=3 \
	    export SHELL="$(SHELL)"; \
	    export PATH="$(PATH)"; \
	    export HOME="$(HOME)"; \
	    export XCODE="$(XCODE)"; \
	    export XCBBUILDSERVICE_PATH="$(XCBBUILDSERVICE_PATH)"; \
			$(XCODE)/Contents/MacOS/Xcode &> /tmp/xcode_sourcekit.log

open_xcode: build
	/usr/bin/env - TERM="$(TERM)"; \
	    export SHELL="$(SHELL)"; \
	    export PATH="$(PATH)"; \
	    export HOME="$(HOME)"; \
	    export XCODE="$(XCODE)"; \
	    export XCBBUILDSERVICE_PATH="$(XCBBUILDSERVICE_PATH)"; \
			$(XCODE)/Contents/MacOS/Xcode

clean:
	rm -rf /tmp/xcbuild.*

symlink_external:
	ln -sf $(shell tools/bazelwrapper info execution_root)/external external

run_shim: build
	XCBBUILDSERVICE_PATH=$(XCBBUILDSERVICE_PATH) $(XCBBUILDSERVICE_PATH)

disable_indexing:
	defaults write com.apple.dt.XCode IDEIndexDisable 1

# Note: the static build service doesn't work with this ATM
enable_indexing:
	defaults write com.apple.dt.XCode IDEIndexDisable 0

# Uses xxd to inspect outputs
hex_dump: FILE_A=/tmp/xcbuild.in
hex_dump: FILE_B=
hex_dump: 
	@xxd -c 16 $(FILE_A)
	@[[ ! -f "$(FILE_B)" ]] || xxd -c 16 $(FILE_B)

# Dumps the raw bits
dump:
	echo "print(repr(open('$(FILE)', 'rb').read()))" | python

# Dumps raw values from the parsed output stream
debug_output_raw:
	@cat /tmp/xcbuild.out | \
	    $(BAZEL) run $(BUILD_SERVICE) -- --dump

# Dumps raw values from the parsed input stream
debug_input_raw:
	@cat /tmp/xcbuild.in | \
	    $(BAZEL) run $(BUILD_SERVICE) -- --dump

# Dumps human readable values from the parsed output stream
debug_output_h:
	@cat /tmp/xcbuild.out | \
	    $(BAZEL) run $(BUILD_SERVICE) -- --dump_h

# Dumps human readable values from the parsed input stream
debug_input_h:
	@cat /tmp/xcbuild.in | \
	    $(BAZEL) run $(BUILD_SERVICE) -- --dump_h

debug_output_python: build
	@cat /tmp/xcbuild.out | utils/msgpack_dumper.py

# Attempt to create custom index stores to be used as source for build service
# will come back to this later once we can pass the correct indexing msg
# foo:
# 	mkdir -p /tmp/xcbuildkit-debug/iOSApp /tmp/xcbuildkit-debug/CLI \
# 	&& \
# 	/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang \
# 	-isysroot \
# 	/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator15.4.sdk \
# 	-index-store-path \
# 	/tmp/xcbuildkit-debug \
# 	-c \
# 	iOSApp/iOSApp/main.m \
# 	-o \
# 	/tmp/xcbuildkit-debug/iOSApp/main.o \

#Copyright (c) 2022, XCBuildKit contributors
#All rights reserved.
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions are met:
#
#1. Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#2. Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
#ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
#ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#The views and conclusions contained in the software and documentation are those
#of the authors and should not be interpreted as representing official policies,
#either expressed or implied, of the IDEXCBProgress project.
XCODE=$(dir $(shell dirname $(shell xcode-select -p)))
BAZEL=tools/bazelwrapper
XCB=$(XCODE)/Contents/Developer/usr/bin/xcodebuild

# For development wrap all build services inside of the shim to make it easier
# to debug and replay builds.
# The shim isn't used in production
XCBBUILDSERVICE_PATH=$(PWD)/bazel-bin/BuildServiceShim/BuildServiceShim

# Build service to use when running `test` and `debug_*` actions below
BUILD_SERVICE=XCBBuildServiceProxy

# See below comment - Bazel is not making a symlink.
# This is of course just riddled with problems
# https://github.com/jerrymarino/xcbuildkit/issues/36
# Assumptions on Makefile and Bazelrc / Bazel 5 it works for the cases here
BUILD_SERVICE_PATH=$(shell echo $$PWD/bazel-out/applebin_macos-darwin_*-fastbuild-ST-*/bin/$(BUILD_SERVICE)_archive-root/$(BUILD_SERVICE).app/Contents/MacOS/$(BUILD_SERVICE))

.PHONY: build
build:
	@$(BAZEL) build :* //BuildServiceShim $(BUILD_SERVICE)

# Note: after using launchd to set an env var, apps that use it need to be
# relaunched: Xcode / terminals
install_bazel_progress_bar_support:
	$(BAZEL) build :BazelBuildServiceInstaller
	sudo installer -pkg bazel-bin/BazelBuildServiceInstaller.pkg -target /

uninstall_bazel_progress_bar_support:
	utils/uninstall.sh

# Available dummy targets
DUMMY_XCODE_ARGS=-target CLI
# DUMMY_XCODE_ARGS=-target iOSApp -sdk iphonesimulator
test: build
	rm -rf /tmp/xcbuild.*
	/usr/bin/env - TERM="$(TERM)" \
		SHELL="$(SHELL)" \
		PATH="$(PATH)" \
		HOME="$(HOME)" \
		XCODE="$(XCODE)" \
	    	DEBUG_BUILDSERVICE_PATH="$(BUILD_SERVICE_PATH)"; \
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
	    export DEBUG_BUILDSERVICE_PATH="$(BUILD_SERVICE_PATH)"; \
	    export XCBBUILDSERVICE_PATH="$(XCBBUILDSERVICE_PATH)"; \
			$(XCODE)/Contents/MacOS/Xcode

open_xcode: build
	/usr/bin/env - TERM="$(TERM)"; \
	    export SHELL="$(SHELL)"; \
	    export PATH="$(PATH)"; \
	    export HOME="$(HOME)"; \
	    export XCODE="$(XCODE)"; \
	    export DEBUG_BUILDSERVICE_PATH="$(BUILD_SERVICE_PATH)"; \
	    export XCBBUILDSERVICE_PATH="$(XCBBUILDSERVICE_PATH)"; \
			$(XCODE)/Contents/MacOS/Xcode

clean:
	rm -fr /tmp/xcbuild.* && \
	rm -fr /tmp/xcbuild-*

symlink_external:
	ln -sf $(shell tools/bazelwrapper info execution_root)/external external

run_shim: build
	XCBBUILDSERVICE_PATH=$(XCBBUILDSERVICE_PATH) $(XCBBUILDSERVICE_PATH)

disable_indexing:
	defaults write com.apple.dt.XCode IDEIndexDisable 1

# Note: the static build service doesn't work with this ATM
enable_indexing:
	defaults write com.apple.dt.XCode IDEIndexDisable 0

enable_indexing_logs:
	defaults write com.apple.dt.Xcode IDEIndexShowLog 1

disable_indexing_logs:
	defaults write com.apple.dt.Xcode IDEIndexShowLog 0

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

# For more details about the usage of these see TODOs in `Examples/XCBBuildServiceProxy/main.swift`
#
MACOS_SDK=$(shell xcrun --sdk macosx --show-sdk-path) # /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk
CLANG=$(shell xcrun --find clang) # /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
WORKSPACE_HASH=frhmkkebaragakhdzyysbrsvbgtc
TMP_DD=/tmp/xcbuild-dd
TMP_INDEX_STORE=${TMP_DD}/iOSApp-${WORKSPACE_HASH}/Index/DataStore
TMP_OUT=/tmp/xcbuild-out

make generate_custom_index_store:
	mkdir -p ${TMP_DD} && \
	mkdir -p ${TMP_OUT} && \
	${CLANG} \
	-isysroot ${MACOS_SDK} \
	-c ${PWD}/iOSApp/CLI/main.m \
	-o ${TMP_OUT}/main.o \
	-index-store-path ${TMP_INDEX_STORE}
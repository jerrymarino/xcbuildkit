# Don't use xcode-select here for development
# Note: This is tested on Xcode 11 Beta 5
#
# The protocol has changed a bit since 10.2.1
# Details:  was notified a build operation started without being notified that its planning operation finished
XCODE=$(dir $(shell dirname $(shell xcode-select -p)))
BAZEL=tools/bazelwrapper

clean:
	rm -rf /tmp/xcbuild.*

symlink_external:
	ln -sf $(shell tools/bazelwrapper info execution_root)/external external

# Hardcode all the paths to Xcode build for debugging reasons
XCB=$(XCODE)/Contents/Developer/usr/bin/xcodebuild

# For development wrap all build services inside of the shim to make it easier
# to debug and replay builds.
# The shim isn't used in production
XCBBUILDSERVICE_PATH=$(PWD)/bazel-bin/BuildServiceShim/BuildServiceShim

.PHONY: build
build:
	$(BAZEL) build :* //BuildServiceShim

# Available dummy targets
# TODO: add the ability to test all of these
DUMMY_XCODE_ARGS=-target CLI
# DUMMY_XCODE_ARGS=-target iOSApp -sdk iphonesimulator
test: build
	$(BAZEL) build BSBuildService
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

# Opens Xcode with the build service selected
open_xcode: build
	/usr/bin/env - TERM="$(TERM)"; \
	    export SHELL="$(SHELL)"; \
	    export PATH="$(PATH)"; \
	    export HOME="$(HOME)"; \
	    export XCODE="$(XCODE)"; \
	    export XCBBUILDSERVICE_PATH="$(XCBBUILDSERVICE_PATH)"; \
             $(XCODE)/Contents/MacOS/Xcode

run_shim: build
	XCBBUILDSERVICE_PATH=$(XCBBUILDSERVICE_PATH) $(XCBBUILDSERVICE_PATH)

enable_indexing:
	defaults write com.apple.dt.XCode IDEIndexDisable 1

# Note: the static build service doesn't work with this ATM
disable_indexing:
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

# Dumps the parsed stream
debug_output:
	@cat /tmp/xcbuild.out | \
	    $(BAZEL) run BSBuildService -- --dump

# Dumps the parsed stream
debug_input:
	@cat /tmp/xcbuild.in | \
	    $(BAZEL) run BSBuildService -- --dump

# FIXME see stub on using `replace`/`redirect`
debug_output_python: build
	@cat /tmp/xcbuild.out | utils/msgpack_dumper.py


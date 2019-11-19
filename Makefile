# Don't use xcode-select here for development
# Note: This is tested on Xcode 11 Beta 5
#
# The protocol has changed a bit since 10.2.1
# Details:  was notified a build operation started without being notified that its planning operation finished
XCODE=$(dir $(shell dirname $(shell xcode-select -p)))
INC=$(XCODE)/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include
BAZEL=tools/bazelwrapper

# Compilation of the runner
# This is mainly a debugging utility. Consider using Bazel
xcbrunner: main.c
	clang -I $(INC) main.c -o xcbrunner

clean:
	rm -rf /tmp/xcbuild.*


symlink_external:
	ln -sf $(shell tools/bazelwrapper info execution_root)/external external

# Hardcode all the paths to Xcode build for debugging reasons
XCB=$(XCODE)/Contents/Developer/usr/bin/xcodebuild
XCBBUILDSERVICE_PATH=$(PWD)/xcbrunner

.PHONY: build
build: xcbrunner
	$(BAZEL) build BSBuildService

# Available dummy targets
DUMMY_XCODE_ARGS=-target CLI
# DUMMY_XCODE_ARGS=-target iOSApp -sdk iphonesimulator

test: xcbrunner
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

# Known issues with Xcode
# - indexing requests aren't done yet
# - it will only work after the first build
# - if you have a nasty environment, this will not work!
open_xcode: build
	defaults write com.apple.dt.XCode IDEIndexDisable 1
	/usr/bin/env - TERM="$(TERM)"; \
	    export SHELL="$(SHELL)"; \
	    export PATH="$(PATH)"; \
	    export HOME="$(HOME)"; \
	    export XCODE="$(XCODE)"; \
	    export XCBBUILDSERVICE_PATH="$(XCBBUILDSERVICE_PATH)"; \
             $(XCODE)/Contents/MacOS/Xcode

SERVICE=$(XCODE)/Contents/SharedFrameworks/XCBuild.framework/PlugIns/XCBBuildService.bundle/Contents/MacOS/XCBBuildService

# Uses xxd to inspect outputs
hex_dump: FILE_A=/tmp/xcbuild.in
hex_dump: FILE_B=
hex_dump: 
	@xxd -c 16 $(FILE_A)
	@[[ ! -f "$(FILE_B)" ]] || xxd -c 16 $(FILE_B)

# Need to actually populate this first ( e.g. make test )
read_streams_to_debug: 
	$$(sleep 2 && killall -10 Python) &   \
	(cat /tmp/xcbuild.in | ./unpacker.py ) || true
	mv /tmp/xcbuild.diags /tmp/xcbuild.in.diags
	$$(sleep 2 && killall -10 Python) &   \
	(cat /tmp/xcbuild.out | ./unpacker.py | cat  > /tmp/xcbuild.out.diags) || true
	mv /tmp/xcbuild.diags /tmp/xcbuild.out.diags


dump:
	echo "print(repr(open('$(FILE)', 'rb').read()))" | python

# Tests the differences between what we expect and not.
# The implementation here is poor and it'd be nice to have better tooling for
# this
# test_writer:
#	@cat example_output/nooped/xcbuild.in | \
#	    $(BAZEL) run BSBuildService > /tmp/x
#	./utils/diff.py /tmp/x $(PWD)/golden_output/xcbuild.basic.out

# Dumps the parsed stream
debug_output:
	@cat /tmp/xcbuild.out | \
	    $(BAZEL) run BSBuildService -- --dump

# Dumps the parsed stream
debug_input:
	@cat /tmp/xcbuild.in | \
	    $(BAZEL) run BSBuildService -- --dump

# Dumps the MsgPack data structure for an input
debug_raw_input:
	@cat /tmp/xcbuild.in | \
	    $(BAZEL) run BSBuildService -- --raw

# FIXME see stub on using `replace`/`redirect`
debug_output_python: build
	@cat /tmp/xcbuild.out | utils/msgpack_dumper.py


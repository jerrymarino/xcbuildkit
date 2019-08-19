# Don't use xcode-select here for development
# Note: This is tested on Xcode 11 Beta 5
#
# The protocol has changed a bit since 10.2.1
# Details:  was notified a build operation started without being notified that its planning operation finished
XCODE=$(dir $(shell dirname $(shell xcode-select -p)))

INC=$(XCODE)/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include

# Compilation of the runner
xcbr:
	clang -I $(INC)  main.c -o xcbrunner

clean:
	rm -rf /tmp/xcbuild.*


# Hardcode all the paths to Xcode build for debugging reasons
XCB=$(XCODE)/Contents/Developer/usr/bin/xcodebuild
XCBBUILDSERVICE_PATH=$(PWD)/xcbrunner

test: xcbr
	rm -rf /tmp/xcbuild.*
	export XCBBUILDSERVICE_PATH=$(XCBBUILDSERVICE_PATH); \
	export XCODE=$(XCODE); \
		cd iOSApp;  \
		$(DTRUSS) sleep 3 && $(XCB) build -jobs 1 -target iOSApp \
		-sdk iphonesimulator

# Known issues with Xcode
# - indexing requests aren't done yet
# - it will only work after the first build
open_xcode:
	defaults write com.apple.dt.XCode IDEIndexDisable 1
	/usr/bin/env - TERM="$(TERM)"; \
	    export SHELL="$(SHELL)"; \
	    export PATH="$(PATH)"; \
	    export HOME="$(HOME)"; \
	    export XCODE="$(XCODE)"; \
	    export XCBBUILDSERVICE_PATH="$(XCBBUILDSERVICE_PATH)"; \
             $(XCODE)/Contents/MacOS/Xcode

SERVICE=$(XCODE)/Contents/SharedFrameworks/XCBuild.framework/PlugIns/XCBBuildService.bundle/Contents/MacOS/XCBBuildService
#compare:  FILE=xcbuild.in.pif
compare:  FILE=/tmp/xcbuild.in
compare: 
	$$(sleep 2 && killall -10 Python) &   \
	(cat $(FILE) | ./service.py > s.out) || true
	cat $(FILE) | $(SERVICE) > x.out
	xxd -c 16 s.out
	xxd -c 16 x.out

# Need to actually populate this first ( e.g. make test )
read_streams_to_debug: 
	$$(sleep 2 && killall -10 Python) &   \
	(cat /tmp/xcbuild.in | ./unpacker.py ) || true
	mv /tmp/xcbuild.diags /tmp/xcbuild.in.diags
	$$(sleep 2 && killall -10 Python) &   \
	(cat /tmp/xcbuild.out | ./unpacker.py | cat  > /tmp/xcbuild.out.diags) || true
	mv /tmp/xcbuild.diags /tmp/xcbuild.out.diags


# FIXME: this isn't working
dump:
	echo "print(str(open('$(FILE)', 'rb').read()))" | python


test_debug: xcbr
	rm -rf /tmp/xcbuild.*
	killall -10 Python; sleep 2
	touch /tmp/xcbuild.in
	touch /tmp/xcbuild.out
	tail -F  /tmp/xcbuild.in  | ./unpacker.py /tmp/xcbuild.in.diags &
	tail -F /tmp/xcbuild.out  | ./unpacker.py /tmp/xcbuild.out.diags &
	sleep 1
	#cd iOSApp;  \
		sudo xcodebuild clean -jobs 1 -target iOSApp  \
		-sdk iphonesimulator
	export DEBUG=YES; \
	export XCBUILD_TRACING_URL=/tmp/xcbuild.trace; \
        export XCODE=$(XCODE); \
	export XCBBUILDSERVICE_PATH=$(XCBBUILDSERVICE_PATH); \
		cd iOSApp;  \
		$(DTRUSS) sleep 3 && $(XCB) build -jobs 1   -target iOSApp  \
		-sdk iphonesimulator 2>&1 | tee  /tmp/xcodebuild.log


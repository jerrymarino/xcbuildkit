# xcbuildkit

xcbuildkit is a framework to extend or replace Xcode's build system. No plugins
needed!

# Usage

Checkout the [examples](Examples/) and [Makefile](Makefile).

### Bazel Progress Bar Only

To install the progress bar for Bazel in Xcode, the example BazelBuildService
provides all functionality.

```
tools/bazelwrapper build :BazelBuildServiceInstaller
sudo installer -pkg bazel-bin/BazelBuildServiceInstaller.pkg -target /
```
_The installer requires sudo to setup an environment variable override. For
testing only use `make open_xcode`_


Additonally set Bazel options ( e.g. in `~/.bazelrc` ) :
- setup Bazel to write a binary BEP to /tmp/
  `--build_event_binary_file=/tmp/bep.bep` _This can be improved in the future_

- _optionally_ crank up the BEP updates:
  `--progress_report_interval=1 --build_event_publish_all_actions`

# What is this used for?

Generally, integrating third party build systems like Bazel.

Xcode can't render updates ( progress, errors, and warnings ) for external
build systems, e.g. Bazel, because it isn't intrinsically aware of these
systems. There is no supported way for run script build phases to communicate
their state to Xcode. As a result, during long running tasks, like downloading
a dependency or compiling an iOS application, Xcode's UI feels stuck. This is
problematic as it can make the ad-hoc tasks "feel slow" due to the perception
of no progress.

Additionally, for other features like testing, Xcode needs source files loaded
into test targets. Currently, Xcode requires mocking out the toolchain with stub
linkers and compilers so XCBuild can run ( e.g. XCHammer ). This adds extra,
unavoidable overhead to each build. xcbuildkit enables replacing Xcode's build
system entirely to improves the user experience of external build systems and
remove the hacks.


# Build system architecture

![default achitecture](Docs/default_architecture.png?raw=true "Default achitecture")

To build applications, Xcode runs tools like compilers and linkers via a build
service daemon. Xcode and the build service communicate via a binary protocol.
For example, to create a build, Xcode sends a create build message.  The build
service creates the build, and when the build is done, it sends a message back
to Xcode know it's done. Throughout the lifecycle of the build, diagnostics and
other information are also exchanged via this protocol. Xcode's UI is driven by
this protocol as well.

xcbuildkit simply implements this protocol to enable extending or replacing
default behavior. No plugins or hacks necessary!

# Injecting external build system progress messages via a Proxy

![build service proxy](Docs/xcbuildkit_proxy.png?raw=true "Build service proxy")

A common path to integrate external build systems like buck or Bazel is to run
them via a runscript. To preserve all functionality of Xcode's build system and
inject progress messages and build diagnostics xcbuildkit provides a proxy build
service. The main difference between the default architecture is that progress
messages are injected within XCBBuildService's message.

_See [examples/BazelBuildService](Examples/BazelBuildService) for an example implementation._

# Replacing Xcode's build system with an external build system

![build service replacement](Docs/xcbuildkit_replacement.png?raw=true "Build service replacement")


It may be desirable to replace Xcode's default build system with an external
one. This approach allows Xcode to run external build systems transparently to
the user.  Additionally, it removes the need to have ad-hoc integration via
runscripts, which require stubbing out Xcode's toolchain with mock tools. 

_See [examples/BSBuildService](Examples/BSBuildService) for an example implementation._

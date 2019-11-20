# xcbuildkit

xcbuildkit is a system to implement external build systems inside of Xcode

_It's currently an unstable prototype to explore how it will all fit together._

# Usgage

See Examples/BProgress





## What is this used for?

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
unavoidable overhead to each build. xcbuildkit enables entirely replacing the
build invocation an remove overhead.

## Goals and Outcomes

The goal of IDEXCBProgress is to find ways to notify Xcode of updates like
progress, errors, and warnings which can then be populated by external build
systems like Bazel or Buck.

**This project is an unofficial, non Apple, experiment that uses private Xcode
APIs.**

## Notes and current state

As, Xcode <-> build service, aka the build system daemon, have a clear protocol
and interface between each other, it seems possible to hook in build systems at
this level. Ideally, IDEXCBProgress is achievable without hacking Xcode's
runtime via a plugin: the plugin currently exists as a fallback/alternate
approach to utilizing the build protocol.

**Build protocol integration**

XCBuildKit replaces the build service and interact with Xcode over the build
protocol via the corresponding file descriptors. This would give total control
of the build process to the user. A possible implementation simply dupes ad-hoc
progress ( in the form of build protocol messages ) to the original output file
descriptor.





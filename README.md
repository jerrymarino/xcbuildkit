# IDEXCBProgress

IDEXCBProgress adds the ability to show progress from ad-hoc build systems
inside of Xcode.

_It's currently an unstable prototype to explore how it will all fit together._

## What is this used for?

Xcode can't render updates ( progress, errors, and warnings ) for external
build systems, e.g. Bazel, because it isn't intrinsically aware of these
systems. There is no supported way for run script build phases to communicate
their state to Xcode. As a result, during long running tasks, like downloading
a dependency or compiling an iOS application, Xcode's UI feels stuck. This is
problematic as it can make the ad-hoc tasks "feel slow" due to the perception
of no progress.

## Goals and Outcomes

The goal of IDEXCBProgress is to find ways to notify Xcode of updates like
progress, errors, and warnings which can then be populated by external build
systems like Bazel or Buck.

**This project is an unofficial, non Apple, experiment that uses private Xcode
APIs.**

## Notes and current state

As, Xcode <-> build service, aka the build system daemon, have a clear protocol
and interface between each other, it seems possible to hook in progress at this
level. Ideally, IDEXCBProgress is achievable without hacking Xcode's runtime
via a plugin: the plugin currently exists as a fallback/alternate approach to
utilizing the build protocol.

**Build protocol integration**

One approach is to replace the build service and interact with Xcode over the
build protocol via the corresponding file descriptors. This would give total
control of the build process to the user. A possible implementation simply
dupes ad-hoc progress ( in the form of build protocol messages ) to the
original output file descriptor.

**Plugin integration**

The project contains a prototype/demo of how an Xcode plugin could work. It
wasn't immediately clear if there is a way to send additional messages to Xcode
via the build protocol, or if that would be a working/correct solution. The
notifies Xcode about updates by invoking delegate callbacks resulted from build
protocol messages, as if the protocol had actually sent these messages.


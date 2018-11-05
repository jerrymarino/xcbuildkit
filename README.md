# IDEXCBProgress

IDEXCBProgress adds the ability to show progress from ad-hoc build systems
inside of Xcode.

_It's currently an unstable prototype to explore how it will all fit together._

## What is this used for?

Xcode can't render updates ( progress, errors, and warnings ) for external
build systems, e.g. SPM, Bazel, because it isn't intrinsically aware of these
systems.  During long running tasks, like downloading a dependency or compiling
an iOS application, Xcode's UI feels stuck. This is problematic as it can make
the ad-hoc tasks "feel slow" due to the perception of no progress.

## Goals and Outcomes

The goal of IDEXCBProgress is to provide a thin subsystem to notify Xcode of
updates like progress, errors, and warnings which can then be populated by
external build systems like Bazel or Buck.

**This project is an unoffical, non Apple project. Getting official Xcode
support of this ability is non-goal. However, if the work results in a good
API, perhaps the Xcode team may see it and want to add it ;).**

## Notes and current state

The project is currently a prototype/demo of how an Xcode plugin could work.

As, Xcode <-> `XCBBuildService`, aka the build system daemon, have a clear
protocol and interface between each other, it seems possible to hook in
progress at this level. It wasn't immediately clear if there is a way to send
additional messages to Xcode via this interface, or if this is the correct
solution.

_It would be nice if this was achievable without adding an Xcode plugin. At the
end of the day, the build protocol is as undocumented and subject to change as
Xcode, so it isn't a dealbreaker if it ends up being a plugin._


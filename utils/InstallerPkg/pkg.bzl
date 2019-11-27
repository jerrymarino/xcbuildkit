def _impl(ctx):
    # Use the name of the app
    # This relies on the convention of macos_application
    app_name = ctx.attr.app.label.name
    extracted_app = ctx.actions.declare_directory(app_name + "_app_dir")

    # Bazel givs us the .app as a zip file.
    # Unzip so we can directly package the .app
    unzip_cmd = [
        "mkdir -p " + extracted_app.path + ";",
        "unzip", 
        "-q", 
        ctx.expand_location("$(location " + str(ctx.attr.app.label) + ")", targets=[ctx.attr.app]),
        "-d",
        extracted_app.path,
    ]
    ctx.actions.run_shell(inputs=ctx.attr.app.files, outputs=[extracted_app],
        command=" ".join(unzip_cmd))

    cmd = [
        "pkgbuild", 
        "--root",
        # This puts the .app at the root of the package
        # And causes the install_location to be the name of the app.
        # e.g. /opt/XCBuildKit/XCBuildKit.app
        extracted_app.path + "/" + app_name + ".app",
        "--scripts",
        ctx.attr.scripts_path,
        "--identifier",
        ctx.attr.identifier,
        "--version",
        ctx.attr.version,

        "--install-location", ctx.attr.install_location,
        ctx.outputs.pkg.path
    ]
    inputs = [extracted_app]
    for f in ctx.attr.scripts:
        inputs.extend(f.files.to_list())
    ctx.actions.run_shell(outputs=[ctx.outputs.pkg], command=" ".join(cmd),
        inputs=inputs)

# Consider implementing this into rules apple or more generally
# https://github.com/bazelbuild/rules_pkg/tree/master/pkg
# Provide a similar API as pkgbuild, but glob the "scripts" attribute
_macos_application_installer = rule(
    implementation = _impl,
    attrs = {
        "app" : attr.label(),
        "identifier": attr.string(),
        "version": attr.string(default="1.0"),
        "install_location": attr.string(),
        "scripts": attr.label_list(allow_files=True),
        "scripts_path": attr.string(),
    },
    outputs = { "pkg": "%{name}.pkg" }
)

def macos_application_installer(**kwargs):
    scripts = "utils/InstallerPkg/scripts/"
    install_location = "/opt/XCBuildKit/XCBuildKit.app"
    _macos_application_installer(
        scripts_path=scripts,
        scripts=native.glob([scripts + "*"]),
        install_location=install_location,
        **kwargs
    )


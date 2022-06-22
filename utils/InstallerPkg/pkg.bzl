load("@build_bazel_rules_apple//apple:providers.bzl", "AppleBundleInfo")

def _pkg_impl(ctx):
    # Use the name of the app
    # This relies on the convention of macos_application
    app_name = ctx.attr.app.label.name
    extracted_app = ctx.actions.declare_directory(app_name + "_app_dir")

    # Bazel gives us the .app as a zip file.
    # Unzip so we can directly package the .app
    bundle_zip = ctx.attr.app[AppleBundleInfo].archive
    unzip_cmd = [
        "mkdir -p " + extracted_app.path + ";",
        "unzip",
        "-q",
        bundle_zip.path,
        "-d",
        extracted_app.path,
    ]
    ctx.actions.run_shell(
        inputs = ctx.attr.app.files,
        outputs = [extracted_app],
        command = " ".join(unzip_cmd),
    )

    cmd = [
        "pkgbuild",
        "--root",
        # This puts the .app at the root of the package
        # And causes the install_location to be the name of the app.
        # e.g. /opt/XCBuildKit/XCBuildKit.app
        extracted_app.path + "/" + app_name + ".app",
        "--identifier",
        ctx.attr.identifier,
        "--version",
        ctx.attr.version,
        "--install-location",
        ctx.attr.install_location,
        ctx.outputs.pkg.path,
    ]

    inputs = [extracted_app]
    if ctx.attr.scripts:
        # We need to smash all the scripts into a directory that this can pick
        # pkgbuild can pick them up
        scripts_dir = ctx.actions.declare_directory(app_name + "_scripts_dir")
        prepare_scripts_cmd = ["mkdir -p", scripts_dir.path, ";\n"]
        for script in ctx.attr.scripts.files.to_list():
            # build may mutate
            prepare_scripts_cmd.extend(["ditto", script.path, scripts_dir.path + "/" + script.basename + ";\n"])

        scripts = ctx.attr.scripts.files.to_list()
        ctx.actions.run_shell(
            outputs = [scripts_dir],
            command = " ".join(prepare_scripts_cmd),
            inputs = scripts,
        )

        ## Add the scripts_dir to the main command
        inputs.append(scripts_dir)
        cmd.extend(["--scripts", scripts_dir.path])

    ctx.actions.run_shell(
        outputs = [ctx.outputs.pkg],
        command = " ".join(cmd),
        inputs = inputs,
    )

# Consider implementing this into rules apple or more generally
# https://github.com/bazelbuild/rules_pkg/tree/master/pkg
# Provide a similar API as pkgbuild, but glob the "scripts" attribute
macos_application_installer_pkg = rule(
    implementation = _pkg_impl,
    attrs = {
        "app": attr.label(providers = [AppleBundleInfo]),
        "identifier": attr.string(),
        "version": attr.string(default = "1.0"),
        "install_location": attr.string(),
        "scripts": attr.label(),
    },
    outputs = {"pkg": "%{name}.pkg"},
)

def _product_impl(ctx):
    # Use the name of the app
    # This relies on the convention of macos_application
    input_pkg = ctx.attr.package.files.to_list()[0]
    distribution = ctx.attr.distribution.files.to_list()[0]
    cmd = [
        "productbuild",
        "--distribution",
        distribution.path,
        "--version",
        ctx.attr.version,
        "--package-path",
        input_pkg.dirname,
        ctx.outputs.pkg.path,
    ]
    inputs = [distribution, input_pkg]

    if ctx.attr.resources:
        # We need to smash all the resources into a directory that this can pick
        # pkgbuild can pick them up
        resources_dir = ctx.actions.declare_directory(ctx.attr.name + "_resources_dir")
        prepare_resources_cmd = ["mkdir -p", resources_dir.path, ";\n"]
        for script in ctx.attr.resources.files.to_list():
            # build may mutate
            prepare_resources_cmd.extend(["ditto", script.path, resources_dir.path + "/" + script.basename + ";\n"])

        resources = ctx.attr.resources.files.to_list()
        ctx.actions.run_shell(
            outputs = [resources_dir],
            command = " ".join(prepare_resources_cmd),
            inputs = resources,
        )

        ## Add the resources_dir to the main command
        inputs.append(resources_dir)
        cmd.extend(["--resources", resources_dir.path])

    ctx.actions.run_shell(
        outputs = [ctx.outputs.pkg],
        command = " ".join(cmd),
        inputs = inputs,
    )

# Builds packagebuild product
macos_application_installer_product = rule(
    implementation = _product_impl,
    attrs = {
        "distribution": attr.label(allow_single_file = True),
        "resources": attr.label(allow_single_file = True),
        "version": attr.string(),
        "package": attr.label(allow_single_file = True),
    },
    outputs = {"pkg": "%{name}.pkg"},
)

def macos_application_installer(**kwargs):
    """
    This macro builds an installer product

    params:

    scripts: a filegroup of scripts. As pkgbuild needs these in 1 single layer,
    they are flattend during build time

    resources: a filegroup of resources. As product build needs these in 1 single layer,
    they are flattend during build time
    """
    scripts = kwargs.pop("scripts")
    install_location = "/opt/XCBuildKit/XCBuildKit.app"
    mkargs = kwargs
    name = mkargs.pop("name")

    resources = mkargs.pop("resources")
    distribution = mkargs.pop("distribution")

    macos_application_installer_pkg(
        name = name + "_impl",
        scripts = scripts,
        install_location = install_location,
        **mkargs
    )

    native.filegroup(
        name = name + "_distribution",
        srcs = native.glob([distribution]),
    )

    macos_application_installer_product(
        name = name,
        distribution = name + "_distribution",
        resources = resources,
        version = "1.0",
        package = name + "_impl",
    )

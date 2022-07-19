load("//rules:jar.bzl", _clojure_jar_impl = "clojure_jar_impl")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")

clojure_library = rule(
    doc = "Define a clojure library",
    attrs = {
        "srcs": attr.label_list(default = [], allow_files = True),
        "deps": attr.label_list(default = [], providers = [[JavaInfo]]),
        "runtime_deps": attr.label_list(default = [], providers = [[JavaInfo]]),
        "data": attr.label_list(default = [], allow_files = True),
        "resources": attr.label_list(default=[], allow_files=True),
        "aot": attr.string_list(default = [], doc = "namespaces to be compiled"),
        "resource_strip_prefix": attr.string(default = ""),
        "compiledeps": attr.label_list(default = []),
        "javacopts": attr.string_list(default = [], allow_empty = True, doc = "Optional javac compiler options"),

        "_clojureworker_binary": attr.label(doc="Label for the ClojureWorker binary",
                                            default=Label("@rules_clojure//java/rules_clojure:ClojureWorker"), executable = True, cfg="exec"),
        "_compile_classpath": attr.label_list(doc="classpath for the compilation worker",
                                              cfg="exec",
                                              default = [Label("@rules_clojure_maven//:org_projectodd_shimdandy_shimdandy_impl")]),
        "_jar_classpath": attr.label_list(doc="classpath for rules-clojure.jar",
                                         cfg="exec",
                                         default = [Label("@rules_clojure_maven//:org_projectodd_shimdandy_shimdandy_impl"),
                                                    Label("@rules_clojure//src/rules_clojure:jar-lib")]),

    },
    provides = [JavaInfo],
    implementation = _clojure_jar_impl,
)

clojure_library_bootstrap = rule(
    doc = "Define a clojure library",
    attrs = {
        "srcs": attr.label_list(default = [], allow_files = True),
        "deps": attr.label_list(default = ["@rules_clojure//src/rules_clojure:jar-lib-bootstrap"], providers = [[JavaInfo]]),
        "runtime_deps": attr.label_list(default = [], providers = [[JavaInfo]]),
        "data": attr.label_list(default = [], allow_files = True),
        "resources": attr.label_list(default=[], allow_files=True),
        "aot": attr.string_list(default = [], doc = "namespaces to be compiled"),
        "resource_strip_prefix": attr.string(default = ""),
        "compiledeps": attr.label_list(default = []),
        "javacopts": attr.string_list(default = [], allow_empty = True, doc = "Optional javac compiler options"),

        "_clojureworker_binary": attr.label(doc="Label for the ClojureWorker binary",
                                            default=Label("@rules_clojure//java/rules_clojure:ClojureWorker"), executable = True, cfg="exec"),
        "_compile_classpath": attr.label_list(doc="classpath for the compilation worker",
                                              cfg="exec",
                                              default = [Label("@rules_clojure_maven//:org_projectodd_shimdandy_shimdandy_impl")]),
        "_jar_classpath": attr.label_list(doc="classpath for rules-clojure.jar",
                                         cfg="exec",
                                         default = [Label("@rules_clojure_maven//:org_projectodd_shimdandy_shimdandy_impl"),
                                                    Label("@rules_clojure//src/rules_clojure:jar-lib-bootstrap")]),

    },
    provides = [JavaInfo],
    implementation = _clojure_jar_impl,
)

ClojureInfo = provider(
    fields = ["jar_classpath",
              "default_clojure_classpath",
              ])

def _clojure_toolchain(ctx):
    return [platform_common.ToolchainInfo(
        clojure_info = ClojureInfo(
            jar_classpath = ctx.attr.jar_classpath,
            worker_runtime = ctx.attr.compile_classpath,
            clojureworker_binary = ctx.attr.clojureworker_binary))]

clojure_toolchain = rule(
    implementation = _clojure_toolchain,
    attrs = {
        "default_clojure_classpath": attr.label_list(doc="If the target doesn't depend on a clojure.jar, include these targets",
                                                     default=["@rules_clojure_maven//:org_clojure_clojure",
                                                              "@rules_clojure_maven//:org_clojure_spec_alpha",
                                                              "@rules_clojure_maven//:org_clojure_core_specs_alpha"])})

def clojure_binary(name, **kwargs):
    deps = kwargs.pop("deps", [])
    runtime_deps = kwargs.pop("runtime_deps", [])

    native.java_binary(name=name,
                       runtime_deps = deps + runtime_deps,
                       **kwargs)

def clojure_repl(name, deps=[], ns=None, **kwargs):
    args = []

    if ns:
        args.extend(["-e", """\"(require '[{ns}]) (in-ns '{ns})\"""".format(ns = ns)])

    args.extend(["-e", "(clojure.main/repl)"])

    native.java_binary(name=name,
                       runtime_deps=deps,
                       jvm_flags=["-Dclojure.main.report=stderr"],
                       main_class = "clojure.main",
                       args = args,
                       **kwargs)

def clojure_test(name, *, test_ns, deps=[], runtime_deps=[], **kwargs):
    # ideally the library name and the bin name would be the same. They can't be.
    # clojure src files would like to depend on `foo_test`, so mangle the test binary, not the src jar name

    native.java_test(name=name,
                     runtime_deps = deps + runtime_deps + ["@rules_clojure//src/rules_clojure:testrunner"],
                     use_testrunner = False,
                     main_class="rules_clojure.testrunner",
                     args = [test_ns],
                     **kwargs)

def cljs_impl(ctx):

    runfiles = ctx.runfiles(files=ctx.outputs.outs)

    inputs = ctx.files.data + ctx.files.compile_opts_files

    arguments = ["-m", "cljs.main"]
    if len(ctx.files.compile_opts_files) > 0:
        arguments += ["-co", " ".join([f.path for f in ctx.files.compile_opts_files])]

    if len(ctx.attr.compile_opts_strs) > 0:
        arguments += ["-co"] + [ctx.expand_make_variables("compile_opt_strs", s, ctx.var) for s in ctx.attr.compile_opts_strs]

    arguments += ["--compile"]

    env = {k: ctx.expand_make_variables("env", v, ctx.var) for k,v in ctx.attr.env.items()}

    ctx.actions.run(executable=ctx.executable.clj_binary.path,
                    arguments= arguments,
                    inputs=inputs,
                    env=env,
                    tools=[ctx.executable.clj_binary],
                    outputs=ctx.outputs.outs)

    return DefaultInfo(runfiles=runfiles)

_cljs_library = rule(
    attrs = {"data": attr.label_list(default=[], allow_files=True),
             "compile_opts_files": attr.label_list(allow_files=True, default=[]),
             "compile_opts_strs": attr.string_list(default=[]),
             "clj_binary": attr.label(executable=True, cfg="exec"),
             "env": attr.string_dict(default={}),
             "outs": attr.output_list()},
    provides = [],
    implementation = cljs_impl)

def cljs_library(name, deps=[],**kwargs):
    clj_binary="%s_clj_binary" % name
    native.java_binary(name=clj_binary,
                       main_class = "clojure.main",
                       jvm_flags=["-Dclojure.main.report=stderr"],
                       runtime_deps=deps,
                       data=kwargs.get("data",[]))

    _cljs_library(name=name,
                  clj_binary=clj_binary,
                  **kwargs)

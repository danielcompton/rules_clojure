load(":rules.bzl", "clojure_repl")

package(default_visibility = ["//visibility:public"])

exports_files(["deps.edn"])

java_binary(name="repl",
            main_class="clojure.main",
            args=["-r"],
            runtime_deps=["//src/rules_clojure:worker-lib",
                          "//test/rules_clojure:worker"])

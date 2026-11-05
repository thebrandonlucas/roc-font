# Development environment and named tasks for roc-font, realised by Kai
# without Nix (roc-automation's pure-package guide).
#
#     kai run check          # everything a pull request must pass
#     kai run check -- --only fmt,test
#     kai run examples       # build and run examples/, compare with tests/examples.json
#     kai run docs           # the manual as a site, Markdown and PDF in .docs-out/
#     kai update             # refresh .kai/lock.json after changing a download
#
# The package compiler is the bare `roc` on PATH, never a fetched program:
# the latest Roc nightly, as in CI (nothing pins it; scripts/all_tests.py's
# compiler step reports which one ran). Put it first on PATH when another
# `roc` would come first: Kai reads ROC as the compiler that evaluates this
# file. The checks are Python 3 scripts using the standard library only, so
# no tooling compiler is fetched.
app [kaifile] {
	pf: platform "https://github.com/thebrandonlucas/kai/releases/download/v0.0.11/65bk6qdahqxn1mm6LR6Hkyw8dSdoeRZGwjNSuiPfvguP.tar.zst",
	std: "https://github.com/thebrandonlucas/kai/releases/download/v0.0.11/std-6Jw5GxNCFkpnvBbnFmQg4KAVEn5bAfEveSZfDSzTDs42.tar.zst",
}

import std.Std

systems = ["x86_64-linux", "aarch64-linux", "aarch64-darwin"]

## A released file for each system this project declares, named by the system.
per_system = |prefix|
	systems.map(|system| { system, url: "${prefix}${system.to_str()}", mirrors: [], program: File })

kaifile = Std.kaifile([
	Name("roc-font"),
	Systems(systems),
	# The released documentation renderer; its bytes are pinned in .kai/lock.json.
	FetchLocked("roc-docs", per_system("https://github.com/lukewilliamboswell/roc-automation/releases/download/tools-0.2.0/roc-docs-")),
	Environment("docs", [Tools(["roc-docs#roc-docs"]), Expect(["realpath", "sh"])]),
	# The package compiler and Python for the check scripts come from the machine.
	Environment("package", [Expect(["roc", "python3", "git"])]),
	# Every check, in order: fmt, check, tests (dev backend), fuzz
	# smoke, conformance replay, allocation ratchet, API docs, bundle and
	# whitespace. Extra arguments go to scripts/all_tests.py (--only, --skip, --list).
	Task("check", [Use("package"), Description("Everything a pull request must pass"), Run(["python3", "scripts/all_tests.py"])]),
	# The unit and API tests alone, on the dev backend.
	Task("test", [Use("package"), Description("The unit and API tests alone, on the dev backend"), Run(["python3", "scripts/all_tests.py", "--only", "compiler,test"])]),
	# Build every fuzz target natively and replay its seeds briefly.
	Task("fuzz-smoke", [Use("package"), Description("Build every fuzz target and replay its seeds briefly"), Run(["python3", "scripts/run_fuzz.py", "smoke"])]),
	# Replay the recorded HarfBuzz, Chrome and reading oracle results.
	Task("conformance", [Use("package"), Description("Replay the recorded HarfBuzz, Chrome and reading oracle results"), Run(["python3", "scripts/conformance.py"])]),
	# Build and run every example under examples/ and compare its output with
	# tests/examples.json. After an intended change: kai run examples -- --update
	Task("examples", [Use("package"), Description("Build and run examples/, compare with tests/examples.json"), Run(["python3", "scripts/examples.py", "check"])]),
	# Timing smoke run against the comparison implementations that are present.
	Task("bench-quick", [Use("package"), Description("Timing smoke run against the comparison implementations present"), Run(["python3", "scripts/bench.py", "--quick"])]),
	# The manual: docs/index.adoc rendered as a site, static Markdown and a PDF.
	Task("docs", [Use("docs"), Description("The manual as a site, Markdown and PDF in .docs-out/"), Run(["roc-docs", "build", "--workspace", ".", "--pdf-filename", "roc-font.pdf"])]),
	# The renderer's real path, for actions/blueprint-tool and actions/build-docs.
	Task("docs-path", [Use("docs"), Run(["sh", "-c", "realpath \"$(command -v roc-docs)\""])]),
])

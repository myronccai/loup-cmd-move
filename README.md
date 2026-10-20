# loup-cmd-move

The Windows `move` command recreated in [Loup](https://code-craft.ai/references/loup):
move files and rename directories, with cmd's wildcards, `\` paths,
overwrite question, messages and ERRORLEVELs, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It uses the shared
Windows code in [`source/win/`](source/win/) (switch parser, wildcard
matcher, path helpers, messages), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type).

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                     # native binary: build/move
make ci                        # check, unit tests, build, end-to-end tests
make run ARGS="a.txt b.txt"    # run from source with loup run
```

Quote operands that contain `\`, `*` or `?` so that the Linux shell passes
them through: cmd does not expand wildcards, the command does.

```text
$ build/move 'demo\app.log' 'demo\archive\'
        1 file(s) moved.
$ build/move 'demo\*.txt' 'demo\all.txt'
Cannot move multiple files to a single file.
$ build/move 'demo\report*.txt' 'demo\archive'
\home\myron\repos\ccai-examples\loup-cmd-move\build\demo\report1.txt
\home\myron\repos\ccai-examples\loup-cmd-move\build\demo\report2.txt
Overwrite \home\myron\repos\ccai-examples\loup-cmd-move\build\demo\archive\report2.txt? (Yes/No/All): n
        1 file(s) moved.
$ build/move /Y 'demo\report2.txt' 'demo\archive'
        1 file(s) moved.
$ build/move 'demo\old' 'demo\attic'
        1 dir(s) moved.
$ build/move 'demo\missing.txt' demo; echo "ERRORLEVEL $?"
The system cannot find the file specified.
ERRORLEVEL 1
$ build/move --version
move (loup-cmd-move) 0.1.0
```

`move SOURCE DESTINATION`:

- SOURCE is a file, a pattern with `*` and `?` in its last component
  (matching files only, Windows rules, any case), or a directory.
- DESTINATION is an existing directory (the files keep their names) or a new
  name. A pattern may only go to a directory, unless it matches one file.
- A directory is renamed, or moved into DESTINATION when that is an
  existing directory.
- With a pattern, each file's full path is printed as it is moved. The last
  line counts what was moved: `N file(s) moved.` or `1 dir(s) moved.`
- Before replacing an existing file, move asks
  `Overwrite PATH? (Yes/No/All):` and reads one line of standard input (`y`,
  `n` or `a`, in any case; anything else asks again; the end of input means
  no). `/Y` never asks, `/-Y` always asks, and without either move asks
  unless the `COPYCMD` environment variable contains `/Y`.

Files move with a rename; when that fails (another file system), move
copies the file, checks the copy's size and removes the original.

Switches start with `/` or `-` in any case (`/y`, `-Y`). A `/X` that is not
`/Y` or `/-Y` is a path (`move /tmp/a.txt .`), and `--` ends switch
parsing. `/?` prints a short help; `--help` and `--version` work as the only
argument.

Exit status (ERRORLEVEL): `0` when nothing failed (also when you answered
no), `1` for a missing source or target directory, a usage error, or a file
that could not be moved.

## Differences from the original

- Only `SOURCE DESTINATION`: the comma-separated source list
  (`a.txt,b.txt`) is not supported.
- The overwrite answer is a whole line (Enter needed); cmd reacts to the key
  press. When standard input is not a terminal, the answer is echoed after
  the question so that the output reads as on screen. Without `/Y`, move
  asks even inside scripts (cmd does not ask in batch files); set
  `COPYCMD=/Y` or pass `/Y` in scripts.
- Paths are printed from `$PWD` (or `pwd`), without a drive letter
  (`\home\me\a.txt`).
- A pattern matches files only; a pattern destination (`move *.txt *.bak`)
  is refused with `The filename, directory name, or volume label syntax is
  incorrect.` (use loup-cmd-ren for that).
- Names are case-sensitive on Linux for literal operands; patterns ignore
  case.
- Errors cmd reports with other wording (sharing violations, moving a
  directory into itself) are `Access is denied.`
- Moving a file onto itself counts as moved and changes nothing.
- `/?` prints a short help text of this recreation, not Windows' own.
  Messages end with LF, not CRLF.

## Layout

```text
source/main.loup               # entry point
source/appinfo.loup            # name, version, exit statuses
source/cli/args.loup           # /Y and /-Y via win.switches; COPYCMD
source/cli/usage.loup          # /? and --version text
source/cli/app.loup            # run(): parse, dispatch, exit status
source/commands/move.loup      # plan_move(), move_file() (rename, copy fallback), run_move()
source/commands/prompt.loup    # the Overwrite question, one line of stdin at a time
source/commands/cwd.loup       # absolute paths for messages ($PWD or pwd)
source/win/                    # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup              # unit tests (make test)
tests/e2e.sh                   # end-to-end tests of build/move (make e2e)
specs/move/                    # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

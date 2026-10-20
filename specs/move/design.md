# Design: move

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them with
the shared switch parser, handles `/?` and `--version`, and calls
`commands.move.run_move`. `run_move` checks the operand count, asks
`plan_move` for a plan (a list of steps, or one error message), then carries
the steps out, asking before overwriting, and prints the summary.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (0 and 1) |
| `source/cli/args.loup` | `Options`, `move_switches()`, `copycmd_confirm`, `should_ask`, `parse_args` |
| `source/cli/usage.loup` | `usage()` (a short help text), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, exceptions to status 1 |
| `source/commands/move.loup` | `Step`, `Plan`, `plan_move`, `move_file`, `copy_then_remove`, `move_dir`, `summary_line`, `run_move` |
| `source/commands/prompt.loup` | `read_line`, `stdin_is_terminal`, `parse_answer`, `overwrite_question`, `ask_overwrite` |
| `source/commands/cwd.loup` | `normalize_absolute`, `absolute_path`, `current_dir` |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

### Planning

`plan_move(source, dest, cwd)` refuses wildcards in a directory component
or in the destination, expands a wildcard source with
`win.wildcard.expand(..., MATCH_FILES)`, and otherwise classifies the
literal source (directory, file, or missing: file or path message). An
existing destination directory gives one step per source into it; anything
else is a new name, which needs one source, an existing parent and no
trailing separator. A directory may not go onto a file, nor into itself
(compared as absolute, normalized paths).

### Moving

Files: `runtime.fs().rename` (not `io.fs.rename`, which aborts natively),
then a check on disk, since native builds fail silently and Stage0 throws
(both handled). If the source is still there, `copy_then_remove` copies,
compares sizes and removes the source, undoing the copy if the source
cannot be removed. Directories are only renamed, as on Windows.

### Asking

Loup 1.26.0 reads standard input only whole (constraint T2). `read_line`
runs `sh -c 'IFS= read -r line; ...'`: the child inherits standard input
and its `read` takes one line and nothing more, so successive questions get
successive lines from a pipe or the terminal. `test -t 0` tells whether
standard input is a terminal; when it is not, the answer is echoed.

## Differences from the original

- No comma-separated source lists.
- The answer needs Enter; move asks inside scripts too unless `/Y` or
  `COPYCMD=/Y`; non-terminal answers are echoed.
- No drive letters in printed paths; a pattern destination is refused.
- Other failure wordings become `Access is denied.`
- `/?` prints this recreation's own short help text.

## Error handling

Plan errors are printed alone and give status 1. A step that fails prints
`Access is denied.`, the remaining steps go on, and the status is 1.
Declining an overwrite is not an error. An unexpected exception is printed
on standard error and gives status 1.

## Testing

- `tests/args_test.loup`: `/Y`, `/-Y`, last one wins, `COPYCMD`,
  `should_ask`, help and version.
- `tests/move_test.loup`: plans (into, rename, wildcards, directories,
  every error), `move_file`, `move_dir`, `copy_then_remove`, the summary.
- `tests/prompt_test.loup`, `tests/cwd_test.loup`: answers, question text,
  absolute paths.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: the native binary; every case starts from a fresh tree
  under `$TMP` and checks the tree afterwards (stdin answers from files).

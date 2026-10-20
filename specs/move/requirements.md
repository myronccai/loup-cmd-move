# Requirements: move

## Introduction

`move` is the cmd.exe built-in that moves files and renames directories.
This repository recreates it in Loup for Linux, keeping Windows' operand
syntax (`\` separators, `*` and `?` expanded by the command), the overwrite
question, messages and ERRORLEVELs. It uses the shared Windows code in
`source/win/` (copied from loup-cmd-type).

## Requirements

### Requirement 1: Moving files

**User Story:** As a cmd user, I want to move files into a directory or to a
new name.

#### Acceptance Criteria

1. WHEN the destination is an existing directory, THE program SHALL move the
   source file into it under the same name.
2. WHEN the destination does not exist and its parent directory does, THE
   program SHALL move (rename) the file to that name.
3. WHEN the source's last component has `*` or `?`, THE program SHALL move
   every matching file (not directories), print each one's absolute path
   with `\` before moving it, and refuse several files to one file name with
   `Cannot move multiple files to a single file.`
4. THE program SHALL end with `%9d file(s) moved.`
5. WHEN a rename fails, THE program SHALL copy the file, check the copy's
   size and remove the source; if that fails too, it SHALL keep the source
   and print `Access is denied.`

### Requirement 2: Directories

**User Story:** As a cmd user, I want to rename or move a directory.

#### Acceptance Criteria

1. WHEN the source is a directory and the destination does not exist, THE
   program SHALL rename it; WHEN the destination is a directory, THE program
   SHALL move the source into it. It SHALL print `        1 dir(s) moved.`
2. WHEN the destination is a file, THE program SHALL print
   `Cannot create a file when that file already exists.`
3. WHEN the destination is the directory itself or inside it, THE program
   SHALL print `Access is denied.` and change nothing.

### Requirement 3: Overwriting

**User Story:** As a cmd user, I want to be asked before a file is replaced,
unless I say otherwise.

#### Acceptance Criteria

1. WHEN a destination file exists and asking is on, THE program SHALL print
   `Overwrite PATH? (Yes/No/All): ` and read one line from standard input:
   Yes replaces, No skips, All replaces this and every later file without
   asking; anything else asks again; the end of input means No.
2. `/Y` SHALL turn asking off and `/-Y` on; the last one given wins. Without
   either, asking SHALL be on unless `COPYCMD` contains `/Y` (and off with
   `/-Y` there).
3. WHEN standard input is not a terminal, THE program SHALL echo the answer
   after the question.

### Requirement 4: Errors and switches

**User Story:** As a script author, I want Windows' messages and
ERRORLEVELs.

#### Acceptance Criteria

1. WHEN there are not exactly two operands, THE program SHALL print
   `The syntax of the command is incorrect.` and exit 1.
2. WHEN the source does not exist (or no file matches), THE program SHALL
   print `The system cannot find the file specified.`; WHEN its directory
   or the destination's directory does not exist,
   `The system cannot find the path specified.`; exit 1.
3. WHEN a wildcard appears in a directory component of the source, or in
   the destination, THE program SHALL print `The filename, directory name,
   or volume label syntax is incorrect.` and exit 1.
4. THE program SHALL exit 1 if any file could not be moved, else 0.
5. `/?` SHALL print a short help text and exit 0; `--help` and `--version`
   alone SHALL print the help and `move (loup-cmd-move) 0.1.0`. A `/X` other
   than `/Y`, `/-Y` SHALL be an operand.

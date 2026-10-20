#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. Every case runs in a fresh fixture tree under $TMP, and
# the tree is checked afterwards: move only ever touches paths under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# The fixture tree, rebuilt before every case.
W="$TMP/w"
reset() {
    cd "$TMP" && rm -rf "$W"
    mkdir -p "$W/sub" "$W/dirA/inner"
    printf 'alpha\n' > "$W/a.txt"
    printf 'bravo\n' > "$W/b.txt"
    printf 'charlie\n' > "$W/c.log"
    printf 'old b\n' > "$W/sub/b.txt"
    printf 'x\n' > "$W/dirA/inner/x.txt"
    cd "$W"
}

# The tree as one line per entry: `dir/` or `file=content`.
state() {
    (cd "$W" && find . -mindepth 1 | LC_ALL=C sort | while read -r p; do
        if [ -d "$p" ]; then echo "${p#./}/"; else echo "${p#./}=$(cat "$p")"; fi
    done)
}

# check_state NAME EXPECTED: the tree after the last case.
check_state() {
    local got
    got=$(state)
    if [ "$got" = "$2" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $1 (tree)"
        diff <(echo "$2") <(echo "$got") | sed 's/^/    /'
    fi
}

START=$'a.txt=alpha\nb.txt=bravo\nc.log=charlie\ndirA/\ndirA/inner/\ndirA/inner/x.txt=x\nsub/\nsub/b.txt=old b'
unset COPYCMD
WD=${W//\//\\}
one=$'        1 file(s) moved.\n'
nf=$'The system cannot find the file specified.\n'
np=$'The system cannot find the path specified.\n'

# Help and version.
reset
"$BIN" '/?' > "$TMP/help" 2>&1
if [ "$(head -1 "$TMP/help")" = 'Move files to another directory or name, or rename a directory.' ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1)); echo "FAIL: /? help"
fi
check      "--version"          0 $'move (loup-cmd-move) 0.1.0\n' --version

# Moving one file.
reset; check_both "into a directory" 0 "$one" ''               a.txt sub
check_state "into a directory" $'b.txt=bravo\nc.log=charlie\ndirA/\ndirA/inner/\ndirA/inner/x.txt=x\nsub/\nsub/a.txt=alpha\nsub/b.txt=old b'
reset; check "trailing backslash" 0 "$one"                      a.txt 'sub\'
check_state "trailing backslash" $'b.txt=bravo\nc.log=charlie\ndirA/\ndirA/inner/\ndirA/inner/x.txt=x\nsub/\nsub/a.txt=alpha\nsub/b.txt=old b'
reset; check "rename"           0 "$one"                        a.txt z.txt
check_state "rename" $'b.txt=bravo\nc.log=charlie\ndirA/\ndirA/inner/\ndirA/inner/x.txt=x\nsub/\nsub/b.txt=old b\nz.txt=alpha'
reset; check "move and rename"  0 "$one"                        'c.log' 'sub\new.log'
check_state "move and rename" $'a.txt=alpha\nb.txt=bravo\ndirA/\ndirA/inner/\ndirA/inner/x.txt=x\nsub/\nsub/b.txt=old b\nsub/new.log=charlie'
reset; check "absolute paths"   0 "$one"                        "$W/c.log" "$W/sub"
check_state "absolute paths" $'a.txt=alpha\nb.txt=bravo\ndirA/\ndirA/inner/\ndirA/inner/x.txt=x\nsub/\nsub/b.txt=old b\nsub/c.log=charlie'
reset; check "onto itself"      0 "$one"                        a.txt .
check_state "onto itself" "$START"

# Wildcards: each file is listed with its full path.
reset; check_both "wildcard"    0 "$WD\\c.log
$one" ''                                                        '*.LOG' sub
check_state "wildcard" $'a.txt=alpha\nb.txt=bravo\ndirA/\ndirA/inner/\ndirA/inner/x.txt=x\nsub/\nsub/b.txt=old b\nsub/c.log=charlie'
reset; check "wildcard, one match renames" 0 "$WD\\c.log
$one"                                                           '*.log' renamed.log
check_state "wildcard, one match renames" $'a.txt=alpha\nb.txt=bravo\ndirA/\ndirA/inner/\ndirA/inner/x.txt=x\nrenamed.log=charlie\nsub/\nsub/b.txt=old b'

# Overwriting: move asks unless /Y (or COPYCMD=/Y); the answer comes from stdin.
printf 'y\n' > "$TMP/yes"; printf 'n\n' > "$TMP/no"; printf 'maybe\nY\n' > "$TMP/retry"; printf 'all\n' > "$TMP/all"
ask="Overwrite $WD\\sub\\b.txt? (Yes/No/All): "
reset; IN="$TMP/yes" check "answer yes" 0 "${ask}y
$one"                                                           b.txt sub
check_state "answer yes" $'a.txt=alpha\nc.log=charlie\ndirA/\ndirA/inner/\ndirA/inner/x.txt=x\nsub/\nsub/b.txt=bravo'
reset; IN="$TMP/no" check "answer no" 0 "${ask}n
        0 file(s) moved.
"                                                               b.txt sub
check_state "answer no" "$START"
reset; IN="$TMP/retry" check "asks again" 0 "${ask}maybe
${ask}Y
$one"                                                           b.txt sub
reset; check "end of input is no" 0 "${ask}
        0 file(s) moved.
"                                                               b.txt sub
check_state "end of input is no" "$START"
reset; check "/Y"               0 "$one"                        /Y b.txt sub
check_state "/Y" $'a.txt=alpha\nc.log=charlie\ndirA/\ndirA/inner/\ndirA/inner/x.txt=x\nsub/\nsub/b.txt=bravo'
reset; COPYCMD=/Y check "COPYCMD=/Y" 0 "$one"                   b.txt sub
reset; IN="$TMP/no" COPYCMD=/Y check "/-Y beats COPYCMD" 0 "${ask}n
        0 file(s) moved.
"                                                               /-Y b.txt sub
reset; printf 'old a\n' > sub/a.txt
IN="$TMP/all" check "answer all" 0 "$WD\\a.txt
Overwrite $WD\\sub\\a.txt? (Yes/No/All): all
$WD\\b.txt
        2 file(s) moved.
"                                                               '*.txt' sub
check_state "answer all" $'c.log=charlie\ndirA/\ndirA/inner/\ndirA/inner/x.txt=x\nsub/\nsub/a.txt=alpha\nsub/b.txt=bravo'

# Directories.
dmoved=$'        1 dir(s) moved.\n'
reset; check "rename a directory" 0 "$dmoved"                   dirA dirB
check_state "rename a directory" $'a.txt=alpha\nb.txt=bravo\nc.log=charlie\ndirB/\ndirB/inner/\ndirB/inner/x.txt=x\nsub/\nsub/b.txt=old b'
reset; check "directory into a directory" 0 "$dmoved"           'dirA\' sub
check_state "directory into a directory" $'a.txt=alpha\nb.txt=bravo\nc.log=charlie\nsub/\nsub/b.txt=old b\nsub/dirA/\nsub/dirA/inner/\nsub/dirA/inner/x.txt=x'
reset; check_both "directory into itself" 1 '' $'Access is denied.\n' dirA 'dirA\inner'
check_state "directory into itself" "$START"
reset; check_both "directory onto a file" 1 '' \
    $'Cannot create a file when that file already exists.\n'    dirA a.txt
reset; check_both "wildcards skip directories" 1 '' "$nf"       'dir*' sub

# Errors (ERRORLEVEL 1); nothing changes.
reset; check_both "missing file"     1 '' "$nf"                 nope.txt sub
reset; check_both "missing directory" 1 '' "$np"                'nodir\a.txt' sub
reset; check_both "no match"         1 '' "$nf"                 '*.none' sub
reset; check_both "missing target directory" 1 '' "$np"         a.txt 'nodir\a.txt'
reset; check_both "target directory with separator" 1 '' "$np"  a.txt 'newdir\'
reset; check_both "many files to one" 1 '' \
    $'Cannot move multiple files to a single file.\n'           '*.txt' one.txt
reset; check_both "wildcard in directory" 1 '' \
    $'The filename, directory name, or volume label syntax is incorrect.\n' 's*\b.txt' .
reset; check_both "wildcard destination" 1 '' \
    $'The filename, directory name, or volume label syntax is incorrect.\n' a.txt '*.bak'
reset; check_both "one operand"      1 '' $'The syntax of the command is incorrect.\n' a.txt
reset; check_both "three operands"   1 '' $'The syntax of the command is incorrect.\n' a.txt b.txt sub
reset; check_both "unknown switch is a path" 1 '' "$nf"         /z sub
check_state "errors change nothing" "$START"

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

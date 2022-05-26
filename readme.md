a simple file browser runs in terminal


ref:
* https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
* https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
* https://www.kernel.org/doc/html/latest/input/input.html

concepts:
* posix terminal interface
* terminfo
* character device
* tty: controlling terminal of a process, character file
    * /dev/tty /proc/self/fd/1
* csi: control sequence introducer
    * `\x1B[`

naming convention
* enum: snake\_case
* union: snake\_case

goals/limits:
* runs on linux only
* each displayed item ends with a regular file
* configurable mime-opener
* no async
* no filesystem modification: rm, mv ... (except trash)
* configurable color for basename
* sort by directory, then mtime or size or nature

todo:
* ~~line overflow~~
* the dir of trash should respect the partition of file to be deleted

a simple video files browser runs in terminal

## features
* each displayed item is a video file
* trash file into /{mount-point}/{trash-dir}
* shuffle files

## limits
* runs on linux only
* uses mpv to play videos
* treats files which ends with .mp4, .mkv as video
* no filesystem modification: rm, mv ... (except trash)

## build
* zig 0.10.0
* `$ zig build -Drelease-safe`

todo:
* [ ] ~~configurable mime-opener~~
* [ ] ~~configurable color for basename~~
* [ ] sort by directory, then mtime or size or nature

a simple file browser runs in terminal

limits:
* runs on linux only
* uses mpv to play videos
* considers a file which ends with .mp4, .mkv is video file

features:
* each displayed item ends with a regular file
* no filesystem modification: rm, mv ... (except trash)
* trash file into /{mount-point}/{trash-dir}
* shuffle files

todo:
* configurable mime-opener
* configurable color for basename
* sort by directory, then mtime or size or nature

# ExifAudio.yazi

Preview audio metadata on [yazi](https://github.com/sxyazi/yazi). To install, copy the file init.lua inside `~/.config/yazi/plugins/exifaudio.yazi/` if on Linux or at `C:\Users\USERNAME\AppData\Roaming\yazi\config\plugins\exifaudio.yazi` if on Windows. Then, add this to your `yazi.toml` config:

```toml
append_previewers = [
{ mime = "audio/*", exec = "exifaudio" },
]
```

Make sure you have [exiftool](https://exiftool.org/) installed, and can be found in your `PATH`.

## Preview

TBA

## Thanks
Thanks to [sxyazi](https://github.com/sxyazi) for the PDF previewer code, on which this previewer is based on.

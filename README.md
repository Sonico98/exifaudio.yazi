# exifaudio.yazi

Preview audio metadata and cover on [Yazi](https://github.com/sxyazi/yazi).

![image](https://github.com/Sonico98/exifaudio.yazi/assets/61394886/53c1492c-9f05-4c80-a4e7-94fb36f35ca9)

## Installation

```sh
# Linux/macOS
git clone https://github.com/Sonico98/exifaudio.yazi.git ~/.config/yazi/plugins/exifaudio.yazi

# Windows
git clone https://github.com/Sonico98/exifaudio.yazi.git %AppData%\yazi\config\plugins\exifaudio.yazi
```

## Usage

Add this to your `yazi.toml`:

```toml
[[plugin.prepend_previewers]]
mime = "audio/*"
exec = "exifaudio"
```

Make sure you have [exiftool](https://exiftool.org/) installed and in your `PATH`.

## Thanks

Thanks to [sxyazi](https://github.com/sxyazi) for the PDF previewer code, on which this previewer is based on.

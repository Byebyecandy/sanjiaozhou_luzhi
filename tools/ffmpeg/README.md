# FFmpeg

The packaged app expects:

```text
tools/ffmpeg/ffmpeg.exe
tools/ffmpeg/ffprobe.exe
```

The local release ZIP includes these binaries. They are not committed to Git because each binary is larger than GitHub's normal file-size limit.

To rebuild the package from a fresh checkout, place Windows FFmpeg binaries here before running:

```powershell
.\packaging\Build-Package.ps1 -Version 1.0.0
```

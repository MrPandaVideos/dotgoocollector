# Goo Collector

Simple Windows GUI app that scans a **Source** folder for `.goo` and/or `.gcode` files and copies them to a **Destination** you pick (typically a thumb drive).

Runs entirely on your PC — no install, no account, no network calls.

## Download

1. On GitHub, click **Code → Download ZIP**.
2. Unzip — **`GooCollector.exe`** is in the root folder.
3. Double-click **`GooCollector.exe`**.

Windows SmartScreen may warn that the app is unsigned. Choose **More info → Run anyway** if you trust this repository.

## How to use

1. **Source** → Browse to the drive or folder to scan.
2. **Destination** → Browse to your thumb drive (or any folder).
3. **File type** → `.goo`, `.gcode`, or both.
4. **1. Scan for files**
5. **2. Copy to destination**

Optional: leave **Keep folder structure** checked so same-named files from different folders don’t collide.

## Privacy

- Everything stays on your machine.
- No telemetry, analytics, or internet access.
- Existing files at the destination are skipped (not overwritten).

## Rebuild from source

Requires [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) (Windows target):

```bat
cd GooCollector
Publish-Exe.bat
```

Writes `GooCollector.exe` to the repo root and to `GooCollector\dist\`.

There is also a zero-install PowerShell GUI: `GooCollector\Run-GooCollector.bat`.

## Notes

- Scanning a whole drive (for example `C:\`) can take a while; inaccessible/system folders are skipped.
- Don’t choose a Destination inside the Source path.
- Cancel is available during long scans or copies.

## License

MIT — see [LICENSE](LICENSE).

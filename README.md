# Goo Collector

Windows app that scans a drive (or folder) for `.goo` files and copies them to a destination you choose — typically a thumb drive.

## Quick start (no install)

On Windows:

1. Plug in your thumb drive.
2. Double-click `GooCollector/Run-GooCollector.bat`.
3. Pick a **source drive** (or Browse to a folder).
4. Pick a **destination** (your thumb drive folder).
5. Click **Scan for .goo files**.
6. Click **Copy to destination**.

That launcher uses built-in PowerShell + WinForms. Nothing else to install.

## Options

| Option | What it does |
| --- | --- |
| Extension | Defaults to `.goo`; change if you need another type |
| Keep folder structure | Recreates the source folders under the destination |
| Overwrite existing files | Replaces same-named files already on the destination |

Inaccessible system folders are skipped. You can cancel a long scan or copy at any time.

## Build the .NET desktop app (optional)

If you prefer a compiled Windows EXE:

```bat
cd GooCollector
dotnet build -c Release
```

Requires [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) on Windows.

Run:

```bat
dotnet run --project GooCollector.csproj -c Release
```

Or launch the built EXE from `bin\Release\net8.0-windows\GooCollector.exe`.

## Notes

- Scanning all of `C:\` can take a while and may need Administrator rights for some folders.
- Destination should not be inside the scan source (for example, don’t copy into a folder you’re still scanning).
- “Keep folder structure” is recommended so files with the same name from different folders don’t collide.

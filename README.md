# Goo Collector

Simple Windows GUI app that scans a **Source** folder for `.goo` and/or `.gcode` files and copies them to a **Destination** you pick (typically a thumb drive).

## Download

1. On GitHub, click **Code → Download ZIP** (or download this repo).
2. Unzip the download — **`GooCollector.exe`** is in the root folder.
3. Double-click **`GooCollector.exe`**. No install required.

## How to use

1. Click **Browse…** next to **Source** (or click the Source field) and pick a drive/folder in File Explorer.
2. Click **Browse…** next to **Destination** and pick your thumb drive (or any folder).
3. Choose **File type**: `.goo`, `.gcode`, or both.
4. Click **1. Scan for files**.
5. Click **2. Copy to destination**.

Optional: leave **Keep folder structure** checked so files from different folders don’t overwrite each other.

## Rebuild the .exe yourself

Requires [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0):

```bat
cd GooCollector
Publish-Exe.bat
```

That writes `GooCollector.exe` to this folder’s parent (the repo root) and to `GooCollector/dist/`.

## Notes

- Scanning a whole drive (for example `C:\`) can take a while; some protected folders are skipped automatically.
- Don’t choose a Destination inside the Source folder.
- Existing files at the Destination are skipped (not overwritten).

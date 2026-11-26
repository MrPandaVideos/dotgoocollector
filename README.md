# Goo Collector

Simple Windows GUI app that scans a **Source** folder for `.goo` files and copies them to a **Destination** you pick (typically a thumb drive).

## Download the .exe

Grab the prebuilt Windows app from the release zip:

- [`GooCollector/release/GooCollector-win-x64.zip`](GooCollector/release/GooCollector-win-x64.zip)

Unzip, then double-click **`GooCollector.exe`**. No install required (self-contained).

## How to use

1. Click **Browse…** next to **Source** (or click the Source field) and pick a drive/folder in File Explorer.
2. Click **Browse…** next to **Destination** and pick your thumb drive (or any folder).
3. Click **1. Scan for .goo files**.
4. Click **2. Copy to destination**.

Optional: leave **Keep folder structure** checked so files from different folders don’t overwrite each other.

## Rebuild the .exe yourself

Requires [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0):

```bat
cd GooCollector
Publish-Exe.bat
```

Output: `GooCollector/dist/GooCollector.exe`

## Notes

- Scanning a whole drive (for example `C:\`) can take a while; some protected folders are skipped automatically.
- Don’t choose a Destination inside the Source folder.
- Existing files at the Destination are skipped (not overwritten).

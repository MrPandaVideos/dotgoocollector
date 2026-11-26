# Goo Collector

Simple Windows GUI app that scans a drive (or folder) for `.goo` files and copies them to a destination you choose — typically a thumb drive.

## Download the .exe

Grab the prebuilt Windows app from the release zip:

- [`GooCollector/release/GooCollector-win-x64.zip`](GooCollector/release/GooCollector-win-x64.zip)

Unzip, then double-click **`GooCollector.exe`**. No install required (self-contained).

## How to use

1. Choose a **Scan from** drive (or click **Folder…** for a specific folder).
2. Click **Browse…** under **Copy to** and select your thumb drive.
3. Click **1. Scan for .goo files**.
4. Click **2. Copy to destination**.

Optional: leave **Keep folder structure** checked so files from different folders don’t overwrite each other.

## Rebuild the .exe yourself

Requires [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) on Windows (or any OS that can target `win-x64`):

```bat
cd GooCollector
Publish-Exe.bat
```

Or:

```bat
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -o dist
```

Output: `GooCollector/dist/GooCollector.exe`

## Notes

- Scanning all of `C:\` can take a while; some protected folders are skipped automatically.
- Don’t choose a destination inside the folder you’re scanning.
- Existing files at the destination are skipped (not overwritten).

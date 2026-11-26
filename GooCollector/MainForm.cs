using System.ComponentModel;
using System.Diagnostics;

namespace GooCollector;

public sealed class MainForm : Form
{
    private readonly ComboBox _sourceDrive = new();
    private readonly Button _refreshDrives = new();
    private readonly TextBox _extension = new();
    private readonly Button _browseSource = new();
    private readonly TextBox _customSource = new();
    private readonly Button _destinationBrowse = new();
    private readonly TextBox _destination = new();
    private readonly CheckBox _preserveStructure = new();
    private readonly CheckBox _overwrite = new();
    private readonly Button _scanButton = new();
    private readonly Button _copyButton = new();
    private readonly Button _cancelButton = new();
    private readonly ListView _results = new();
    private readonly Label _status = new();
    private readonly ProgressBar _progress = new();
    private readonly Label _summary = new();

    private CancellationTokenSource? _cts;
    private readonly BindingList<FoundFile> _foundFiles = new();
    private string _activeSourceRoot = string.Empty;

    public MainForm()
    {
        Text = "Goo Collector";
        MinimumSize = new Size(780, 560);
        Size = new Size(900, 640);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 10F);

        BuildLayout();
        WireEvents();
        RefreshDrives();
        UpdateUiState(idle: true);
    }

    private void BuildLayout()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 5,
            Padding = new Padding(16),
        };
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        // Source row
        var sourcePanel = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            ColumnCount = 4,
            RowCount = 2,
            Margin = new Padding(0, 0, 0, 8),
        };
        sourcePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));
        sourcePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        sourcePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 100));
        sourcePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));

        sourcePanel.Controls.Add(new Label
        {
            Text = "Source drive",
            AutoSize = true,
            Anchor = AnchorStyles.Left,
            Margin = new Padding(0, 8, 8, 8),
        }, 0, 0);

        _sourceDrive.DropDownStyle = ComboBoxStyle.DropDownList;
        _sourceDrive.Dock = DockStyle.Fill;
        sourcePanel.Controls.Add(_sourceDrive, 1, 0);

        _refreshDrives.Text = "Refresh";
        _refreshDrives.Dock = DockStyle.Fill;
        sourcePanel.Controls.Add(_refreshDrives, 2, 0);

        _browseSource.Text = "Browse…";
        _browseSource.Dock = DockStyle.Fill;
        sourcePanel.Controls.Add(_browseSource, 3, 0);

        sourcePanel.Controls.Add(new Label
        {
            Text = "Or folder",
            AutoSize = true,
            Anchor = AnchorStyles.Left,
            Margin = new Padding(0, 8, 8, 8),
        }, 0, 1);

        _customSource.ReadOnly = true;
        _customSource.PlaceholderText = "Optional: scan a specific folder instead of a whole drive";
        _customSource.Dock = DockStyle.Fill;
        sourcePanel.SetColumnSpan(_customSource, 3);
        sourcePanel.Controls.Add(_customSource, 1, 1);

        // Destination / options row
        var destPanel = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            ColumnCount = 4,
            RowCount = 2,
            Margin = new Padding(0, 0, 0, 8),
        };
        destPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));
        destPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        destPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));
        destPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 120));

        destPanel.Controls.Add(new Label
        {
            Text = "Destination",
            AutoSize = true,
            Anchor = AnchorStyles.Left,
            Margin = new Padding(0, 8, 8, 8),
        }, 0, 0);

        _destination.ReadOnly = true;
        _destination.PlaceholderText = "Choose where to copy .goo files (e.g. your thumb drive)";
        _destination.Dock = DockStyle.Fill;
        destPanel.Controls.Add(_destination, 1, 0);

        _destinationBrowse.Text = "Browse…";
        _destinationBrowse.Dock = DockStyle.Fill;
        destPanel.Controls.Add(_destinationBrowse, 2, 0);

        var options = new FlowLayoutPanel
        {
            AutoSize = true,
            Dock = DockStyle.Fill,
            WrapContents = false,
        };
        destPanel.SetColumnSpan(options, 4);
        destPanel.Controls.Add(options, 0, 1);

        options.Controls.Add(new Label
        {
            Text = "Extension",
            AutoSize = true,
            Margin = new Padding(0, 8, 8, 0),
        });

        _extension.Text = ".goo";
        _extension.Width = 80;
        _extension.Margin = new Padding(0, 4, 16, 0);
        options.Controls.Add(_extension);

        _preserveStructure.Text = "Keep folder structure";
        _preserveStructure.Checked = true;
        _preserveStructure.AutoSize = true;
        _preserveStructure.Margin = new Padding(0, 6, 16, 0);
        options.Controls.Add(_preserveStructure);

        _overwrite.Text = "Overwrite existing files";
        _overwrite.AutoSize = true;
        _overwrite.Margin = new Padding(0, 6, 16, 0);
        options.Controls.Add(_overwrite);

        // Results list
        _results.Dock = DockStyle.Fill;
        _results.View = View.Details;
        _results.FullRowSelect = true;
        _results.GridLines = true;
        _results.Columns.Add("File", 280);
        _results.Columns.Add("Path", 420);
        _results.Columns.Add("Size", 100);
        _results.VirtualMode = false;

        // Actions
        var actions = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            AutoSize = true,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = false,
            Margin = new Padding(0, 8, 0, 8),
        };

        _scanButton.Text = "Scan for .goo files";
        _scanButton.AutoSize = true;
        _scanButton.Padding = new Padding(12, 4, 12, 4);
        actions.Controls.Add(_scanButton);

        _copyButton.Text = "Copy to destination";
        _copyButton.AutoSize = true;
        _copyButton.Padding = new Padding(12, 4, 12, 4);
        actions.Controls.Add(_copyButton);

        _cancelButton.Text = "Cancel";
        _cancelButton.AutoSize = true;
        _cancelButton.Padding = new Padding(12, 4, 12, 4);
        actions.Controls.Add(_cancelButton);

        _summary.AutoSize = true;
        _summary.Margin = new Padding(16, 10, 0, 0);
        actions.Controls.Add(_summary);

        // Status / progress
        var statusPanel = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            ColumnCount = 1,
            RowCount = 2,
        };
        _progress.Dock = DockStyle.Top;
        _progress.Height = 18;
        _progress.Style = ProgressBarStyle.Continuous;
        _status.AutoSize = true;
        _status.Margin = new Padding(0, 6, 0, 0);
        _status.Text = "Pick a source drive and destination, then scan.";
        statusPanel.Controls.Add(_progress, 0, 0);
        statusPanel.Controls.Add(_status, 0, 1);

        root.Controls.Add(sourcePanel, 0, 0);
        root.Controls.Add(destPanel, 0, 1);
        root.Controls.Add(_results, 0, 2);
        root.Controls.Add(actions, 0, 3);
        root.Controls.Add(statusPanel, 0, 4);

        Controls.Add(root);
    }

    private void WireEvents()
    {
        _refreshDrives.Click += (_, _) => RefreshDrives();
        _browseSource.Click += (_, _) => BrowseSourceFolder();
        _destinationBrowse.Click += (_, _) => BrowseDestination();
        _scanButton.Click += async (_, _) => await ScanAsync();
        _copyButton.Click += async (_, _) => await CopyAsync();
        _cancelButton.Click += (_, _) => _cts?.Cancel();
        _extension.TextChanged += (_, _) =>
        {
            var ext = NormalizeExtension(_extension.Text);
            _scanButton.Text = string.IsNullOrEmpty(ext) ? "Scan" : $"Scan for {ext} files";
        };
    }

    private void RefreshDrives()
    {
        var selected = _sourceDrive.SelectedItem as string;
        _sourceDrive.Items.Clear();

        foreach (var drive in DriveInfo.GetDrives().Where(d => d.IsReady).OrderBy(d => d.Name))
        {
            var label = $"{drive.Name} ({FormatDriveLabel(drive)})";
            _sourceDrive.Items.Add(new DriveItem(drive.RootDirectory.FullName, label));
        }

        if (_sourceDrive.Items.Count == 0)
        {
            _status.Text = "No ready drives found.";
            return;
        }

        if (!string.IsNullOrEmpty(selected))
        {
            for (var i = 0; i < _sourceDrive.Items.Count; i++)
            {
                if (_sourceDrive.Items[i] is DriveItem item && item.Display == selected)
                {
                    _sourceDrive.SelectedIndex = i;
                    return;
                }
            }
        }

        // Prefer C:\ when present
        for (var i = 0; i < _sourceDrive.Items.Count; i++)
        {
            if (_sourceDrive.Items[i] is DriveItem item &&
                item.Root.StartsWith("C:", StringComparison.OrdinalIgnoreCase))
            {
                _sourceDrive.SelectedIndex = i;
                return;
            }
        }

        _sourceDrive.SelectedIndex = 0;
    }

    private static string FormatDriveLabel(DriveInfo drive)
    {
        var name = string.IsNullOrWhiteSpace(drive.VolumeLabel) ? drive.DriveType.ToString() : drive.VolumeLabel;
        try
        {
            return $"{name} — {FormatBytes(drive.TotalSize)}";
        }
        catch
        {
            return name;
        }
    }

    private void BrowseSourceFolder()
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = "Choose a folder to scan for .goo files",
            UseDescriptionForTitle = true,
            ShowNewFolderButton = false,
        };

        if (!string.IsNullOrWhiteSpace(_customSource.Text) && Directory.Exists(_customSource.Text))
        {
            dialog.SelectedPath = _customSource.Text;
        }

        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            _customSource.Text = dialog.SelectedPath;
        }
    }

    private void BrowseDestination()
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = "Choose where to copy the .goo files (for example your thumb drive)",
            UseDescriptionForTitle = true,
            ShowNewFolderButton = true,
        };

        if (!string.IsNullOrWhiteSpace(_destination.Text) && Directory.Exists(_destination.Text))
        {
            dialog.SelectedPath = _destination.Text;
        }

        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            _destination.Text = dialog.SelectedPath;
            UpdateUiState(idle: _cts is null);
        }
    }

    private string ResolveSourceRoot()
    {
        if (!string.IsNullOrWhiteSpace(_customSource.Text))
        {
            return _customSource.Text.Trim();
        }

        if (_sourceDrive.SelectedItem is DriveItem item)
        {
            return item.Root;
        }

        return string.Empty;
    }

    private async Task ScanAsync()
    {
        var source = ResolveSourceRoot();
        if (string.IsNullOrWhiteSpace(source) || !Directory.Exists(source))
        {
            MessageBox.Show(this, "Choose a valid source drive or folder first.", "Goo Collector",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var extension = NormalizeExtension(_extension.Text);
        if (string.IsNullOrEmpty(extension))
        {
            MessageBox.Show(this, "Enter a file extension such as .goo.", "Goo Collector",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        _cts?.Cancel();
        _cts = new CancellationTokenSource();
        var token = _cts.Token;

        _foundFiles.Clear();
        _results.Items.Clear();
        _activeSourceRoot = Path.GetFullPath(source);
        UpdateUiState(idle: false);
        _progress.Style = ProgressBarStyle.Marquee;
        _status.Text = $"Scanning {source} for *{extension} …";
        _summary.Text = string.Empty;

        var found = new List<FoundFile>();
        var sw = Stopwatch.StartNew();

        try
        {
            await Task.Run(() =>
            {
                foreach (var path in EnumerateFilesSafe(source, $"*{extension}", token))
                {
                    token.ThrowIfCancellationRequested();

                    long size = 0;
                    try { size = new FileInfo(path).Length; } catch { /* ignore */ }

                    var file = new FoundFile(path, size);
                    found.Add(file);

                    if (found.Count % 25 == 0 || found.Count == 1)
                    {
                        BeginInvoke(() =>
                        {
                            _status.Text = $"Scanning… found {found.Count} file(s). Last: {path}";
                        });
                    }
                }
            }, token);

            found.Sort((a, b) => string.Compare(a.FullPath, b.FullPath, StringComparison.OrdinalIgnoreCase));
            foreach (var file in found)
            {
                _foundFiles.Add(file);
                _results.Items.Add(new ListViewItem(new[]
                {
                    Path.GetFileName(file.FullPath),
                    file.FullPath,
                    FormatBytes(file.Size),
                }));
            }

            sw.Stop();
            _summary.Text = $"{found.Count} file(s) · {FormatBytes(found.Sum(f => f.Size))} · {sw.Elapsed:mm\\:ss}";
            _status.Text = found.Count == 0
                ? $"No {extension} files found under {source}."
                : $"Scan complete. {found.Count} {extension} file(s) ready to copy.";
        }
        catch (OperationCanceledException)
        {
            _status.Text = "Scan canceled.";
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, $"Scan failed:\n{ex.Message}", "Goo Collector",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            _status.Text = "Scan failed.";
        }
        finally
        {
            _progress.Style = ProgressBarStyle.Continuous;
            _progress.Value = 0;
            _cts = null;
            UpdateUiState(idle: true);
        }
    }

    private async Task CopyAsync()
    {
        if (_foundFiles.Count == 0)
        {
            MessageBox.Show(this, "Scan first so there are files to copy.", "Goo Collector",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        var destination = _destination.Text.Trim();
        if (string.IsNullOrWhiteSpace(destination) || !Directory.Exists(destination))
        {
            MessageBox.Show(this, "Choose a valid destination folder (for example your thumb drive).",
                "Goo Collector", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var sourceRoot = string.IsNullOrEmpty(_activeSourceRoot)
            ? ResolveSourceRoot()
            : _activeSourceRoot;

        if (PathsOverlap(sourceRoot, destination))
        {
            MessageBox.Show(this,
                "Destination is inside the scan source (or the same path). Choose a different destination such as a thumb drive.",
                "Goo Collector", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var confirm = MessageBox.Show(this,
            $"Copy {_foundFiles.Count} file(s) to:\n{destination}\n\nContinue?",
            "Confirm copy", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
        if (confirm != DialogResult.Yes)
        {
            return;
        }

        _cts?.Cancel();
        _cts = new CancellationTokenSource();
        var token = _cts.Token;

        UpdateUiState(idle: false);
        _progress.Style = ProgressBarStyle.Continuous;
        _progress.Minimum = 0;
        _progress.Maximum = Math.Max(1, _foundFiles.Count);
        _progress.Value = 0;

        var preserve = _preserveStructure.Checked;
        var overwrite = _overwrite.Checked;
        var files = _foundFiles.ToList();
        var copied = 0;
        var skipped = 0;
        var failed = 0;

        try
        {
            await Task.Run(() =>
            {
                for (var i = 0; i < files.Count; i++)
                {
                    token.ThrowIfCancellationRequested();
                    var file = files[i];

                    try
                    {
                        var relative = preserve
                            ? GetRelativePathSafe(sourceRoot, file.FullPath)
                            : Path.GetFileName(file.FullPath);

                        // Avoid drive-letter rooted relative paths on Windows
                        relative = relative.TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                        if (relative.Length >= 2 && relative[1] == ':')
                        {
                            relative = relative[2..].TrimStart('\\', '/');
                        }

                        var targetPath = Path.Combine(destination, relative);
                        var targetDir = Path.GetDirectoryName(targetPath);
                        if (!string.IsNullOrEmpty(targetDir))
                        {
                            Directory.CreateDirectory(targetDir);
                        }

                        if (!overwrite && File.Exists(targetPath))
                        {
                            Interlocked.Increment(ref skipped);
                        }
                        else
                        {
                            File.Copy(file.FullPath, targetPath, overwrite);
                            Interlocked.Increment(ref copied);
                        }
                    }
                    catch
                    {
                        Interlocked.Increment(ref failed);
                    }

                    var done = i + 1;
                    BeginInvoke(() =>
                    {
                        _progress.Value = Math.Min(done, _progress.Maximum);
                        _status.Text = $"Copying {done} of {files.Count}: {Path.GetFileName(file.FullPath)}";
                    });
                }
            }, token);

            _status.Text = $"Copy finished. Copied {copied}, skipped {skipped}, failed {failed}.";
            MessageBox.Show(this,
                $"Done.\n\nCopied: {copied}\nSkipped: {skipped}\nFailed: {failed}\n\nDestination:\n{destination}",
                "Goo Collector", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        catch (OperationCanceledException)
        {
            _status.Text = $"Copy canceled. Copied {copied}, skipped {skipped}, failed {failed}.";
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, $"Copy failed:\n{ex.Message}", "Goo Collector",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            _status.Text = "Copy failed.";
        }
        finally
        {
            _cts = null;
            UpdateUiState(idle: true);
        }
    }

    private void UpdateUiState(bool idle)
    {
        _scanButton.Enabled = idle;
        _copyButton.Enabled = idle && _foundFiles.Count > 0 && !string.IsNullOrWhiteSpace(_destination.Text);
        _cancelButton.Enabled = !idle;
        _sourceDrive.Enabled = idle;
        _refreshDrives.Enabled = idle;
        _browseSource.Enabled = idle;
        _destinationBrowse.Enabled = idle;
        _extension.Enabled = idle;
        _preserveStructure.Enabled = idle;
        _overwrite.Enabled = idle;
    }

    private static IEnumerable<string> EnumerateFilesSafe(string root, string pattern, CancellationToken token)
    {
        var pending = new Stack<string>();
        pending.Push(root);

        while (pending.Count > 0)
        {
            token.ThrowIfCancellationRequested();
            var dir = pending.Pop();

            IEnumerable<string> files = Array.Empty<string>();
            try
            {
                files = Directory.EnumerateFiles(dir, pattern, SearchOption.TopDirectoryOnly);
            }
            catch
            {
                // Skip inaccessible directories (system, permissions, etc.)
            }

            foreach (var file in files)
            {
                token.ThrowIfCancellationRequested();
                yield return file;
            }

            IEnumerable<string> subdirs = Array.Empty<string>();
            try
            {
                subdirs = Directory.EnumerateDirectories(dir);
            }
            catch
            {
                // Skip inaccessible directories
            }

            foreach (var sub in subdirs)
            {
                // Skip reparse points / junctions that can loop or leave the drive
                try
                {
                    var attr = File.GetAttributes(sub);
                    if (attr.HasFlag(FileAttributes.ReparsePoint))
                    {
                        continue;
                    }
                }
                catch
                {
                    continue;
                }

                pending.Push(sub);
            }
        }
    }

    private static string NormalizeExtension(string value)
    {
        var ext = (value ?? string.Empty).Trim();
        if (string.IsNullOrEmpty(ext))
        {
            return string.Empty;
        }

        if (!ext.StartsWith('.'))
        {
            ext = "." + ext;
        }

        return ext.ToLowerInvariant();
    }

    private static string GetRelativePathSafe(string root, string fullPath)
    {
        try
        {
            return Path.GetRelativePath(root, fullPath);
        }
        catch
        {
            return Path.GetFileName(fullPath);
        }
    }

    private static bool PathsOverlap(string source, string destination)
    {
        try
        {
            var src = Path.GetFullPath(source)
                .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                + Path.DirectorySeparatorChar;
            var dst = Path.GetFullPath(destination)
                .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                + Path.DirectorySeparatorChar;

            return dst.StartsWith(src, StringComparison.OrdinalIgnoreCase)
                   || src.StartsWith(dst, StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB", "TB"];
        double size = bytes;
        var unit = 0;
        while (size >= 1024 && unit < units.Length - 1)
        {
            size /= 1024;
            unit++;
        }

        return unit == 0 ? $"{bytes} {units[unit]}" : $"{size:0.##} {units[unit]}";
    }

    private sealed record DriveItem(string Root, string Display)
    {
        public override string ToString() => Display;
    }

    private sealed record FoundFile(string FullPath, long Size);
}

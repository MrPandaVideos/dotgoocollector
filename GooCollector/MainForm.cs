using System.Diagnostics;

namespace GooCollector;

public sealed class MainForm : Form
{
    private readonly TextBox _source = new();
    private readonly Button _sourceBrowse = new();
    private readonly TextBox _destination = new();
    private readonly Button _destinationBrowse = new();
    private readonly CheckBox _preserveStructure = new();
    private readonly Button _scanButton = new();
    private readonly Button _copyButton = new();
    private readonly Button _cancelButton = new();
    private readonly ListView _results = new();
    private readonly Label _status = new();
    private readonly ProgressBar _progress = new();
    private readonly Label _summary = new();

    private CancellationTokenSource? _cts;
    private readonly List<FoundFile> _foundFiles = new();
    private string _activeSourceRoot = string.Empty;

    private const string Extension = ".goo";

    public MainForm()
    {
        Text = "Goo Collector";
        MinimumSize = new Size(720, 520);
        Size = new Size(820, 580);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 10F);

        BuildLayout();
        WireEvents();
        UpdateUiState(idle: true);
    }

    private void BuildLayout()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 4,
            Padding = new Padding(16),
        };
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        var settings = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            ColumnCount = 3,
            RowCount = 2,
            Margin = new Padding(0, 0, 0, 12),
        };
        settings.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 100));
        settings.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        settings.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));

        settings.Controls.Add(MakeLabel("Source"), 0, 0);
        _source.ReadOnly = true;
        _source.Cursor = Cursors.Hand;
        _source.PlaceholderText = "Click Browse to pick a drive or folder to scan";
        _source.Dock = DockStyle.Fill;
        settings.Controls.Add(_source, 1, 0);
        _sourceBrowse.Text = "Browse…";
        _sourceBrowse.Dock = DockStyle.Fill;
        settings.Controls.Add(_sourceBrowse, 2, 0);

        settings.Controls.Add(MakeLabel("Destination"), 0, 1);
        _destination.ReadOnly = true;
        _destination.Cursor = Cursors.Hand;
        _destination.PlaceholderText = "Click Browse to pick where to copy (e.g. thumb drive)";
        _destination.Dock = DockStyle.Fill;
        settings.Controls.Add(_destination, 1, 1);
        _destinationBrowse.Text = "Browse…";
        _destinationBrowse.Dock = DockStyle.Fill;
        settings.Controls.Add(_destinationBrowse, 2, 1);

        _results.Dock = DockStyle.Fill;
        _results.View = View.Details;
        _results.FullRowSelect = true;
        _results.GridLines = true;
        _results.Columns.Add("File", 240);
        _results.Columns.Add("Path", 400);
        _results.Columns.Add("Size", 90);

        var actions = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            AutoSize = true,
            WrapContents = false,
            Margin = new Padding(0, 10, 0, 8),
        };

        _scanButton.Text = "1. Scan for .goo files";
        _scanButton.AutoSize = true;
        _scanButton.Padding = new Padding(14, 6, 14, 6);
        actions.Controls.Add(_scanButton);

        _copyButton.Text = "2. Copy to destination";
        _copyButton.AutoSize = true;
        _copyButton.Padding = new Padding(14, 6, 14, 6);
        actions.Controls.Add(_copyButton);

        _cancelButton.Text = "Cancel";
        _cancelButton.AutoSize = true;
        _cancelButton.Padding = new Padding(14, 6, 14, 6);
        actions.Controls.Add(_cancelButton);

        _preserveStructure.Text = "Keep folder structure";
        _preserveStructure.Checked = true;
        _preserveStructure.AutoSize = true;
        _preserveStructure.Margin = new Padding(16, 10, 0, 0);
        actions.Controls.Add(_preserveStructure);

        _summary.AutoSize = true;
        _summary.Margin = new Padding(16, 12, 0, 0);
        actions.Controls.Add(_summary);

        var statusPanel = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            ColumnCount = 1,
            RowCount = 2,
        };
        _progress.Dock = DockStyle.Top;
        _progress.Height = 18;
        _status.AutoSize = true;
        _status.Margin = new Padding(0, 6, 0, 0);
        _status.Text = "Pick a Source folder, pick a Destination folder, then press Scan.";
        statusPanel.Controls.Add(_progress, 0, 0);
        statusPanel.Controls.Add(_status, 0, 1);

        root.Controls.Add(settings, 0, 0);
        root.Controls.Add(_results, 0, 1);
        root.Controls.Add(actions, 0, 2);
        root.Controls.Add(statusPanel, 0, 3);
        Controls.Add(root);
    }

    private static Label MakeLabel(string text) => new()
    {
        Text = text,
        AutoSize = true,
        Anchor = AnchorStyles.Left,
        Margin = new Padding(0, 8, 8, 8),
    };

    private void WireEvents()
    {
        _sourceBrowse.Click += (_, _) => BrowseSource();
        _destinationBrowse.Click += (_, _) => BrowseDestination();
        _source.Click += (_, _) => BrowseSource();
        _destination.Click += (_, _) => BrowseDestination();
        _scanButton.Click += async (_, _) => await ScanAsync();
        _copyButton.Click += async (_, _) => await CopyAsync();
        _cancelButton.Click += (_, _) => _cts?.Cancel();
    }

    private void BrowseSource()
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = "Choose the source drive or folder to scan for .goo files",
            UseDescriptionForTitle = true,
            ShowNewFolderButton = false,
        };

        if (!string.IsNullOrWhiteSpace(_source.Text) && Directory.Exists(_source.Text))
        {
            dialog.SelectedPath = _source.Text;
        }

        if (dialog.ShowDialog(this) == DialogResult.OK)
        {
            _source.Text = dialog.SelectedPath;
            UpdateUiState(idle: _cts is null);
        }
    }

    private void BrowseDestination()
    {
        using var dialog = new FolderBrowserDialog
        {
            Description = "Choose the destination folder (for example your thumb drive)",
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

    private async Task ScanAsync()
    {
        var source = _source.Text.Trim();
        if (string.IsNullOrWhiteSpace(source) || !Directory.Exists(source))
        {
            MessageBox.Show(this, "Pick a Source folder first (Browse…).", "Goo Collector",
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
        _status.Text = $"Scanning {source} for *{Extension} …";
        _summary.Text = string.Empty;

        var found = new List<FoundFile>();
        var sw = Stopwatch.StartNew();

        try
        {
            await Task.Run(() =>
            {
                foreach (var path in EnumerateFilesSafe(source, $"*{Extension}", token))
                {
                    token.ThrowIfCancellationRequested();

                    long size = 0;
                    try { size = new FileInfo(path).Length; } catch { /* ignore */ }

                    found.Add(new FoundFile(path, size));

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
                _results.Items.Add(new ListViewItem([
                    Path.GetFileName(file.FullPath),
                    file.FullPath,
                    FormatBytes(file.Size),
                ]));
            }

            sw.Stop();
            _summary.Text = $"{found.Count} file(s) · {FormatBytes(found.Sum(f => f.Size))} · {sw.Elapsed:mm\\:ss}";
            _status.Text = found.Count == 0
                ? $"No {Extension} files found under {source}."
                : $"Scan complete. {found.Count} {Extension} file(s) ready to copy.";
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
            MessageBox.Show(this, "Pick a Destination folder first (Browse…).",
                "Goo Collector", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var sourceRoot = string.IsNullOrEmpty(_activeSourceRoot)
            ? _source.Text.Trim()
            : _activeSourceRoot;

        if (PathsOverlap(sourceRoot, destination))
        {
            MessageBox.Show(this,
                "Destination is inside the Source (or the same path). Choose a different Destination such as a thumb drive.",
                "Goo Collector", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var confirm = MessageBox.Show(this,
            $"Copy {_foundFiles.Count} .goo file(s) to:\n{destination}\n\nContinue?",
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

                        if (File.Exists(targetPath))
                        {
                            Interlocked.Increment(ref skipped);
                        }
                        else
                        {
                            File.Copy(file.FullPath, targetPath, overwrite: false);
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
                $"Done.\n\nCopied: {copied}\nSkipped (already there): {skipped}\nFailed: {failed}\n\nDestination:\n{destination}",
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
        _scanButton.Enabled = idle && !string.IsNullOrWhiteSpace(_source.Text);
        _copyButton.Enabled = idle
            && _foundFiles.Count > 0
            && !string.IsNullOrWhiteSpace(_destination.Text);
        _cancelButton.Enabled = !idle;
        _sourceBrowse.Enabled = idle;
        _destinationBrowse.Enabled = idle;
        _source.Enabled = idle;
        _destination.Enabled = idle;
        _preserveStructure.Enabled = idle;
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
                // Skip inaccessible directories
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

    private sealed record FoundFile(string FullPath, long Size);
}

# Goo Collector — zero-install Windows GUI (PowerShell + WinForms)
# Double-click Run-GooCollector.bat, or run: powershell -ExecutionPolicy Bypass -File .\Run-GooCollector.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Goo Collector"
$form.Size = New-Object System.Drawing.Size(820, 580)
$form.MinimumSize = New-Object System.Drawing.Size(720, 520)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$script:foundFiles = New-Object System.Collections.Generic.List[string]
$script:activeSourceRoot = ""
$script:cancelRequested = $false
$script:busy = $false

function Format-Bytes([long]$bytes) {
    $units = @("B", "KB", "MB", "GB", "TB")
    $size = [double]$bytes
    $unit = 0
    while ($size -ge 1024 -and $unit -lt ($units.Length - 1)) {
        $size /= 1024
        $unit++
    }
    if ($unit -eq 0) { return "$bytes $($units[$unit])" }
    return ("{0:0.##} {1}" -f $size, $units[$unit])
}

function Get-RelativePathSafe([string]$root, [string]$fullPath) {
    $rootFull = [IO.Path]::GetFullPath($root).TrimEnd('\', '/') + '\'
    $pathFull = [IO.Path]::GetFullPath($fullPath)
    if ($pathFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        return $pathFull.Substring($rootFull.Length)
    }
    return [IO.Path]::GetFileName($fullPath)
}

function Update-UiState {
    $scanButton.Enabled = (-not $script:busy) -and (-not [string]::IsNullOrWhiteSpace($sourceBox.Text))
    $copyButton.Enabled = (-not $script:busy) -and ($script:foundFiles.Count -gt 0) -and (-not [string]::IsNullOrWhiteSpace($destinationBox.Text))
    $cancelButton.Enabled = $script:busy
    $sourceBrowse.Enabled = -not $script:busy
    $destinationBrowse.Enabled = -not $script:busy
    $sourceBox.Enabled = -not $script:busy
    $destinationBox.Enabled = -not $script:busy
    $preserveCheck.Enabled = -not $script:busy
}

function Browse-Source {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choose the source drive or folder to scan for .goo files"
    $dialog.ShowNewFolderButton = $false
    if (-not [string]::IsNullOrWhiteSpace($sourceBox.Text) -and (Test-Path -LiteralPath $sourceBox.Text)) {
        $dialog.SelectedPath = $sourceBox.Text
    }
    if ($dialog.ShowDialog($form) -eq "OK") {
        $sourceBox.Text = $dialog.SelectedPath
        Update-UiState
    }
}

function Browse-Destination {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choose the destination folder (for example your thumb drive)"
    $dialog.ShowNewFolderButton = $true
    if (-not [string]::IsNullOrWhiteSpace($destinationBox.Text) -and (Test-Path -LiteralPath $destinationBox.Text)) {
        $dialog.SelectedPath = $destinationBox.Text
    }
    if ($dialog.ShowDialog($form) -eq "OK") {
        $destinationBox.Text = $dialog.SelectedPath
        Update-UiState
    }
}

$rootPanel = New-Object System.Windows.Forms.TableLayoutPanel
$rootPanel.Dock = "Fill"
$rootPanel.ColumnCount = 1
$rootPanel.RowCount = 4
$rootPanel.Padding = New-Object System.Windows.Forms.Padding(16)
[void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))

$settings = New-Object System.Windows.Forms.TableLayoutPanel
$settings.Dock = "Top"
$settings.AutoSize = $true
$settings.ColumnCount = 3
$settings.RowCount = 2
$settings.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
[void]$settings.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 100)))
[void]$settings.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$settings.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 110)))

$sourceLabel = New-Object System.Windows.Forms.Label
$sourceLabel.Text = "Source"
$sourceLabel.AutoSize = $true
$sourceLabel.Anchor = "Left"
$sourceLabel.Margin = New-Object System.Windows.Forms.Padding(0, 8, 8, 8)
$settings.Controls.Add($sourceLabel, 0, 0)

$sourceBox = New-Object System.Windows.Forms.TextBox
$sourceBox.ReadOnly = $true
$sourceBox.Cursor = [System.Windows.Forms.Cursors]::Hand
$sourceBox.Dock = "Fill"
$settings.Controls.Add($sourceBox, 1, 0)

$sourceBrowse = New-Object System.Windows.Forms.Button
$sourceBrowse.Text = "Browse…"
$sourceBrowse.Dock = "Fill"
$settings.Controls.Add($sourceBrowse, 2, 0)

$destLabel = New-Object System.Windows.Forms.Label
$destLabel.Text = "Destination"
$destLabel.AutoSize = $true
$destLabel.Anchor = "Left"
$destLabel.Margin = New-Object System.Windows.Forms.Padding(0, 8, 8, 8)
$settings.Controls.Add($destLabel, 0, 1)

$destinationBox = New-Object System.Windows.Forms.TextBox
$destinationBox.ReadOnly = $true
$destinationBox.Cursor = [System.Windows.Forms.Cursors]::Hand
$destinationBox.Dock = "Fill"
$settings.Controls.Add($destinationBox, 1, 1)

$destinationBrowse = New-Object System.Windows.Forms.Button
$destinationBrowse.Text = "Browse…"
$destinationBrowse.Dock = "Fill"
$settings.Controls.Add($destinationBrowse, 2, 1)

$results = New-Object System.Windows.Forms.ListView
$results.Dock = "Fill"
$results.View = "Details"
$results.FullRowSelect = $true
$results.GridLines = $true
[void]$results.Columns.Add("File", 240)
[void]$results.Columns.Add("Path", 400)
[void]$results.Columns.Add("Size", 90)

$actions = New-Object System.Windows.Forms.FlowLayoutPanel
$actions.Dock = "Fill"
$actions.AutoSize = $true
$actions.WrapContents = $false
$actions.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 8)

$scanButton = New-Object System.Windows.Forms.Button
$scanButton.Text = "1. Scan for .goo files"
$scanButton.AutoSize = $true
$scanButton.Padding = New-Object System.Windows.Forms.Padding(14, 6, 14, 6)
$actions.Controls.Add($scanButton)

$copyButton = New-Object System.Windows.Forms.Button
$copyButton.Text = "2. Copy to destination"
$copyButton.AutoSize = $true
$copyButton.Padding = New-Object System.Windows.Forms.Padding(14, 6, 14, 6)
$actions.Controls.Add($copyButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.AutoSize = $true
$cancelButton.Padding = New-Object System.Windows.Forms.Padding(14, 6, 14, 6)
$actions.Controls.Add($cancelButton)

$preserveCheck = New-Object System.Windows.Forms.CheckBox
$preserveCheck.Text = "Keep folder structure"
$preserveCheck.Checked = $true
$preserveCheck.AutoSize = $true
$preserveCheck.Margin = New-Object System.Windows.Forms.Padding(16, 10, 0, 0)
$actions.Controls.Add($preserveCheck)

$summaryLabel = New-Object System.Windows.Forms.Label
$summaryLabel.AutoSize = $true
$summaryLabel.Margin = New-Object System.Windows.Forms.Padding(16, 12, 0, 0)
$actions.Controls.Add($summaryLabel)

$statusPanel = New-Object System.Windows.Forms.TableLayoutPanel
$statusPanel.Dock = "Top"
$statusPanel.AutoSize = $true
$statusPanel.ColumnCount = 1
$statusPanel.RowCount = 2

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Dock = "Top"
$progress.Height = 18
$progress.Style = "Continuous"

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.AutoSize = $true
$statusLabel.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)
$statusLabel.Text = "Pick a Source folder, pick a Destination folder, then press Scan."

$statusPanel.Controls.Add($progress, 0, 0)
$statusPanel.Controls.Add($statusLabel, 0, 1)

$rootPanel.Controls.Add($settings, 0, 0)
$rootPanel.Controls.Add($results, 0, 1)
$rootPanel.Controls.Add($actions, 0, 2)
$rootPanel.Controls.Add($statusPanel, 0, 3)
$form.Controls.Add($rootPanel)

$sourceBrowse.Add_Click({ Browse-Source })
$destinationBrowse.Add_Click({ Browse-Destination })
$sourceBox.Add_Click({ Browse-Source })
$destinationBox.Add_Click({ Browse-Destination })
$cancelButton.Add_Click({ $script:cancelRequested = $true })

$scanButton.Add_Click({
    $source = $sourceBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($source) -or -not (Test-Path -LiteralPath $source)) {
        [System.Windows.Forms.MessageBox]::Show($form, "Pick a Source folder first (Browse…).", "Goo Collector") | Out-Null
        return
    }

    $script:busy = $true
    $script:cancelRequested = $false
    $script:foundFiles.Clear()
    $results.Items.Clear()
    $script:activeSourceRoot = [IO.Path]::GetFullPath($source)
    Update-UiState
    $progress.Style = "Marquee"
    $statusLabel.Text = "Scanning $source for *.goo …"
    $summaryLabel.Text = ""
    $form.Refresh()

    $found = New-Object System.Collections.Generic.List[object]
    $sw = [Diagnostics.Stopwatch]::StartNew()

    try {
        $pending = New-Object System.Collections.Generic.Stack[string]
        $pending.Push($source)
        while ($pending.Count -gt 0) {
            if ($script:cancelRequested) { break }
            $dir = $pending.Pop()

            try {
                Get-ChildItem -LiteralPath $dir -File -Filter "*.goo" -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($script:cancelRequested) { return }
                    $found.Add([PSCustomObject]@{ Path = $_.FullName; Size = $_.Length })
                    if ($found.Count % 25 -eq 0 -or $found.Count -eq 1) {
                        $statusLabel.Text = "Scanning… found $($found.Count) file(s). Last: $($_.FullName)"
                        [System.Windows.Forms.Application]::DoEvents()
                    }
                }
            } catch { }

            try {
                Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue |
                    Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
                    ForEach-Object { $pending.Push($_.FullName) }
            } catch { }

            [System.Windows.Forms.Application]::DoEvents()
        }

        $sorted = $found | Sort-Object Path
        $totalSize = [long]0
        foreach ($f in $sorted) {
            [void]$script:foundFiles.Add($f.Path)
            $item = New-Object System.Windows.Forms.ListViewItem([IO.Path]::GetFileName($f.Path))
            [void]$item.SubItems.Add($f.Path)
            [void]$item.SubItems.Add((Format-Bytes ([long]$f.Size)))
            [void]$results.Items.Add($item)
            $totalSize += [long]$f.Size
        }

        $sw.Stop()
        $summaryLabel.Text = "$($found.Count) file(s) · $(Format-Bytes $totalSize) · $($sw.Elapsed.ToString('mm\:ss'))"
        if ($script:cancelRequested) {
            $statusLabel.Text = "Scan canceled. Found $($found.Count) file(s) so far."
        } elseif ($found.Count -eq 0) {
            $statusLabel.Text = "No .goo files found under $source."
        } else {
            $statusLabel.Text = "Scan complete. $($found.Count) .goo file(s) ready to copy."
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($form, "Scan failed:`n$($_.Exception.Message)", "Goo Collector") | Out-Null
        $statusLabel.Text = "Scan failed."
    }
    finally {
        $progress.Style = "Continuous"
        $progress.Value = 0
        $script:busy = $false
        Update-UiState
    }
})

$copyButton.Add_Click({
    if ($script:foundFiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show($form, "Scan first so there are files to copy.", "Goo Collector") | Out-Null
        return
    }
    $destination = $destinationBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($destination) -or -not (Test-Path -LiteralPath $destination)) {
        [System.Windows.Forms.MessageBox]::Show($form, "Pick a Destination folder first (Browse…).", "Goo Collector") | Out-Null
        return
    }

    $sourceRoot = if ([string]::IsNullOrWhiteSpace($script:activeSourceRoot)) { $sourceBox.Text.Trim() } else { $script:activeSourceRoot }
    try {
        $src = [IO.Path]::GetFullPath($sourceRoot).TrimEnd('\', '/') + '\'
        $dst = [IO.Path]::GetFullPath($destination).TrimEnd('\', '/') + '\'
        if ($dst.StartsWith($src, [StringComparison]::OrdinalIgnoreCase) -or $src.StartsWith($dst, [StringComparison]::OrdinalIgnoreCase)) {
            [System.Windows.Forms.MessageBox]::Show($form, "Destination is inside the Source (or the same path). Choose a different Destination such as a thumb drive.", "Goo Collector") | Out-Null
            return
        }
    } catch { }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        $form,
        "Copy $($script:foundFiles.Count) .goo file(s) to:`n$destination`n`nContinue?",
        "Confirm copy",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $script:busy = $true
    $script:cancelRequested = $false
    Update-UiState
    $progress.Style = "Continuous"
    $progress.Minimum = 0
    $progress.Maximum = [Math]::Max(1, $script:foundFiles.Count)
    $progress.Value = 0

    $preserve = $preserveCheck.Checked
    $copied = 0
    $skipped = 0
    $failed = 0

    try {
        for ($i = 0; $i -lt $script:foundFiles.Count; $i++) {
            if ($script:cancelRequested) { break }
            $file = $script:foundFiles[$i]
            try {
                if ($preserve) {
                    $relative = Get-RelativePathSafe $sourceRoot $file
                } else {
                    $relative = [IO.Path]::GetFileName($file)
                }
                $relative = $relative.TrimStart('\', '/')
                if ($relative.Length -ge 2 -and $relative[1] -eq ':') {
                    $relative = $relative.Substring(2).TrimStart('\', '/')
                }
                $targetPath = Join-Path $destination $relative
                $targetDir = Split-Path -Parent $targetPath
                if (-not [string]::IsNullOrWhiteSpace($targetDir)) {
                    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
                }
                if (Test-Path -LiteralPath $targetPath) {
                    $skipped++
                } else {
                    Copy-Item -LiteralPath $file -Destination $targetPath
                    $copied++
                }
            } catch {
                $failed++
            }

            $progress.Value = [Math]::Min($i + 1, $progress.Maximum)
            $statusLabel.Text = "Copying $($i + 1) of $($script:foundFiles.Count): $([IO.Path]::GetFileName($file))"
            [System.Windows.Forms.Application]::DoEvents()
        }

        if ($script:cancelRequested) {
            $statusLabel.Text = "Copy canceled. Copied $copied, skipped $skipped, failed $failed."
        } else {
            $statusLabel.Text = "Copy finished. Copied $copied, skipped $skipped, failed $failed."
            [System.Windows.Forms.MessageBox]::Show(
                $form,
                "Done.`n`nCopied: $copied`nSkipped (already there): $skipped`nFailed: $failed`n`nDestination:`n$destination",
                "Goo Collector") | Out-Null
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($form, "Copy failed:`n$($_.Exception.Message)", "Goo Collector") | Out-Null
        $statusLabel.Text = "Copy failed."
    }
    finally {
        $script:busy = $false
        Update-UiState
    }
})

Update-UiState
[void]$form.ShowDialog()

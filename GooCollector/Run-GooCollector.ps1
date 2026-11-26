# Goo Collector — zero-install Windows GUI (PowerShell + WinForms)
# Double-click Run-GooCollector.bat, or run: powershell -ExecutionPolicy Bypass -File .\Run-GooCollector.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Goo Collector"
$form.Size = New-Object System.Drawing.Size(900, 640)
$form.MinimumSize = New-Object System.Drawing.Size(780, 560)
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

function Normalize-Extension([string]$value) {
    if ($null -eq $value) { $value = "" }
    $ext = $value.Trim()
    if ([string]::IsNullOrWhiteSpace($ext)) { return "" }
    if (-not $ext.StartsWith(".")) { $ext = ".$ext" }
    return $ext.ToLowerInvariant()
}

function Get-ReadyDrives {
    Get-PSDrive -PSProvider FileSystem |
        Where-Object { $_.Used -ne $null -or (Test-Path $_.Root) } |
        Sort-Object Name |
        ForEach-Object {
            $root = $_.Root
            $label = $_.Description
            if ([string]::IsNullOrWhiteSpace($label)) { $label = $_.Name }
            [PSCustomObject]@{ Root = $root; Display = "$root ($label)" }
        }
}

function Update-UiState {
    $scanButton.Enabled = -not $script:busy
    $copyButton.Enabled = (-not $script:busy) -and ($script:foundFiles.Count -gt 0) -and (-not [string]::IsNullOrWhiteSpace($destinationBox.Text))
    $cancelButton.Enabled = $script:busy
    $sourceDrive.Enabled = -not $script:busy
    $refreshButton.Enabled = -not $script:busy
    $browseSourceButton.Enabled = -not $script:busy
    $destinationBrowse.Enabled = -not $script:busy
    $extensionBox.Enabled = -not $script:busy
    $preserveCheck.Enabled = -not $script:busy
    $overwriteCheck.Enabled = -not $script:busy
}

function Refresh-Drives {
    $sourceDrive.Items.Clear()
    $drives = @(Get-ReadyDrives)
    foreach ($d in $drives) {
        [void]$sourceDrive.Items.Add($d.Display)
    }
    if ($sourceDrive.Items.Count -eq 0) {
        $statusLabel.Text = "No ready drives found."
        return
    }
    $cIndex = -1
    for ($i = 0; $i -lt $drives.Count; $i++) {
        if ($drives[$i].Root -like "C:*") { $cIndex = $i; break }
    }
    $sourceDrive.SelectedIndex = if ($cIndex -ge 0) { $cIndex } else { 0 }
    $script:driveMap = @{}
    for ($i = 0; $i -lt $drives.Count; $i++) {
        $script:driveMap[$drives[$i].Display] = $drives[$i].Root
    }
}

function Resolve-SourceRoot {
    if (-not [string]::IsNullOrWhiteSpace($customSource.Text)) {
        return $customSource.Text.Trim()
    }
    if ($null -eq $sourceDrive.SelectedItem) { return "" }
    $key = [string]$sourceDrive.SelectedItem
    if ($script:driveMap.ContainsKey($key)) { return $script:driveMap[$key] }
    return ""
}

function Get-RelativePathSafe([string]$root, [string]$fullPath) {
    $rootFull = [IO.Path]::GetFullPath($root).TrimEnd('\', '/') + '\'
    $pathFull = [IO.Path]::GetFullPath($fullPath)
    if ($pathFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        return $pathFull.Substring($rootFull.Length)
    }
    return [IO.Path]::GetFileName($fullPath)
}

# --- Layout ---
$rootPanel = New-Object System.Windows.Forms.TableLayoutPanel
$rootPanel.Dock = "Fill"
$rootPanel.ColumnCount = 1
$rootPanel.RowCount = 5
$rootPanel.Padding = New-Object System.Windows.Forms.Padding(16)
[void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
[void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))

# Source panel
$sourcePanel = New-Object System.Windows.Forms.TableLayoutPanel
$sourcePanel.Dock = "Top"
$sourcePanel.AutoSize = $true
$sourcePanel.ColumnCount = 4
$sourcePanel.RowCount = 2
$sourcePanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
[void]$sourcePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 110)))
[void]$sourcePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$sourcePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 100)))
[void]$sourcePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 110)))

$sourceLabel = New-Object System.Windows.Forms.Label
$sourceLabel.Text = "Source drive"
$sourceLabel.AutoSize = $true
$sourceLabel.Anchor = "Left"
$sourceLabel.Margin = New-Object System.Windows.Forms.Padding(0, 8, 8, 8)
$sourcePanel.Controls.Add($sourceLabel, 0, 0)

$sourceDrive = New-Object System.Windows.Forms.ComboBox
$sourceDrive.DropDownStyle = "DropDownList"
$sourceDrive.Dock = "Fill"
$sourcePanel.Controls.Add($sourceDrive, 1, 0)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "Refresh"
$refreshButton.Dock = "Fill"
$sourcePanel.Controls.Add($refreshButton, 2, 0)

$browseSourceButton = New-Object System.Windows.Forms.Button
$browseSourceButton.Text = "Browse…"
$browseSourceButton.Dock = "Fill"
$sourcePanel.Controls.Add($browseSourceButton, 3, 0)

$folderLabel = New-Object System.Windows.Forms.Label
$folderLabel.Text = "Or folder"
$folderLabel.AutoSize = $true
$folderLabel.Anchor = "Left"
$folderLabel.Margin = New-Object System.Windows.Forms.Padding(0, 8, 8, 8)
$sourcePanel.Controls.Add($folderLabel, 0, 1)

$customSource = New-Object System.Windows.Forms.TextBox
$customSource.ReadOnly = $true
$customSource.Dock = "Fill"
$sourcePanel.SetColumnSpan($customSource, 3)
$sourcePanel.Controls.Add($customSource, 1, 1)

# Destination panel
$destPanel = New-Object System.Windows.Forms.TableLayoutPanel
$destPanel.Dock = "Top"
$destPanel.AutoSize = $true
$destPanel.ColumnCount = 3
$destPanel.RowCount = 2
$destPanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
[void]$destPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 110)))
[void]$destPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$destPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 110)))

$destLabel = New-Object System.Windows.Forms.Label
$destLabel.Text = "Destination"
$destLabel.AutoSize = $true
$destLabel.Anchor = "Left"
$destLabel.Margin = New-Object System.Windows.Forms.Padding(0, 8, 8, 8)
$destPanel.Controls.Add($destLabel, 0, 0)

$destinationBox = New-Object System.Windows.Forms.TextBox
$destinationBox.ReadOnly = $true
$destinationBox.Dock = "Fill"
$destPanel.Controls.Add($destinationBox, 1, 0)

$destinationBrowse = New-Object System.Windows.Forms.Button
$destinationBrowse.Text = "Browse…"
$destinationBrowse.Dock = "Fill"
$destPanel.Controls.Add($destinationBrowse, 2, 0)

$options = New-Object System.Windows.Forms.FlowLayoutPanel
$options.AutoSize = $true
$options.Dock = "Fill"
$options.WrapContents = $false
$destPanel.SetColumnSpan($options, 3)
$destPanel.Controls.Add($options, 0, 1)

$extLabel = New-Object System.Windows.Forms.Label
$extLabel.Text = "Extension"
$extLabel.AutoSize = $true
$extLabel.Margin = New-Object System.Windows.Forms.Padding(0, 8, 8, 0)
$options.Controls.Add($extLabel)

$extensionBox = New-Object System.Windows.Forms.TextBox
$extensionBox.Text = ".goo"
$extensionBox.Width = 80
$extensionBox.Margin = New-Object System.Windows.Forms.Padding(0, 4, 16, 0)
$options.Controls.Add($extensionBox)

$preserveCheck = New-Object System.Windows.Forms.CheckBox
$preserveCheck.Text = "Keep folder structure"
$preserveCheck.Checked = $true
$preserveCheck.AutoSize = $true
$preserveCheck.Margin = New-Object System.Windows.Forms.Padding(0, 6, 16, 0)
$options.Controls.Add($preserveCheck)

$overwriteCheck = New-Object System.Windows.Forms.CheckBox
$overwriteCheck.Text = "Overwrite existing files"
$overwriteCheck.AutoSize = $true
$overwriteCheck.Margin = New-Object System.Windows.Forms.Padding(0, 6, 16, 0)
$options.Controls.Add($overwriteCheck)

# Results
$results = New-Object System.Windows.Forms.ListView
$results.Dock = "Fill"
$results.View = "Details"
$results.FullRowSelect = $true
$results.GridLines = $true
[void]$results.Columns.Add("File", 280)
[void]$results.Columns.Add("Path", 420)
[void]$results.Columns.Add("Size", 100)

# Actions
$actions = New-Object System.Windows.Forms.FlowLayoutPanel
$actions.Dock = "Fill"
$actions.AutoSize = $true
$actions.FlowDirection = "LeftToRight"
$actions.WrapContents = $false
$actions.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 8)

$scanButton = New-Object System.Windows.Forms.Button
$scanButton.Text = "Scan for .goo files"
$scanButton.AutoSize = $true
$scanButton.Padding = New-Object System.Windows.Forms.Padding(12, 4, 12, 4)
$actions.Controls.Add($scanButton)

$copyButton = New-Object System.Windows.Forms.Button
$copyButton.Text = "Copy to destination"
$copyButton.AutoSize = $true
$copyButton.Padding = New-Object System.Windows.Forms.Padding(12, 4, 12, 4)
$actions.Controls.Add($copyButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.AutoSize = $true
$cancelButton.Padding = New-Object System.Windows.Forms.Padding(12, 4, 12, 4)
$actions.Controls.Add($cancelButton)

$summaryLabel = New-Object System.Windows.Forms.Label
$summaryLabel.AutoSize = $true
$summaryLabel.Margin = New-Object System.Windows.Forms.Padding(16, 10, 0, 0)
$actions.Controls.Add($summaryLabel)

# Status
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
$statusLabel.Text = "Pick a source drive and destination, then scan."

$statusPanel.Controls.Add($progress, 0, 0)
$statusPanel.Controls.Add($statusLabel, 0, 1)

$rootPanel.Controls.Add($sourcePanel, 0, 0)
$rootPanel.Controls.Add($destPanel, 0, 1)
$rootPanel.Controls.Add($results, 0, 2)
$rootPanel.Controls.Add($actions, 0, 3)
$rootPanel.Controls.Add($statusPanel, 0, 4)
$form.Controls.Add($rootPanel)

# --- Events ---
$refreshButton.Add_Click({ Refresh-Drives })

$browseSourceButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choose a folder to scan for .goo files"
    if ($dialog.ShowDialog($form) -eq "OK") {
        $customSource.Text = $dialog.SelectedPath
    }
})

$destinationBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choose where to copy the .goo files (for example your thumb drive)"
    $dialog.ShowNewFolderButton = $true
    if ($dialog.ShowDialog($form) -eq "OK") {
        $destinationBox.Text = $dialog.SelectedPath
        Update-UiState
    }
})

$cancelButton.Add_Click({ $script:cancelRequested = $true })

$extensionBox.Add_TextChanged({
    $ext = Normalize-Extension $extensionBox.Text
    if ([string]::IsNullOrWhiteSpace($ext)) {
        $scanButton.Text = "Scan"
    } else {
        $scanButton.Text = "Scan for $ext files"
    }
})

$scanButton.Add_Click({
    $source = Resolve-SourceRoot
    if ([string]::IsNullOrWhiteSpace($source) -or -not (Test-Path -LiteralPath $source)) {
        [System.Windows.Forms.MessageBox]::Show($form, "Choose a valid source drive or folder first.", "Goo Collector") | Out-Null
        return
    }
    $extension = Normalize-Extension $extensionBox.Text
    if ([string]::IsNullOrWhiteSpace($extension)) {
        [System.Windows.Forms.MessageBox]::Show($form, "Enter a file extension such as .goo.", "Goo Collector") | Out-Null
        return
    }

    $script:busy = $true
    $script:cancelRequested = $false
    $script:foundFiles.Clear()
    $results.Items.Clear()
    $script:activeSourceRoot = [IO.Path]::GetFullPath($source)
    Update-UiState
    $progress.Style = "Marquee"
    $statusLabel.Text = "Scanning $source for *$extension …"
    $summaryLabel.Text = ""
    $form.Refresh()

    $pattern = "*$extension"
    $found = New-Object System.Collections.Generic.List[object]
    $sw = [Diagnostics.Stopwatch]::StartNew()

    try {
        $pending = New-Object System.Collections.Generic.Stack[string]
        $pending.Push($source)
        while ($pending.Count -gt 0) {
            if ($script:cancelRequested) { break }
            $dir = $pending.Pop()

            try {
                Get-ChildItem -LiteralPath $dir -File -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
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
            $item = New-Object System.Windows.Forms.ListViewItem($f.Path.Split([IO.Path]::DirectorySeparatorChar)[-1])
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
            $statusLabel.Text = "No $extension files found under $source."
        } else {
            $statusLabel.Text = "Scan complete. $($found.Count) $extension file(s) ready to copy."
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
        [System.Windows.Forms.MessageBox]::Show($form, "Choose a valid destination folder (for example your thumb drive).", "Goo Collector") | Out-Null
        return
    }

    $sourceRoot = if ([string]::IsNullOrWhiteSpace($script:activeSourceRoot)) { Resolve-SourceRoot } else { $script:activeSourceRoot }
    try {
        $src = [IO.Path]::GetFullPath($sourceRoot).TrimEnd('\', '/') + '\'
        $dst = [IO.Path]::GetFullPath($destination).TrimEnd('\', '/') + '\'
        if ($dst.StartsWith($src, [StringComparison]::OrdinalIgnoreCase) -or $src.StartsWith($dst, [StringComparison]::OrdinalIgnoreCase)) {
            [System.Windows.Forms.MessageBox]::Show($form, "Destination is inside the scan source (or the same path). Choose a different destination such as a thumb drive.", "Goo Collector") | Out-Null
            return
        }
    } catch { }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        $form,
        "Copy $($script:foundFiles.Count) file(s) to:`n$destination`n`nContinue?",
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
    $overwrite = $overwriteCheck.Checked
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
                if ((-not $overwrite) -and (Test-Path -LiteralPath $targetPath)) {
                    $skipped++
                } else {
                    Copy-Item -LiteralPath $file -Destination $targetPath -Force:$overwrite
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
                "Done.`n`nCopied: $copied`nSkipped: $skipped`nFailed: $failed`n`nDestination:`n$destination",
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

$script:driveMap = @{}
Refresh-Drives
Update-UiState
[void]$form.ShowDialog()

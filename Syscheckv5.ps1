Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Runtime.WindowsRuntime


$cSharpCode = @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    private const int SPI_SETDESKWALLPAPER = 20;
    private const int SPIF_UPDATEINIFILE = 0x01;
    private const int SPIF_SENDWININICHANGE = 0x02;
    public static void Set(string path) {
        SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, path, SPIF_UPDATEINIFILE | SPIF_SENDWININICHANGE);
    }
}
"@
Add-Type -TypeDefinition $cSharpCode -Language CSharp

[System.Net.ServicePointManager]::SecurityProtocol = 'Tls12'

[System.Windows.Forms.Application]::EnableVisualStyles()

# ============================================================================
# OCR INITIALIZATION - Windows Runtime OCR Support
# ============================================================================
$Global:WinRTLoaded = $false
$Global:OCREngine = $null

try {
    [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
    [Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapDecoder,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
    $Global:WinRTLoaded = $true
}
catch {
    $Global:WinRTLoaded = $false
}

# Helper for async WinRT operations
$Global:AsTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and
    $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

function Await-AsyncOperation {
    param(
        [Parameter(Mandatory=$true)]
        $WinRtTask,
        [Parameter(Mandatory=$true)]
        [Type]$ResultType
    )
    try {
        $taskGeneric = $Global:AsTaskGeneric.MakeGenericMethod($ResultType)
        $task = $taskGeneric.Invoke($null, @($WinRtTask))
        return $task.GetAwaiter().GetResult()
    }
    catch {
        throw "Async operation failed: $($_.Exception.Message)"
    }
}

function Initialize-OCREngine {
    if (-not $Global:WinRTLoaded) { return $false }
    if (-not $Global:OCREngine) {
        try {
            $Global:OCREngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage("en-US")
            if (-not $Global:OCREngine) { return $false }
            return $true
        }
        catch {
            return $false
        }
    }
    return $true
}



if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $script:PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}
else {
    try {
        $script:PSScriptRoot = Split-Path -Parent -Path ([System.Environment]::GetCommandLineArgs()[0])
    }
    catch {
        Write-Warning "[CRITICAL] Could not determine script path from command line arguments. Defaulting to current directory."
        $script:PSScriptRoot = (Get-Location).Path
    }
}







$Global:InstallerProfiles = @{
    "NVIDIA" = @{
        WindowTitles = @("NVIDIA", "NVIDIA App", "setup.exe", "*NVIDIA*Setup*", "*NVIDIA*Installer*", "NVIDIA Graphics Driver*")
        RequireButtons = $false
        Steps = @(
            # Installer phase - click AGREE & CONTINUE
            @{ Action = "Click"; ButtonNames = @("AGREE & CONTINUE", "AGREE AND CONTINUE", "I AGREE"); WaitEnabled = $true }
            # Wait for installer to finish and auto-launch NVIDIA App
            @{ Action = "Wait"; Seconds = 8 }
            # Kill the auto-launched NVIDIA App (runs without admin)
            @{ Action = "KillProcess"; ProcessName = "NVIDIA App" }
            # Launch NVIDIA App with admin privileges
            @{ Action = "LaunchProcess"; ProcessPath = "C:\Program Files\NVIDIA Corporation\NVIDIA App\CEF\NVIDIA App.exe"; WaitAfterLaunch = 5 }
            # Wait for popup to render (popup appears after main UI)
            @{ Action = "Wait"; Seconds = 3 }
            # NVIDIA App keyboard navigation starts here
            # Tab, Tab, Tab, Enter
           @{ Action = "SendKeys"; Keys = "{TAB}{TAB}{TAB}{ENTER}" }
            @{ Action = "Wait"; Seconds = 1 }
            # Tab, Tab, Enter
            @{ Action = "SendKeys"; Keys = "{TAB}{TAB}{ENTER}" }
            @{ Action = "Wait"; Seconds = 1 }
            # Tab, Tab, Enter
            @{ Action = "SendKeys"; Keys = "{TAB}{TAB}{ENTER}" }
            @{ Action = "Wait"; Seconds = 1 }
            # Tab, Tab, Enter
            @{ Action = "SendKeys"; Keys = "{TAB}{TAB}{ENTER}" }
            @{ Action = "Wait"; Seconds = 1 }
            # Tab, Tab, Tab, Tab, Tab, Arrow Down, Enter
            @{ Action = "SendKeys"; Keys = "{TAB}{DOWN}{ENTER}" }
            @{ Action = "Wait"; Seconds = 1 }
            # Tab, Tab, Tab, Tab, Tab, Tab, Enter
            @{ Action = "SendKeys"; Keys = "{TAB}{TAB}{TAB}{TAB}{TAB}{TAB}{ENTER}" }
            # Wait 120 seconds for installation
            @{ Action = "Wait"; Seconds = 35 }
            @{ Action = "SendKeys"; Keys = "{TAB}{ENTER}" }
            @{ Action = "SendKeys"; Keys = "{LEFT}{ENTER}" }
            @{ Action = "SendKeys"; Keys = "{TAB}{TAB}{TAB}{TAB}{ENTER}" }
            @{ Action = "Wait"; Seconds = 120 }
            @{ Action = "SendKeys"; Keys = "{TAB}{TAB}{TAB}{ENTER}" }
            @{ Action = "SendKeys"; Keys = "%{F4}" }

        )
    }
    "AMD" = @{
        WindowTitles = @("AMDSoftwareInstaller","amd-software-adrenalin-edition-25.11.1-minimalsetup-251111_web","AMDSoftwareInstaller.exe", "*AMD*Installer*", "*Radeon*Software*", "*AMD*Setup*", "*AMD*", "*Radeon*", "")
        RequireButtons = $false
        TemplateFolder = "amd"
        Steps = @()
    }
    "MSI" = @{
        WindowTitles = @("Select Setup Language","Setup -MSI Center","Setup - MSI Center", "MSI Center_2.0.53.0.exe","MSI Center_2.0.53.0.tmp", "*MSI Center*", "*MSI*Installer*", "*MSI*Setup*")
        LaunchApp = "StartApps:MSI Center"
        LaunchAppProfile = "MSICenter"
        Steps = @(
            @{ Action = "Click"; ButtonNames = @("OK"); WaitEnabled = $true }
            @{ Action = "Click"; ButtonNames = @("Install", "INSTALL") }
            @{ Action = "WaitForButton"; ButtonNames = @("Finish", "Close", "Complete"); MaxWait = 120 }
        )
    }
    "MSICenter" = @{
        WindowTitles = @("*MSI Center*")
        TemplateFolder = "msi"
        Steps = @(
            @{ Action = "Wait"; Seconds = 3 }  # Wait for window to fully load
            @{ Action = "SendKeys"; Keys = "{PGDN 21}" }
            @{ Action = "Wait"; Seconds = 2 }  # Wait after scrolling
        )
    }
    "Gigabyte" = @{
        WindowTitles = @("*GIGABYTE*Control*", "*GCC*Setup*", "*GIGABYTE*Installer*")
        LaunchApp = @(
            "C:\Program Files\GIGABYTE\Control Center\GCC.exe",
            "C:\Program Files (x86)\GIGABYTE\Control Center\GCC.exe",
            "%PUBLIC%\Desktop\GIGABYTE Control Center.lnk",
            "%USERPROFILE%\Desktop\GIGABYTE Control Center.lnk",
            "C:\Users\Public\Desktop\GIGABYTE Control Center.lnk"
        )
        LaunchAppProfile = "GigabyteApp"
        Steps = @(
            @{ Action = "Click"; ButtonNames = @("Install", "INSTALL") }
            @{ Action = "WaitForButton"; ButtonNames = @("Finish", "Close", "Complete"); MaxWait = 120 }
        )
    }
    "GigabyteApp" = @{
        WindowTitles = @("*GIGABYTE*Control*Center*", "*GCC*")
        TemplateFolder = "gigabyte"
        Steps = @()
    }
    "ASRock" = @{
        WindowTitles = @("*ASRock*APP*Shop*", "*APP*Shop*Setup*", "*ASRock*Installer*", "*APPShopSetup(v2.0.0.4)*", "Setup","APPShopSetup(v2.0.0.4).tmp", "*Select Setup Language*", "Select Setup Language", "Setup - APP Shop v2.0.0.4", "Setup/Uninstall (32 bit) (2)","License Agreement")
        RequireButtons = $false
        Steps = @(
            @{ Action = "SendKeys";Keys = "{Enter}" }
            @{ Action = "SendKeys";Keys = "{TAB}{UP}{ENTER}" }
            @{ Action = "SendKeys";Keys = "{ENTER}" }
            @{ Action = "Wait"; Seconds = 60 }
            @{ Action = "Click"; ButtonNames = @("Finish", "Close", "Complete") }
        )
    }
    "Asustek" = @{
        WindowTitles = @("*Armoury Crate*", "*ASUS*Installer*", "*Armoury*Setup*")
        Steps = @(
            @{ Action = "Click"; ButtonNames = @("Next", "NEXT", "Next >") }
            @{ Action = "Click"; ButtonNames = @("I Agree", "Accept", "Agree") }
            @{ Action = "Click"; ButtonNames = @("Install", "INSTALL") }
            @{ Action = "Wait"; Seconds = 120 }
            @{ Action = "Click"; ButtonNames = @("Finish", "Close", "Complete") }
        )
    }
    "TX20E" = @{
        WindowTitles = @("*Realtek*", "*Setup*", "*Install*", "*TP-Link*Network*Adapter*", "TP-Link Network Adapter")
        TemplateFolder= "tx20e"
        RefindWindowEachStep = $true  # Re-find window before each template step
        Steps = @()
    }
    "Realtek_RTL8852BE_TX20E" = @{
        WindowTitles = @("*Realtek*", "*Setup*", "*Install*", "*TP-Link*Network*Adapter*", "TP-Link Network Adapter")
        TemplateFolder= "tx20e"
        RefindWindowEachStep = $true  # Re-find window before each template step
        Steps = @()
    }
}

# ============================================================================
# OCR HELPER FUNCTIONS
# ============================================================================

function Get-WindowHandleByProcess {
    param(
        [int]$ProcessId,
        [string[]]$WindowTitles
    )

    Write-Host "[Get-WindowHandleByProcess] Starting - ProcessId: $ProcessId, Titles: $($WindowTitles -join ', ')" -ForegroundColor Gray

    if (-not ([System.Management.Automation.PSTypeName]'WindowOps').Type) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class WindowOps {
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(int dwFlags, int dx, int dy, int cButtons, int dwExtraInfo);

    public const int MOUSEEVENTF_LEFTDOWN = 0x02;
    public const int MOUSEEVENTF_LEFTUP = 0x04;

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(50);
        mouse_event(MOUSEEVENTF_LEFTDOWN, x, y, 0, 0);
        System.Threading.Thread.Sleep(50);
        mouse_event(MOUSEEVENTF_LEFTUP, x, y, 0, 0);
    }
}
"@
    }

    $script:FoundWindows = New-Object System.Collections.ArrayList

    # Store parameters in script scope for callback access
    $script:TargetProcessId = $ProcessId
    $script:TargetWindowTitles = $WindowTitles

    Write-Host "[Get-WindowHandleByProcess] Created FoundWindows list, starting EnumWindows..." -ForegroundColor Gray

    $callback = {
        param($hWnd, $lParam)

        # PERFORMANCE: Early exit if we already found a window
        if ($script:FoundWindows.Count -gt 0) {
            return $false
        }

        if ([WindowOps]::IsWindowVisible($hWnd)) {
            $length = [WindowOps]::GetWindowTextLength($hWnd)
            if ($length -gt 0) {
                $sb = New-Object System.Text.StringBuilder($length + 1)
                [WindowOps]::GetWindowText($hWnd, $sb, $sb.Capacity) | Out-Null
                $title = $sb.ToString()

                $winProcessId = 0
                [WindowOps]::GetWindowThreadProcessId($hWnd, [ref]$winProcessId) | Out-Null

                $matchesProcess = ($winProcessId -eq $script:TargetProcessId)
                $matchesTitle = $false

                # Debug output for NVIDIA process
                if ($matchesProcess) {
                    Write-Host "[Get-WindowHandleByProcess] Found window for ProcessId: $winProcessId - Title: '$title'" -ForegroundColor Cyan
                }

                if ($script:TargetWindowTitles) {
                    foreach ($pattern in $script:TargetWindowTitles) {
                        if ($title -like $pattern) {
                            $matchesTitle = $true
                            Write-Host "[Get-WindowHandleByProcess] Title matched pattern '$pattern' - Title: '$title'" -ForegroundColor Green
                            break
                        }
                    }
                }

                if ($matchesProcess -or $matchesTitle) {
                    $rect = New-Object WindowOps+RECT
                    [WindowOps]::GetWindowRect($hWnd, [ref]$rect) | Out-Null
                    $width = $rect.Right - $rect.Left
                    $height = $rect.Bottom - $rect.Top

                    if ($width -gt 0 -and $height -gt 0) {
                        [void]$script:FoundWindows.Add($hWnd)
                        # PERFORMANCE: Stop enumeration once we find a match
                        return $false
                    }
                }
            }
        }
        return $true
    }

    Write-Host "[Get-WindowHandleByProcess] Calling EnumWindows..." -ForegroundColor Gray
    [WindowOps]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
    Write-Host "[Get-WindowHandleByProcess] EnumWindows completed. Found: $($script:FoundWindows.Count) windows" -ForegroundColor Gray

    if ($script:FoundWindows.Count -gt 0) {
        Write-Host "[Get-WindowHandleByProcess] Returning handle: $($script:FoundWindows[0])" -ForegroundColor Gray
        return $script:FoundWindows[0]
    }
    Write-Host "[Get-WindowHandleByProcess] No window found, returning Zero" -ForegroundColor Gray
    return [IntPtr]::Zero
}

function Capture-WindowScreenshot {
    param([IntPtr]$WindowHandle)

    try {
        $rect = New-Object WindowOps+RECT
        [WindowOps]::GetWindowRect($WindowHandle, [ref]$rect) | Out-Null

        $width = $rect.Right - $rect.Left
        $height = $rect.Bottom - $rect.Top

        if ($width -le 0 -or $height -le 0) { return $null }

        [WindowOps]::SetForegroundWindow($WindowHandle) | Out-Null
        Start-Sleep -Milliseconds 300

        $bitmap = New-Object System.Drawing.Bitmap($width, $height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        $graphics.Dispose()

        return $bitmap
    }
    catch {
        return $null
    }
}

function Find-TextInImage {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$SearchText
    )

    if (-not (Initialize-OCREngine)) { return $null }

    try {
        $tempFile = [System.IO.Path]::Combine($env:TEMP, "ocr_$([Guid]::NewGuid()).png")
        $Bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Png)

        $fileTask = [Windows.Storage.StorageFile]::GetFileFromPathAsync($tempFile)
        $storageFile = Await-AsyncOperation -WinRtTask $fileTask -ResultType ([Windows.Storage.StorageFile])

        $streamTask = $storageFile.OpenAsync([Windows.Storage.FileAccessMode]::Read)
        $stream = Await-AsyncOperation -WinRtTask $streamTask -ResultType ([Windows.Storage.Streams.IRandomAccessStream])

        $decoderTask = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)
        $decoder = Await-AsyncOperation -WinRtTask $decoderTask -ResultType ([Windows.Graphics.Imaging.BitmapDecoder])

        $bitmapTask = $decoder.GetSoftwareBitmapAsync()
        $softwareBitmap = Await-AsyncOperation -WinRtTask $bitmapTask -ResultType ([Windows.Graphics.Imaging.SoftwareBitmap])

        $ocrTask = $Global:OCREngine.RecognizeAsync($softwareBitmap)
        $ocrResult = Await-AsyncOperation -WinRtTask $ocrTask -ResultType ([Windows.Media.Ocr.OcrResult])

        $stream.Dispose()
        $softwareBitmap.Dispose()
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

        foreach ($line in $ocrResult.Lines) {
            if ($line.Text -match "(?i)$([regex]::Escape($SearchText))") {
                if ($line.Words -and $line.Words.Count -gt 0) {
                    $bounds = $line.Words[0].BoundingRect
                    $x = if ($bounds.X -is [array]) { $bounds.X[0] } else { $bounds.X }
                    $y = if ($bounds.Y -is [array]) { $bounds.Y[0] } else { $bounds.Y }
                    $width = if ($bounds.Width -is [array]) { $bounds.Width[0] } else { $bounds.Width }
                    $height = if ($bounds.Height -is [array]) { $bounds.Height[0] } else { $bounds.Height }

                    return @{
                        Text = $line.Text
                        X = [int]($x + $width / 2)
                        Y = [int]($y + $height / 2)
                        Found = $true
                    }
                }
            }
        }
        return $null
    }
    catch {
        return $null
    }
}

function Find-TemplateInImage {
    param(
        [System.Drawing.Bitmap]$Screenshot,
        [System.Drawing.Image]$Template,
        [double]$Threshold = 0.7
    )

    try {
        # Save screenshot and template to temp files for Python processing
        $screenshotPath = [System.IO.Path]::Combine($env:TEMP, "screenshot_$([Guid]::NewGuid()).png")
        $templatePath = [System.IO.Path]::Combine($env:TEMP, "template_$([Guid]::NewGuid()).png")

        $Screenshot.Save($screenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $Template.Save($templatePath, [System.Drawing.Imaging.ImageFormat]::Png)

        # Try to find compiled executable first, fallback to Python script
        $compiledExe = Join-Path $script:PSScriptRoot "opencvpython\template_matcher.exe"
        $pythonScript = Join-Path $script:PSScriptRoot "opencvpython\template_matcher.py"

        $executable = $null
        $usePython = $false

        # Prefer Python script first (more reliable for now)
        if (Test-Path $pythonScript) {
            # Check if python is actually available (not just the Microsoft Store stub)
            $pythonAvailable = $false
            try {
                $pythonTest = & python --version 2>&1
                if ($LASTEXITCODE -eq 0 -and $pythonTest -match "Python \d+\.\d+") {
                    $pythonAvailable = $true
                }
            } catch {}

            if ($pythonAvailable) {
                $executable = "python"
                $usePython = $true
                Write-Host "[TemplateMatch] Using Python script..." -ForegroundColor Gray
            }
        }

        # Fallback to compiled exe if Python not available
        if (-not $executable -and (Test-Path $compiledExe)) {
            # If running from network share, copy exe to local temp to avoid execution blocking
            if ($compiledExe -like "\\*") {
                $localExe = Join-Path $env:TEMP "template_matcher.exe"
                if (-not (Test-Path $localExe) -or ((Get-Item $compiledExe).LastWriteTime -gt (Get-Item $localExe).LastWriteTime)) {
                    Write-Host "[TemplateMatch] Copying exe from network to local temp..." -ForegroundColor Gray
                    Copy-Item $compiledExe $localExe -Force
                }
                $executable = $localExe
            }
            else {
                $executable = $compiledExe
            }
            Write-Host "[TemplateMatch] Using compiled executable..." -ForegroundColor Gray
        }

        if (-not $executable) {
            Write-Host "[TemplateMatch] Neither Python nor compiled executable available!" -ForegroundColor Red
            Write-Host "[TemplateMatch] Expected: $pythonScript or $compiledExe" -ForegroundColor Red
            Remove-Item $screenshotPath -Force -ErrorAction SilentlyContinue
            Remove-Item $templatePath -Force -ErrorAction SilentlyContinue
            return $null
        }

        # Execute template matcher using Start-Process for reliable output capture
        Write-Host "[TemplateMatch] Executing: $executable" -ForegroundColor Gray

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        if ($usePython) {
            $psi.FileName = $executable
            $psi.Arguments = "`"$pythonScript`" `"$screenshotPath`" `"$templatePath`" $Threshold"
            Write-Host "[TemplateMatch] Args: python $pythonScript $screenshotPath $templatePath $Threshold" -ForegroundColor Gray
        }
        else {
            $psi.FileName = $executable
            $psi.Arguments = "`"$screenshotPath`" `"$templatePath`" $Threshold"
            Write-Host "[TemplateMatch] Args: $screenshotPath $templatePath $Threshold" -ForegroundColor Gray
        }

        try {
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            $process.Start() | Out-Null
            $process.WaitForExit(10000)  # 10 second timeout

            $result = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $exitCode = $process.ExitCode

            Write-Host "[TemplateMatch] Exit code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Yellow' })
            Write-Host "[TemplateMatch] Raw output: $result" -ForegroundColor Gray

            if ($stderr) {
                Write-Host "[TemplateMatch] STDERR: $stderr" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "[TemplateMatch] Exception running matcher: $($_.Exception.Message)" -ForegroundColor Red
            Remove-Item $screenshotPath -Force -ErrorAction SilentlyContinue
            Remove-Item $templatePath -Force -ErrorAction SilentlyContinue
            return $null
        }

        # Clean up temp files
        Remove-Item $screenshotPath -Force -ErrorAction SilentlyContinue
        Remove-Item $templatePath -Force -ErrorAction SilentlyContinue

        if ($exitCode -ne 0) {
            Write-Host "[TemplateMatch] Matcher failed with exit code $exitCode" -ForegroundColor Red
            Write-Host "[TemplateMatch] Output: $result" -ForegroundColor Red
            return $null
        }

        # Parse JSON result
        $matchResult = $result | ConvertFrom-Json

        if ($matchResult.success) {
            Write-Host "[TemplateMatch] Match found at ($($matchResult.center_x), $($matchResult.center_y)) with confidence $($matchResult.confidence)" -ForegroundColor Green
            return @{
                Found = $true
                X = $matchResult.center_x
                Y = $matchResult.center_y
                Confidence = $matchResult.confidence
                Width = $matchResult.template_width
                Height = $matchResult.template_height
            }
        }
        else {
            Write-Host "[TemplateMatch] No match found: $($matchResult.error)" -ForegroundColor Yellow
            return $null
        }
    }
    catch {
        Write-Host "[TemplateMatch] Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Click-TextInWindow {
    param(
        [IntPtr]$WindowHandle,
        [array]$SearchTexts,
        [int]$OffsetX = 0,
        [int]$OffsetY = 0
    )

    try {
        Write-Host "[OCR] Capturing screenshot of window..." -ForegroundColor Gray
        $screenshot = Capture-WindowScreenshot -WindowHandle $WindowHandle
        if (-not $screenshot) {
            Write-Host "[OCR] Failed to capture screenshot" -ForegroundColor Red
            return $false
        }

        Write-Host "[OCR] Screenshot captured: $($screenshot.Width)x$($screenshot.Height)" -ForegroundColor Gray

        # Save screenshot for debugging
        $debugFolder = Join-Path $PSScriptRoot "debugocr"
        if (-not (Test-Path $debugFolder)) {
            New-Item -ItemType Directory -Path $debugFolder -Force | Out-Null
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $debugPath = Join-Path $debugFolder "ocr_debug_${timestamp}.png"
        $screenshot.Save($debugPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "[OCR] Screenshot saved to: $debugPath" -ForegroundColor Cyan

        foreach ($searchText in $SearchTexts) {
            Write-Host "[OCR] Searching for text: '$searchText'" -ForegroundColor Gray
            $result = Find-TextInImage -Bitmap $screenshot -SearchText $searchText

            if ($result -and $result.Found) {
                Write-Host "[OCR] Text found! Position: ($($result.X), $($result.Y))" -ForegroundColor Green
                $rect = New-Object WindowOps+RECT
                [WindowOps]::GetWindowRect($WindowHandle, [ref]$rect) | Out-Null

                $clickX = $rect.Left + $result.X + $OffsetX
                $clickY = $rect.Top + $result.Y + $OffsetY

                Write-Host "[OCR] Clicking at screen position: ($clickX, $clickY)" -ForegroundColor Green
                [WindowOps]::Click($clickX, $clickY)
                $screenshot.Dispose()
                return $true
            } else {
                Write-Host "[OCR] Text not found: '$searchText'" -ForegroundColor Yellow
            }
        }

        $screenshot.Dispose()
        Write-Host "[OCR] None of the search texts were found in the image" -ForegroundColor Red
        return $false
    }
    catch {
        Write-Host "[OCR] Exception: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Find-AutomationWindow {
    param([string]$WindowTitle, [bool]$ShowDebug = $false)
    try {
        $root = [System.Windows.Automation.AutomationElement]::RootElement
        if ($WindowTitle -like "*``**") {
            $allWindowsCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)

            # PERFORMANCE FIX: Use Children instead of Descendants (much faster)
            $allWindows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $allWindowsCondition)

            # REMOVED DEBUG POPUPS HERE

            foreach ($win in $allWindows) {
                if ($win.Current.Name -like $WindowTitle) { return $win }
            }
        }
        else {
            $condition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $WindowTitle)
            return $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        }
    } catch { }
    return $null
}

function Find-AutomationButton {
    param([System.Windows.Automation.AutomationElement]$Window, [array]$ButtonNames, [int]$ButtonIndex = -1, [bool]$ShowDebug = $false)
    if (-not $Window) { return $null }
    try {
        $allButtonsCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
        $allButtons = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $allButtonsCondition)
        # REMOVED DEBUG POPUPS HERE
        if ($ButtonIndex -ge 0) {
            if ($allButtons.Count -gt $ButtonIndex) {
                return $allButtons[$ButtonIndex]
            }
            return $null
        }
        foreach ($buttonName in $ButtonNames) {
            $condition = New-Object System.Windows.Automation.AndCondition((New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)), (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $buttonName)))
            $button = $Window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
            if ($button) { return $button }
            foreach ($btn in $allButtons) {
                if ($btn.Current.Name -like "*$buttonName*") { return $btn }
            }
        }
    } catch { }
    return $null
}

function Scroll-AutomationWindow {
    param([System.Windows.Automation.AutomationElement]$Window, [int]$ScrollCount = 5)
    if (-not $Window) { return $false }
    try {
        $scrollCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::IsScrollPatternAvailableProperty, $true)
        $scrollElement = $Window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $scrollCondition)
        if ($scrollElement) {
            try {
                $scrollPattern = $scrollElement.GetCurrentPattern([System.Windows.Automation.ScrollPattern]::Pattern)
                for ($i = 0; $i -lt $ScrollCount; $i++) {
                    $scrollPattern.Scroll([System.Windows.Automation.ScrollAmount]::NoAmount, [System.Windows.Automation.ScrollAmount]::LargeIncrement)
                    Start-Sleep -Milliseconds 100
                }
                return $true
            } catch { }
        }
    } catch { }
    try {
        $Window.SetFocus()
        Start-Sleep -Milliseconds 200
        for ($i = 0; $i -lt $ScrollCount; $i++) {
            [System.Windows.Forms.SendKeys]::SendWait("{PGDN}")
            Start-Sleep -Milliseconds 150
        }
        return $true
    } catch { }
    return $false
}

function Wait-AutomationButtonEnabled {
    param([System.Windows.Automation.AutomationElement]$Button, [int]$TimeoutSeconds = 15)
    if (-not $Button) { return $false }
    $attempts = 0
    while ($attempts -lt $TimeoutSeconds) {
        try {
            if ($Button.Current.IsEnabled) { return $true }
        } catch { return $false }
        Start-Sleep -Seconds 1
        $attempts++
    }
    return $false
}

function Invoke-AutomationButtonClick {
    param([System.Windows.Automation.AutomationElement]$Button)
    if (-not $Button) { return $false }
    try {
        if ($Button.Current.IsInvokePatternAvailable) {
            $invokePattern = $Button.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
            $invokePattern.Invoke()
            return $true
        }
        if ($Button.Current.IsTogglePatternAvailable) {
            $togglePattern = $Button.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
            $togglePattern.Toggle()
            return $true
        }
        $Button.SetFocus()
        Start-Sleep -Milliseconds 200
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        return $true
    } catch { }
    return $false
}

function Execute-AutoClickerStep {
    param(
        [hashtable]$Step,
        [System.Windows.Automation.AutomationElement]$Window,
        [IntPtr]$WindowHandle = [IntPtr]::Zero,
        [bool]$ShowDebug = $false
    )
    # The ShowDebug parameter is now effectively ignored to maintain silent operation

    # Inject WindowHandle into Step for actions that need it
    if ($WindowHandle -ne [IntPtr]::Zero) {
        $Step.WindowHandle = $WindowHandle
    }

    switch ($Step.Action) {
        "Scroll" {
            Scroll-AutomationWindow -Window $Window -ScrollCount 5 | Out-Null
            Start-Sleep -Milliseconds 500
            return $true
        }
        "Click" {
            $buttonIndex = if ($Step.ButtonIndex -ne $null) { $Step.ButtonIndex } else { -1 }
            $button = Find-AutomationButton -Window $Window -ButtonNames $Step.ButtonNames -ButtonIndex $buttonIndex -ShowDebug $false
            if ($button) {
                if ($Step.WaitEnabled) {
                    if (-not (Wait-AutomationButtonEnabled -Button $button -TimeoutSeconds 3)) { return $false }
                }
                if (Invoke-AutomationButtonClick -Button $button) {
                    Start-Sleep -Seconds 1
                    return $true
                }
            }
            if ($Step.Optional) {
                return $true
            }
            return $false
        }
        "Wait" {
            Start-Sleep -Seconds $Step.Seconds
            return $true
        }
        "WaitForButton" {
            $maxWait = if ($Step.MaxWait) { $Step.MaxWait } else { 300 }
            $startTime = Get-Date
            while (((Get-Date) - $startTime).TotalSeconds -lt $maxWait) {
                $buttonIndex = if ($Step.ButtonIndex -ne $null) { $Step.ButtonIndex } else { -1 }
                $button = Find-AutomationButton -Window $Window -ButtonNames $Step.ButtonNames -ButtonIndex $buttonIndex -ShowDebug $false
                if ($button) {
                    if (Wait-AutomationButtonEnabled -Button $button -TimeoutSeconds 2) {
                        if (Invoke-AutomationButtonClick -Button $button) {
                            Start-Sleep -Seconds 1
                            return $true
                        }
                    }
                }
                Start-Sleep -Milliseconds 500
            }
            if ($Step.Optional) {
                return $true
            }
            return $false
        }
        "SendKeys" {
            $keysSent = $false

            # Try UI Automation window first
            if ($Window) {
                try {
                    $Window.SetFocus()
                    Start-Sleep -Milliseconds 500
                    [System.Windows.Forms.SendKeys]::SendWait($Step.Keys)
                    Start-Sleep -Milliseconds 500
                    $keysSent = $true
                } catch {
                    Write-Host "[SendKeys] UI Automation failed: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }

            # Fallback: Use window handle to set foreground window
            if (-not $keysSent -and $Step.WindowHandle) {
                try {
                    [WindowOps]::SetForegroundWindow($Step.WindowHandle) | Out-Null
                    Start-Sleep -Milliseconds 500

                    # Retry setting foreground to ensure focus
                    for ($i = 0; $i -lt 3; $i++) {
                        [WindowOps]::SetForegroundWindow($Step.WindowHandle) | Out-Null
                        Start-Sleep -Milliseconds 100
                    }

                    [System.Windows.Forms.SendKeys]::SendWait($Step.Keys)
                    Start-Sleep -Milliseconds 500
                    $keysSent = $true
                } catch {
                    Write-Host "[SendKeys] Fallback failed: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }

            return $keysSent
        }
        "KillProcess" {
            try {
                $processes = Get-Process -Name $Step.ProcessName -ErrorAction SilentlyContinue
                foreach ($proc in $processes) {
                    $proc.Kill()
                }
                Start-Sleep -Seconds 1
                return $true
            } catch {
                return $true  # Continue even if kill fails
            }
        }
        "LaunchProcess" {
            try {
                if (Test-Path $Step.ProcessPath) {
                    Start-Process $Step.ProcessPath -Verb RunAs -ErrorAction Stop
                    Start-Sleep -Seconds $Step.WaitAfterLaunch
                    return $true
                }
                return $false
            } catch {
                return $false
            }
        }
        "ClickOCR" {
            # OCR-based clicking - requires WindowHandle to be stored in installer context
            Write-Host "[ClickOCR] WindowHandle: $($Step.WindowHandle), SearchTexts: $($Step.SearchTexts -join ', ')" -ForegroundColor Cyan

            if ($Step.WindowHandle -and $Step.WindowHandle -ne [IntPtr]::Zero) {
                $offsetX = if ($Step.OffsetX) { $Step.OffsetX } else { 0 }
                $offsetY = if ($Step.OffsetY) { $Step.OffsetY } else { 0 }

                Write-Host "[ClickOCR] Attempting OCR click..." -ForegroundColor Cyan
                $clicked = Click-TextInWindow `
                    -WindowHandle $Step.WindowHandle `
                    -SearchTexts $Step.SearchTexts `
                    -OffsetX $offsetX `
                    -OffsetY $offsetY

                if ($clicked) {
                    Write-Host "[ClickOCR] Click succeeded!" -ForegroundColor Green
                    Start-Sleep -Seconds 1
                    return $true
                } else {
                    Write-Host "[ClickOCR] Click failed - text not found" -ForegroundColor Yellow
                }

                if ($Step.Optional) {
                    Write-Host "[ClickOCR] Step is optional, continuing..." -ForegroundColor Yellow
                    return $true
                }
                return $false
            } else {
                Write-Host "[ClickOCR] No valid WindowHandle available" -ForegroundColor Red
            }
            return $false
        }
        "ClickCoordinates" {
            # Try UI Automation window first
            if ($Window) {
                try {
                    $rect = $Window.Current.BoundingRectangle
                    $clickX = $rect.Left + $Step.X
                    $clickY = $rect.Top + $Step.Y

                    [WindowOps]::Click($clickX, $clickY)
                    Start-Sleep -Milliseconds 500
                    return $true
                } catch { }
            }
            # Fallback to WindowHandle if available
            elseif ($Step.WindowHandle -and $Step.WindowHandle -ne [IntPtr]::Zero) {
                try {
                    $rect = New-Object WindowOps+RECT
                    [WindowOps]::GetWindowRect($Step.WindowHandle, [ref]$rect) | Out-Null

                    $clickX = $rect.Left + $Step.X
                    $clickY = $rect.Top + $Step.Y

                    Write-Host "[ClickCoordinates] Clicking at ($clickX, $clickY) - Window offset: ($($rect.Left), $($rect.Top))" -ForegroundColor Cyan
                    [WindowOps]::Click($clickX, $clickY)
                    Start-Sleep -Milliseconds 500
                    return $true
                } catch {
                    Write-Host "[ClickCoordinates] Error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "[ClickCoordinates] No window or handle available. Window=$Window, Handle=$($Step.WindowHandle)" -ForegroundColor Red
            }
            return $false
        }
        "ClickTemplate" {
            Write-Host "[ClickTemplate] Searching for template: $($Step.TemplateName)" -ForegroundColor Cyan

            if (-not $Step.WindowHandle -or $Step.WindowHandle -eq [IntPtr]::Zero) {
                Write-Host "[ClickTemplate] No valid WindowHandle available" -ForegroundColor Red
                if ($Step.Optional) { return $true }
                return $false
            }

            try {
                # Capture window screenshot
                $screenshot = Capture-WindowScreenshot -WindowHandle $Step.WindowHandle
                if (-not $screenshot) {
                    Write-Host "[ClickTemplate] Failed to capture window screenshot" -ForegroundColor Red
                    if ($Step.Optional) { return $true }
                    return $false
                }

                # Load template image - support both root and subfolder locations
                $templateFolder = Join-Path $script:PSScriptRoot "ScreenshotTemplates"
                $templatePath = $null

                # Check if step specifies a profile subfolder
                if ($Step.ProfileFolder) {
                    $subfolderPath = Join-Path $templateFolder $Step.ProfileFolder
                    $templatePath = Join-Path $subfolderPath "$($Step.TemplateName).png"
                }

                # Fallback to root ScreenshotTemplates folder
                if (-not $templatePath -or -not (Test-Path $templatePath)) {
                    $templatePath = Join-Path $templateFolder "$($Step.TemplateName).png"
                }

                if (-not (Test-Path $templatePath)) {
                    Write-Host "[ClickTemplate] Template not found: $templatePath" -ForegroundColor Red
                    Write-Host "[ClickTemplate] Please place screenshot in: $templateFolder" -ForegroundColor Yellow
                    $screenshot.Dispose()
                    if ($Step.Optional) { return $true }
                    return $false
                }

                $template = [System.Drawing.Image]::FromFile($templatePath)
                Write-Host "[ClickTemplate] Template loaded: $($template.Width)x$($template.Height)" -ForegroundColor Gray

                # Find template in screenshot
                $match = Find-TemplateInImage -Screenshot $screenshot -Template $template

                $template.Dispose()

                if ($match -and $match.Found) {
                    Write-Host "[ClickTemplate] Template found at ($($match.X), $($match.Y)) with confidence $($match.Confidence)" -ForegroundColor Green

                    # Get window position
                    $rect = New-Object WindowOps+RECT
                    [WindowOps]::GetWindowRect($Step.WindowHandle, [ref]$rect) | Out-Null

                    # Click at center of matched template
                    $clickX = $rect.Left + $match.X
                    $clickY = $rect.Top + $match.Y

                    Write-Host "[ClickTemplate] Clicking at screen position: ($clickX, $clickY)" -ForegroundColor Green
                    [WindowOps]::Click($clickX, $clickY)
                    $screenshot.Dispose()
                    Start-Sleep -Seconds 1
                    return $true
                } else {
                    Write-Host "[ClickTemplate] Template not found in window" -ForegroundColor Yellow
                    $screenshot.Dispose()
                    if ($Step.Optional) { return $true }
                    return $false
                }
            }
            catch {
                Write-Host "[ClickTemplate] Error: $($_.Exception.Message)" -ForegroundColor Red
                if ($Step.Optional) { return $true }
                return $false
            }
        }
        default { return $false }
    }
}

function Start-AutoClickerForInstallers {
    param([array]$Installers)
    if (-not $global:AutoClickEnabled) { return }

    # Track completed installers to prevent re-running
    $script:CompletedInstallers = @()

    # Process installers one at a time (sequential mode)
    foreach ($installerToRun in $Installers) {
        if (-not (Test-Path $installerToRun.Path)) {
            Write-Host "[AutoClicker] Skipping $($installerToRun.VendorType) - file not found: $($installerToRun.Path)" -ForegroundColor Yellow
            continue
        }
        if (-not $Global:InstallerProfiles.ContainsKey($installerToRun.VendorType)) {
            Write-Host "[AutoClicker] Skipping $($installerToRun.VendorType) - no profile found" -ForegroundColor Yellow
            continue
        }

        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "STARTING: $($installerToRun.VendorType)" -ForegroundColor Cyan
        Write-Host "========================================`n" -ForegroundColor Cyan

        # Run the installer and any launched apps sequentially
        $queuedInstallers = @()
        $queuedInstallers += @{
            VendorType = $installerToRun.VendorType
            Path = $installerToRun.Path
        }

        while ($queuedInstallers.Count -gt 0) {
            Write-Host "`n[DEBUG] ============ QUEUE LOOP ITERATION ============" -ForegroundColor Cyan
            Write-Host "[DEBUG] Queue size: $($queuedInstallers.Count)" -ForegroundColor Magenta
            Write-Host "[DEBUG] Queue contents: $($queuedInstallers | ForEach-Object { $_.VendorType } | Out-String)" -ForegroundColor Magenta
            Write-Host "[DEBUG] Completed installers: $($script:CompletedInstallers -join ', ')" -ForegroundColor Magenta

            $currentInstaller = $queuedInstallers[0]
            # Properly dequeue - if only 1 item left, make empty array
            if ($queuedInstallers.Count -eq 1) {
                $queuedInstallers = @()
            } else {
                $queuedInstallers = $queuedInstallers[1..($queuedInstallers.Count-1)]
            }

            Write-Host "[DEBUG] Dequeued: $($currentInstaller.VendorType)" -ForegroundColor Magenta
            Write-Host "[DEBUG] Queue size after dequeue: $($queuedInstallers.Count)" -ForegroundColor Magenta

            # Skip if already completed
            if ($script:CompletedInstallers -contains $currentInstaller.VendorType) {
                Write-Host "[AutoClicker] Skipping $($currentInstaller.VendorType) - already completed" -ForegroundColor Yellow
                continue
            }

            Write-Host "[DEBUG] Not in completed list, proceeding with: $($currentInstaller.VendorType)" -ForegroundColor Magenta

            try {
                Write-Host "[DEBUG] Checking if Process exists: $($currentInstaller.Process -ne $null)" -ForegroundColor Magenta
                $profile = $Global:InstallerProfiles[$currentInstaller.VendorType]
                Write-Host "[DEBUG] Profile loaded: $($profile.WindowTitles -join ', ')" -ForegroundColor Magenta

                $process = $null
                $windowHandle = [IntPtr]::Zero

                if ($currentInstaller.Process) {
                    # Already launched (e.g., launched app)
                    Write-Host "[DEBUG] Using existing process for $($currentInstaller.VendorType)" -ForegroundColor Magenta
                    $process = $currentInstaller.Process
                    Write-Host "[DEBUG] Process ID: $($process.Id), HasExited: $($process.HasExited)" -ForegroundColor Magenta

                    # Get window handle
                    Write-Host "[DEBUG] Waiting 2 seconds before getting window handle..." -ForegroundColor Magenta
                    Start-Sleep -Seconds 2
                    Write-Host "[DEBUG] Calling Get-WindowHandleByProcess for ProcessId: $($process.Id)" -ForegroundColor Magenta
                    $windowHandle = Get-WindowHandleByProcess -ProcessId $process.Id -WindowTitles $profile.WindowTitles
                    Write-Host "[DEBUG] Window handle obtained: $windowHandle" -ForegroundColor Magenta
                }
                elseif ($currentInstaller.Path) {
                    # Launch new process from path
                    Write-Host "[DEBUG] Launching new process from path: $($currentInstaller.Path)" -ForegroundColor Magenta
                    $process = Start-Process $currentInstaller.Path -PassThru -ErrorAction Stop

                    # Get window handle
                    Write-Host "[DEBUG] Waiting 2 seconds before getting window handle..." -ForegroundColor Magenta
                    Start-Sleep -Seconds 2
                    Write-Host "[DEBUG] Calling Get-WindowHandleByProcess for ProcessId: $($process.Id)" -ForegroundColor Magenta
                    $windowHandle = Get-WindowHandleByProcess -ProcessId $process.Id -WindowTitles $profile.WindowTitles
                    Write-Host "[DEBUG] Window handle obtained: $windowHandle" -ForegroundColor Magenta
                }
                else {
                    # App already running, find by window title (for StartApps launched apps)
                    Write-Host "[DEBUG] No process or path provided. Finding window by title for $($currentInstaller.VendorType)" -ForegroundColor Magenta

                    # Retry finding window with longer waits (StartApps apps take time to launch)
                    $maxWindowRetries = 15
                    $windowFound = $false

                    for ($retry = 0; $retry -lt $maxWindowRetries; $retry++) {
                        Write-Host "[DEBUG] Searching for window (attempt $($retry + 1)/$maxWindowRetries)..." -ForegroundColor Gray
                        Start-Sleep -Seconds 2

                        # Find window handle by title patterns
                        $windowHandle = Get-WindowHandleByProcess -ProcessId 0 -WindowTitles $profile.WindowTitles

                        if ($windowHandle -ne [IntPtr]::Zero) {
                            Write-Host "[DEBUG] Found window handle: $windowHandle" -ForegroundColor Green
                            $windowFound = $true

                            # Try to get process from window handle
                            try {
                                [uint32]$processId = 0
                                [Win32.User32]::GetWindowThreadProcessId($windowHandle, [ref]$processId) | Out-Null
                                if ($processId -gt 0) {
                                    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
                                    Write-Host "[DEBUG] Found process ID from window: $processId" -ForegroundColor Green
                                }
                            }
                            catch {
                                Write-Warning "[DEBUG] Could not get process from window handle: $($_.Exception.Message)"
                            }
                            break
                        }
                    }

                    if (-not $windowFound) {
                        Write-Warning "[DEBUG] Could not find window for $($currentInstaller.VendorType) after $maxWindowRetries retries"
                        throw "Window not found for automation"
                    }
                }

                $installer = @{
                    VendorType = $currentInstaller.VendorType
                    Profile = $profile
                    CurrentStep = 0
                    Process = $process
                    ProcessId = if ($process) { $process.Id } else { 0 }
                    WindowHandle = $windowHandle
                    LastAction = (Get-Date)
                    Completed = $false
                }

                Write-Host "[DEBUG] Starting main automation loop for $($installer.VendorType)" -ForegroundColor Cyan
                Start-Sleep -Seconds 3
                $loopCount = 0
                $maxLoops = 1800

                # Process this installer until completion
                while (-not $installer.Completed -and $loopCount -lt $maxLoops) {
                    if ($loopCount % 10 -eq 0) {
                        Write-Host "[DEBUG] Loop iteration $loopCount - Step $($installer.CurrentStep)/$($installer.Profile.Steps.Count)" -ForegroundColor DarkGray
                    }
                    $profile = $installer.Profile

                    # Check if we completed pre-programmed steps and should start template matching phase
                    if ($installer.CurrentStep -ge $profile.Steps.Count -and -not $installer.TemplatePhaseStarted) {
                        Write-Host "[$($installer.VendorType)] Phase 1 (Pre-programmed steps) completed!" -ForegroundColor Green

                        # Check if there's a TemplateFolder for Phase 2
                        if ($profile.TemplateFolder) {
                            Write-Host "[$($installer.VendorType)] Starting Phase 2 (Template Matching)..." -ForegroundColor Cyan
                            $installer.TemplatePhaseStarted = $true
                            $installer.TemplatePhaseStep = 1
                            $installer.TemplateRetryCount = 0
                            $installer.TemplateMaxRetries = 30  # Max retries per template
                            # Don't mark as completed yet, continue to template phase
                        }
                        else {
                            # No template folder, mark as completed
                            $installer.Completed = $true
                        }

                        if ($profile.LaunchApp -and -not $installer.TemplatePhaseStarted) {
                    # Wait for shortcuts/files to be created
                    Write-Host "[$($installer.VendorType)] Installation complete. Attempting to launch app..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 5
                    $launched = $false
                    $maxRetries = 10
                    $launchedProcess = $null

                    # Check if using StartApps method
                    if ($profile.LaunchApp -is [string] -and $profile.LaunchApp.StartsWith("StartApps:")) {
                        $appName = $profile.LaunchApp.Substring(10)  # Remove "StartApps:" prefix
                        Write-Host "[$($installer.VendorType)] Using Get-StartApps to find: $appName" -ForegroundColor Cyan

                        for ($retry = 0; $retry -lt $maxRetries -and -not $launched; $retry++) {
                            $msiApp = Get-StartApps | Where-Object { $_.Name -like "*$appName*" } | Select-Object -First 1

                            if ($msiApp) {
                                Write-Host "[$($installer.VendorType)] Found app with ID: $($msiApp.AppID)" -ForegroundColor Green
                                try {
                                    Start-Process "shell:AppsFolder\$($msiApp.AppID)" -ErrorAction Stop
                                    $launched = $true

                                    # For StartApps, we don't have a process handle, so we need to find it by window
                                    # Wait a moment for app to start
                                    Start-Sleep -Seconds 2

                                    # If LaunchAppProfile is specified, queue without process (will find by window title)
                                    if ($profile.LaunchAppProfile -and $Global:InstallerProfiles.ContainsKey($profile.LaunchAppProfile)) {
                                        Write-Host "[$($installer.VendorType)] Queueing launched app for automation: $($profile.LaunchAppProfile)" -ForegroundColor Cyan
                                        $queuedInstallers += @{
                                            VendorType = $profile.LaunchAppProfile
                                            Process = $null  # Will find by window title
                                        }
                                    }
                                }
                                catch {
                                    Write-Warning "[$($installer.VendorType)] Failed to launch app: $($_.Exception.Message)"
                                }
                            } else {
                                if ($retry -lt ($maxRetries - 1)) {
                                    Write-Host "[$($installer.VendorType)] App not registered yet, retry $($retry + 1)/$maxRetries..." -ForegroundColor Yellow
                                    Start-Sleep -Seconds 2
                                }
                            }
                        }

                        if (-not $launched) {
                            Write-Warning "[$($installer.VendorType)] $appName is not installed or not registered yet."
                        }
                    }
                    elseif ($profile.LaunchApp -is [array]) {
                        # Try to find and launch app with retries
                        for ($retry = 0; $retry -lt $maxRetries -and -not $launched; $retry++) {
                            foreach ($appPath in $profile.LaunchApp) {
                                # Expand environment variables
                                $expandedPath = [System.Environment]::ExpandEnvironmentVariables($appPath)
                                Write-Host "[$($installer.VendorType)] Checking: $expandedPath" -ForegroundColor Gray
                                if (Test-Path $expandedPath) {
                                    Write-Host "[$($installer.VendorType)] Found! Launching: $expandedPath" -ForegroundColor Green
                                    $launchedProcess = Start-Process $expandedPath -PassThru -ErrorAction SilentlyContinue
                                    $launched = $true

                                    # If LaunchAppProfile is specified, queue the launched app
                                    if ($profile.LaunchAppProfile -and $Global:InstallerProfiles.ContainsKey($profile.LaunchAppProfile)) {
                                        Write-Host "[$($installer.VendorType)] Queueing launched app for automation: $($profile.LaunchAppProfile)" -ForegroundColor Cyan
                                        $queuedInstallers += @{
                                            VendorType = $profile.LaunchAppProfile
                                            Process = $launchedProcess
                                        }
                                    }
                                    break
                                }
                            }
                            if (-not $launched -and $retry -lt ($maxRetries - 1)) {
                                Write-Host "[$($installer.VendorType)] App not found yet, retry $($retry + 1)/$maxRetries..." -ForegroundColor Yellow
                                Start-Sleep -Seconds 2
                            }
                        }
                        if (-not $launched) {
                            Write-Host "[$($installer.VendorType)] Failed to find app after $maxRetries retries" -ForegroundColor Red
                        }
                    } else {
                        # Single path with retries
                        for ($retry = 0; $retry -lt $maxRetries -and -not $launched; $retry++) {
                            $expandedPath = [System.Environment]::ExpandEnvironmentVariables($profile.LaunchApp)
                            Write-Host "[$($installer.VendorType)] Checking: $expandedPath" -ForegroundColor Gray
                            if (Test-Path $expandedPath) {
                                Write-Host "[$($installer.VendorType)] Found! Launching: $expandedPath" -ForegroundColor Green
                                $launchedProcess = Start-Process $expandedPath -PassThru -ErrorAction SilentlyContinue
                                $launched = $true

                                # If LaunchAppProfile is specified, queue the launched app
                                if ($profile.LaunchAppProfile -and $Global:InstallerProfiles.ContainsKey($profile.LaunchAppProfile)) {
                                    Write-Host "[$($installer.VendorType)] Queueing launched app for automation: $($profile.LaunchAppProfile)" -ForegroundColor Cyan
                                    $queuedInstallers += @{
                                        VendorType = $profile.LaunchAppProfile
                                        Process = $launchedProcess
                                    }
                                }
                            } else {
                                if ($retry -lt ($maxRetries - 1)) {
                                    Write-Host "[$($installer.VendorType)] App not found yet, retry $($retry + 1)/$maxRetries..." -ForegroundColor Yellow
                                    Start-Sleep -Seconds 2
                                }
                            }
                        }
                        if (-not $launched) {
                            Write-Host "[$($installer.VendorType)] Failed to find app after $maxRetries retries" -ForegroundColor Red
                        }
                    }
                        }
                        continue
                    }

                    # ========== PHASE 2: TEMPLATE MATCHING ==========
                    if ($installer.TemplatePhaseStarted) {
                        # Refresh window handle
                        if ($installer.WindowHandle -eq [IntPtr]::Zero -or $loopCount % 50 -eq 0) {
                            $newHandle = Get-WindowHandleByProcess -ProcessId $installer.ProcessId -WindowTitles $profile.WindowTitles
                            if ($newHandle -ne [IntPtr]::Zero) {
                                $installer.WindowHandle = $newHandle
                            }
                        }

                        # Check if window is available
                        if ($installer.WindowHandle -eq [IntPtr]::Zero) {
                            Write-Host "[$($installer.VendorType)] Template Phase: Waiting for window..." -ForegroundColor Yellow
                            Start-Sleep -Milliseconds 1000
                            $loopCount++
                            continue
                        }

                        # Re-find window if RefindWindowEachStep is enabled (for multi-window installers)
                        if ($profile.RefindWindowEachStep) {
                            $newWindowHandle = Get-WindowHandleByProcess -ProcessId $process.Id -WindowTitles $profile.WindowTitles
                            if ($newWindowHandle -ne [IntPtr]::Zero -and $newWindowHandle -ne $installer.WindowHandle) {
                                Write-Host "[$($installer.VendorType)] Switched to new window (Handle: $newWindowHandle)" -ForegroundColor Cyan
                                $installer.WindowHandle = $newWindowHandle
                                $windowHandle = $newWindowHandle
                            }
                        }

                        # Build template path
                        $templateName = "step$($installer.TemplatePhaseStep)"
                        $templateFolder = Join-Path $script:PSScriptRoot "ScreenshotTemplates"
                        $subfolderPath = Join-Path $templateFolder $profile.TemplateFolder
                        $templatePath = Join-Path $subfolderPath "$templateName.png"

                        Write-Host "[$($installer.VendorType)] Template Phase: Looking for template at: $templatePath" -ForegroundColor Gray

                        # Check if template exists
                        if (-not (Test-Path $templatePath)) {
                            Write-Host "[$($installer.VendorType)] Template Phase: No more templates found (looking for: $templateName.png in $subfolderPath)" -ForegroundColor Cyan
                            Write-Host "[$($installer.VendorType)] Template Phase completed!" -ForegroundColor Green
                            $installer.Completed = $true
                            continue
                        }

                        # Try to match template
                        Write-Host "[$($installer.VendorType)] Template Phase: Trying $templateName (attempt $($installer.TemplateRetryCount + 1)/$($installer.TemplateMaxRetries))..." -ForegroundColor Cyan

                        try {
                            $screenshot = Capture-WindowScreenshot -WindowHandle $installer.WindowHandle
                            if ($screenshot) {
                                $template = [System.Drawing.Image]::FromFile($templatePath)
                                $match = Find-TemplateInImage -Screenshot $screenshot -Template $template

                                $template.Dispose()
                                $screenshot.Dispose()

                                if ($match -and $match.Found) {
                                    # Template found! Click it
                                    Write-Host "[$($installer.VendorType)] Template $templateName found with confidence $($match.Confidence)" -ForegroundColor Green

                                    $rect = New-Object WindowOps+RECT
                                    [WindowOps]::GetWindowRect($installer.WindowHandle, [ref]$rect) | Out-Null

                                    $clickX = $rect.Left + $match.X
                                    $clickY = $rect.Top + $match.Y

                                    Write-Host "[$($installer.VendorType)] Clicking at ($clickX, $clickY)" -ForegroundColor Green
                                    [WindowOps]::Click($clickX, $clickY)
                                    Start-Sleep -Seconds 2

                                    # Move to next template
                                    $installer.TemplatePhaseStep++
                                    $installer.TemplateRetryCount = 0
                                    Write-Host "[$($installer.VendorType)] Moving to step$($installer.TemplatePhaseStep)" -ForegroundColor Cyan
                                }
                                else {
                                    # Template not found, scroll down and retry
                                    $installer.TemplateRetryCount++
                                    Write-Host "[$($installer.VendorType)] Template $templateName not found (retry $($installer.TemplateRetryCount)/$($installer.TemplateMaxRetries))" -ForegroundColor Yellow

                                    # Scroll down to reveal more content (every 2 retries)
                                    if ($installer.TemplateRetryCount % 2 -eq 1) {
                                        Write-Host "[$($installer.VendorType)] Scrolling down to look for template..." -ForegroundColor Cyan
                                        try {
                                            # Set focus to window and send TAB keys to change focus/scroll content
                                            [WindowOps]::SetForegroundWindow($installer.WindowHandle) | Out-Null
                                            Start-Sleep -Milliseconds 200

                                            # Send TAB key multiple times to navigate through elements and change window content
                                            Add-Type -AssemblyName System.Windows.Forms
                                            for ($i = 0; $i -lt 5; $i++) {
                                                [System.Windows.Forms.SendKeys]::SendWait("{TAB}")
                                                Start-Sleep -Milliseconds 100
                                            }
                                            Start-Sleep -Milliseconds 300
                                        }
                                        catch {
                                            Write-Host "[$($installer.VendorType)] Scroll failed: $($_.Exception.Message)" -ForegroundColor Yellow
                                        }
                                    }

                                    if ($installer.TemplateRetryCount -ge $installer.TemplateMaxRetries) {
                                        Write-Host "[$($installer.VendorType)] Max retries reached for $templateName, moving to next template" -ForegroundColor Yellow
                                        $installer.TemplatePhaseStep++
                                        $installer.TemplateRetryCount = 0
                                    }
                                }
                            }
                        }
                        catch {
                            Write-Host "[$($installer.VendorType)] Template Phase error: $($_.Exception.Message)" -ForegroundColor Red
                        }

                        Start-Sleep -Milliseconds 1000
                        $loopCount++
                        continue
                    }

                    # ========== PHASE 1: PRE-PROGRAMMED STEPS ==========
                    $currentStep = $profile.Steps[$installer.CurrentStep]
                    if (((Get-Date) - $installer.LastAction).TotalSeconds -lt 0.3) { continue }

                    # Refresh window handle if needed (windows may change, e.g., NVIDIA spawns new window)
                    # PERFORMANCE FIX: Only refresh every 50 loops (25 seconds) instead of every 10 loops
                    if ($installer.WindowHandle -eq [IntPtr]::Zero -or $loopCount % 50 -eq 0) {
                        $newHandle = Get-WindowHandleByProcess -ProcessId $installer.ProcessId -WindowTitles $profile.WindowTitles
                        if ($newHandle -ne [IntPtr]::Zero) {
                            $installer.WindowHandle = $newHandle
                        }
                    }

                    # If ClickOCR, ClickCoordinates, or ClickTemplate action, inject WindowHandle and ProfileFolder into step
                    if ($currentStep.Action -eq "ClickOCR" -or $currentStep.Action -eq "ClickCoordinates" -or $currentStep.Action -eq "ClickTemplate") {
                        $currentStep.WindowHandle = $installer.WindowHandle

                        # Inject ProfileFolder for template matching if available
                        if ($currentStep.Action -eq "ClickTemplate" -and $profile.TemplateFolder) {
                            $currentStep.ProfileFolder = $profile.TemplateFolder
                        }
                    }

                    $window = $null
                    # PERFORMANCE FIX: Only search for window if we need UI Automation (not for OCR/ClickCoordinates)
                    # This avoids expensive automation searches when we already have WindowHandle for OCR
                    # NOTE: SendKeys DOES need UI Automation window to call SetFocus()
                    $needsUIAutomation = ($currentStep.Action -ne "ClickOCR" -and $currentStep.Action -ne "ClickCoordinates" -and
                                          $currentStep.Action -ne "ClickTemplate" -and $currentStep.Action -ne "Wait" -and
                                          $currentStep.Action -ne "KillProcess" -and $currentStep.Action -ne "LaunchProcess")

                    if ($needsUIAutomation) {
                        foreach ($windowTitle in $profile.WindowTitles) {
                            # Find-AutomationWindow is called without debug
                            $candidateWindow = Find-AutomationWindow -WindowTitle $windowTitle -ShowDebug $false
                            if ($candidateWindow) {

                                # REMOVED VENDOR EXCLUSION LOGIC FOR SILENT OPERATION (Less needed without debug)

                                if ($profile.RequireButtons) {
                                    $allButtonsCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
                                    $buttons = $candidateWindow.FindAll([System.Windows.Automation.TreeScope]::Descendants, $allButtonsCondition)
                                    if ($buttons.Count -eq 0) {
                                        # REMOVED DEBUG POPUP HERE
                                        continue
                                    }
                                }
                                $window = $candidateWindow
                                # REMOVED DEBUG POPUP HERE
                                break
                            }
                        }
                    }

                    # For OCR, ClickCoordinates, ClickTemplate, Wait, and other non-UI actions, we don't need UI Automation window
                    # SendKeys DOES need a window, so it's not in this list
                    if ($currentStep.Action -eq "ClickOCR" -or $currentStep.Action -eq "ClickCoordinates" -or
                        $currentStep.Action -eq "ClickTemplate" -or $currentStep.Action -eq "Wait" -or
                        $currentStep.Action -eq "KillProcess" -or $currentStep.Action -eq "LaunchProcess" -or $window) {
                        # REMOVED DEBUG POPUP HERE
                        try {
                            Write-Host "[DEBUG] Executing step $($installer.CurrentStep + 1): $($currentStep.Action)" -ForegroundColor DarkGray
                            # Execute-AutoClickerStep is called without debug
                            if (Execute-AutoClickerStep -Step $currentStep -Window $window -WindowHandle $windowHandle -ShowDebug $false) {
                                Write-Host "[$($installer.VendorType)] Step $($installer.CurrentStep + 1)/$($profile.Steps.Count) completed: $($currentStep.Action)" -ForegroundColor Green
                                $installer.CurrentStep++
                                # REMOVED DEBUG POPUP HERE
                            } else {
                                Write-Host "[$($installer.VendorType)] Step $($installer.CurrentStep + 1)/$($profile.Steps.Count) failed: $($currentStep.Action)" -ForegroundColor Yellow
                                # REMOVED DEBUG POPUP HERE
                            }
                        } catch {
                            Write-Host "[$($installer.VendorType)] Step $($installer.CurrentStep + 1)/$($profile.Steps.Count) error: $($_.Exception.Message)" -ForegroundColor Red
                        }
                        $installer.LastAction = (Get-Date)
                    } else {
                        Write-Host "[DEBUG] Waiting for window/step conditions - Action: $($currentStep.Action), Window: $($window -ne $null)" -ForegroundColor DarkGray
                    }
                    # REMOVED FINAL DEBUG POPUP FOR CANNOT FIND WINDOW
                # PERFORMANCE FIX: Increased from 500ms to 800ms to reduce CPU usage
                Start-Sleep -Milliseconds 800
                $loopCount++
            }

            # Mark as completed
            Write-Host "[DEBUG] Marking as completed: $($currentInstaller.VendorType)" -ForegroundColor Magenta
            $script:CompletedInstallers += $currentInstaller.VendorType
            Write-Host "[DEBUG] Completed installers list: $($script:CompletedInstallers -join ', ')" -ForegroundColor Magenta

            Write-Host "`n========================================" -ForegroundColor Green
            Write-Host "COMPLETED: $($installer.VendorType)" -ForegroundColor Green
            Write-Host "========================================`n" -ForegroundColor Green

            } catch {
                Write-Host "`n[AutoClicker] ERROR with $($currentInstaller.VendorType):" -ForegroundColor Red
                Write-Host "Error Message: $_" -ForegroundColor Red
                Write-Host "Error Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
                Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
                # Still mark as completed to prevent retry
                Write-Host "[DEBUG] Marking as completed (error case): $($currentInstaller.VendorType)" -ForegroundColor Magenta
                $script:CompletedInstallers += $currentInstaller.VendorType
                Write-Host "[DEBUG] Completed installers list: $($script:CompletedInstallers -join ', ')" -ForegroundColor Magenta
            }
        }

        Write-Host "[DEBUG] Exited queue loop for $($installerToRun.VendorType)" -ForegroundColor Magenta
        Write-Host "[DEBUG] Final queue size: $($queuedInstallers.Count)" -ForegroundColor Magenta
    }
}

function Initialize-GlobalColors {

    [System.Drawing.Color]$global:colorPending = [System.Drawing.Color]::FromArgb(255, 211, 211, 211) # LightGray
    [System.Drawing.Color]$global:colorOK = [System.Drawing.Color]::FromArgb(255, 76, 175, 80) # Green
    [System.Drawing.Color]$global:colorWarning = [System.Drawing.Color]::FromArgb(255, 255, 165, 0) # Amber
    [System.Drawing.Color]$global:colorDarkerWarning = [System.Drawing.Color]::FromArgb(255, 255, 165, 0) # Orange
    [System.Drawing.Color]$global:colorError = [System.Drawing.Color]::FromArgb(255, 244, 67, 54) # Red
    [System.Drawing.Color]$global:colorInfo = [System.Drawing.Color]::FromArgb(255, 33, 150, 243) # Blue
    [System.Drawing.Color]$global:colorDetected = [System.Drawing.Color]::FromArgb(255, 63, 81, 181) # Indigo
    [System.Drawing.Color]$global:colorChecking = [System.Drawing.Color]::FromArgb(255, 55, 71, 79) # Dark Gray-Blue
    [System.Drawing.Color]$global:colorFailed = [System.Drawing.Color]::FromArgb(255, 183, 28, 28) # Dark Red
    [System.Drawing.Color]$global:colorSuccess = [System.Drawing.Color]::FromArgb(255, 56, 142, 60) # Dark Green
    [System.Drawing.Color]$global:colorInProgress = [System.Drawing.Color]::FromArgb(255, 255, 165, 0) # Orange
    [System.Drawing.Color]$global:colorCheckError = [System.Drawing.Color]::FromArgb(255, 255, 87, 34) # Deep Orange
    [System.Drawing.Color]$global:colorGold = [System.Drawing.Color]::FromArgb(255, 255, 223, 0) # Gold

}

function Get-SafeColor {
    param(
        [System.Drawing.Color]$Color,
        [System.Drawing.Color]$DefaultColor = [System.Drawing.Color]::Gray
    )
    if ($null -ne $Color) {
        return $Color
    }
    else {
        Write-Warning "Get-SafeColor: Input color was null. Returning default color."
        return $DefaultColor
    }
}

function Update-Status {
    param(
        [string]$message,
        [System.Drawing.Color]$passedColor = $global:colorPending
    )
    if ($form -and -not $form.IsDisposed -and $statusLabel -and -not $statusLabel.IsDisposed) {
        $finalColor = Get-SafeColor $passedColor
        $form.Invoke([Action]{
            $statusLabel.Text = "Status: $message"
            try {
                $statusLabel.ForeColor = $finalColor
                if ($finalColor -eq $global:colorFailed) {
                    $statusLabel.Font = New-Object System.Drawing.Font($defaultFont, 9, [System.Drawing.FontStyle]::Bold)
                }
                else {
                    $statusLabel.Font = New-Object System.Drawing.Font($defaultFont, 9)
                }
            }
            catch {
                Write-Warning "Failed to set ForeColor/Font in Update-Status. Color was '$($finalColor | Out-String -Stream)'. Error: $($_.Exception.Message)"
                $statusLabel.ForeColor = [System.Drawing.Color]::Black
                $statusLabel.Font = New-Object System.Drawing.Font($defaultFont, 9)
            }
        })
    }
    Write-Host "UI Status: $message"
}

function Update-ProgressBar {
    param([int]$value)
    if ($form -and -not $form.IsDisposed -and $progressBar -and -not $progressBar.IsDisposed) {
        $form.Invoke([Action]{
            if ($value -ge $progressBar.Minimum -and $value -le $progressBar.Maximum) {
                $progressBar.Value = $value
            }
            elseif ($value -lt $progressBar.Minimum) {
                $progressBar.Value = $progressBar.Minimum
            }
            else { # $value > $progressBar.Maximum
                $progressBar.Value = $progressBar.Maximum
            }
        })
    }
}

function Execute-InstallerProcess {
    param(
        [Parameter(Mandatory = $true)][string]$InstallerPath,
        [Parameter(Mandatory = $false)][string]$Arguments,
        [Parameter(Mandatory = $false)][string]$DisplayName = "",
        [Parameter(Mandatory = $false)][string]$DeviceType = ""
    )
    try {
        if (-not (Test-Path $InstallerPath)) {
            Write-Warning "Installer not found: $InstallerPath"
            Show-Popup -Message "Installer not found:`n$InstallerPath" -Title "Installer Error"
            return $false
        }

        Update-Status "Launching installer: $DisplayName..." $global:colorInProgress

        $startProcessParams = @{
            FilePath    = $InstallerPath
            WindowStyle = 'Normal'
        }
        if (-not [string]::IsNullOrWhiteSpace($Arguments)) {
            $startProcessParams.ArgumentList = $Arguments
        }

        Start-Process @startProcessParams

        Update-Status "Launched: $DisplayName" $global:colorSuccess
        return $true
    }
    catch {
        Write-Warning "Failed to launch installer process for '$InstallerPath'. Error: $($_.Exception.Message)"
        Show-Popup -Message "Failed to launch installer:`n$InstallerPath`nError: $($_.Exception.Message)" -Title "Installer Error"
        return $null
    }
}



function Detect-IsLaptop {

    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if ($null -ne $battery) {

            return $true
        }

        $enclosure = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $enclosure) {
            $laptopChassisTypes = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
            foreach ($type in $enclosure.ChassisTypes) {
                if ($laptopChassisTypes -contains $type) {

                    return $true
                }
            }
        }

        return $false
    }
    catch {
        Write-Warning "An error occurred during laptop detection: $($_.Exception.Message). Assuming desktop."
        return $false
    }
}

function Get-MotherboardInfo {

    try {
        $mbInfo = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop
        $manufacturer = $mbInfo.Manufacturer
        $product = $mbInfo.Product

        $normalizedManufacturer = switch -Wildcard ($manufacturer) {
            "*ASUS*"              { "Asustek" }
            "*ASUSTEK*"           { "Asustek" }
            "*GIGA*BYTE*"         { "Gigabyte" }
            "*MSI*"               { "MSI" }
            "*Micro-Star*"        { "MSI" }
            "*ASRock*"            { "ASRock" }
            "*LENOVO*"            { "Lenovo" }
            "*DELL INC*"          { "Dell" }
            "*ACER*"              { "Acer" }
            "*RPL*"               { "Acer" }
            "*HP*"                { "HP" }
            "*HEWLETT-PACKARD*"   { "HP" }
            default               { $manufacturer.Trim() }
        }

        Return [PSCustomObject]@{
            Manufacturer           = $manufacturer
            Product                = $product
            NormalizedManufacturer = $normalizedManufacturer
            OriginalObject         = $mbInfo
        }
    }
    catch {
        Write-Warning "Error detecting motherboard: $($_.Exception.Message)"
        Return $null
    }
}

function Get-GpuInfo {

    $gpus = @()
    try {
        $pnpDisplayDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object { $_.Present -eq [bool]$true }

        if (-not $pnpDisplayDevices) {
            Write-Warning "No PnP devices found for Display class. Trying Win32_VideoController."
            $videoControllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
            $pnpDisplayDevices = foreach ($controller in $videoControllers) {
                [PSCustomObject]@{
                    FriendlyName = $controller.Name
                    Caption      = $controller.Description
                    InstanceId   = $controller.PNPDeviceID
                    HardwareID   = $controller.PNPDeviceID
                }
            }
        }

        foreach ($device in $pnpDisplayDevices) {
            $vendorName = "Unknown"
            $hardwareIdString = if ($device.HardwareID -is [array]) { $device.HardwareID -join ';' } elseif ($device.HardwareID) { $device.HardwareID } else { "" }


            if ($hardwareIdString -match "VEN_10DE") { $vendorName = "NVIDIA" }
            elseif ($hardwareIdString -match "VEN_1002") { $vendorName = "AMD" }
            elseif ($hardwareIdString -match "VEN_8086") { $vendorName = "Intel" }

            $gpus += [PSCustomObject]@{
                Name        = $device.FriendlyName
                Description = $device.Caption
                Vendor      = $vendorName
                PNPDeviceID = $device.InstanceId
                HardwareID  = $hardwareIdString
            }

        }

        if ($gpus.Count -eq 0) {
            Write-Warning "No GPUs conclusively identified."
            return $null
        }

        $physicalGpus = $gpus | Where-Object { $_.Vendor -ne "Unknown" }

        if ($physicalGpus.Count -gt 0) {

            return $physicalGpus
        }
        else {

            return $gpus # Return the original list if no physical GPU was found
        }
    }
    catch {
        Write-Warning "Error detecting GPUs: $($_.Exception.Message)"
        Return $null
    }
}

function Discover-WifiBtHardware {

    $Global:WifiBtHardwareDetected = [bool]$false
    $Global:WifiBtDetectedName = "Not Detected"
    $Global:WifiBtDriverFolderHint = $null

    $allPnpDevices = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.Present -eq [bool]$true }
    if (-not $allPnpDevices) {
        Write-Warning "Could not retrieve PnP devices."
        return
    }

    $knownWifiPatterns = @(
        @{ Vendor = "8086"; Device = "2723"; Name = "Intel AX200"; DriverFolder = "Intel" },
        @{ Vendor = "8086"; Device = "2725"; Name = "Intel AX201/AX211 family"; DriverFolder = "Intel" },
        @{ Vendor = "8086"; Device = "7AF0"; Name = "Intel AX210"; DriverFolder = "Intel" },
        @{ Vendor = "51F0"; Name = "Intel AX211"; DriverFolder = "Intel" },
        @{ Vendor = "08A2"; Name = "Intel BE202"; DriverFolder = "Intel_BE" },
        @{ Vendor = "14C3"; Device = "7961"; Name = "MediaTek MT7921"; DriverFolder = "MediaTek_MT7921" },
        @{ Vendor = "14C3"; Device = "0616"; Name = "MediaTek MT7922 (RZ616)"; DriverFolder = "MediaTek_MT7922" },
        @{ Vendor = "10EC"; Device = "B852"; Name = "TP-Link Archer TX20E (Realtek RTL8852BE)"; DriverFolder = "Realtek_RTL8852BE_TX20E" },
        @{ Vendor = "10EC"; Device = "8852"; Name = "Realtek RTL8852AE/CE (Wi-Fi 6)"; DriverFolder = "Realtek_RTL8852AE" },
        @{ Vendor = "10EC"; Device = "F822"; Name = "Realtek RTL8852CE (Wi-Fi 6E)"; DriverFolder = "Realtek_RTL8852CE" }
    )
    $knownBtPatterns = @(
        @{ Vendor = "8087"; Product = "0026"; Name = "Intel Bluetooth"; DriverFolder = "Intel" },
        @{ Vendor = "8087"; Product = "0029"; Name = "Intel AX200/AX201 Bluetooth"; DriverFolder = "Intel" },
        @{ Vendor = "8087"; Product = "0032"; Name = "Intel AX210/AX211 Bluetooth"; DriverFolder = "Intel" },
        @{ Vendor = "8087"; Product = "0033"; Name = "Intel AX210/AX211 Bluetooth"; DriverFolder = "Intel" },
        @{ Vendor = "8087"; Product = "0036"; Name = "Intel BE200/BE202 Bluetooth"; DriverFolder = "Intel_BE" },
        @{ Vendor = "0E8D"; Product = "0616"; Name = "MediaTek MT7922 Bluetooth"; DriverFolder = "MediaTek_MT7922" },
        @{ Vendor = "13D3"; Product = "3570"; Name = "TP-Link Archer TX20E Bluetooth (AzureWave module)"; DriverFolder = "Realtek_RTL8852BE_TX20E" },
        @{ Vendor = "0BDA"; Product = "B852"; Name = "Realtek Bluetooth (RTL8852BE based)"; DriverFolder = "Realtek_RTL8852BE" },
        @{ Vendor = "0BDA"; Product = "8852"; Name = "Realtek Bluetooth (RTL8852AE based)"; DriverFolder = "Realtek_RTL8852AE" },
        @{ Vendor = "0BDA"; Product = "C822"; Name = "Realtek Bluetooth (RTL8852CE based)"; DriverFolder = "Realtek_RTL8852CE" }
    )

    $detectedWifiDeviceName = ""
    $detectedBtDeviceName = ""
    $wifiDriverHint = $null
    $btDriverHint = $null
    $foundSpecificWifi = [bool]$false
    $foundSpecificBt = [bool]$false

    foreach ($pattern in $knownWifiPatterns) {
        $regex = "PCI\\VEN_$($pattern.Vendor)`&DEV_$($pattern.Device)"
        $device = $allPnpDevices | Where-Object { $_.Class -eq 'Net' -and ($_.HardwareID -join ';') -match $regex -and $_.Status -eq 'OK' } | Select-Object -First 1
        if ($device) {
            $detectedWifiDeviceName = $pattern.Name
            $wifiDriverHint = $pattern.DriverFolder
            $foundSpecificWifi = [bool]$true

            break
        }
    }

    foreach ($pattern in $knownBtPatterns) {
        $regex = "USB\\VID_$($pattern.Vendor)`&PID_$($pattern.Product)"
        $device = $allPnpDevices | Where-Object { ($_.HardwareID -join ';') -match $regex -and $_.Status -eq 'OK' } | Select-Object -First 1
        if ($device) {
            $detectedBtDeviceName = $pattern.Name
            $btDriverHint = $pattern.DriverFolder
            $foundSpecificBt = [bool]$true

            break
        }
    }

    if (-not $foundSpecificWifi) {
        $genericWifi = $allPnpDevices | Where-Object {
            $_.Class -eq 'Net' -and $_.Status -eq 'OK' -and $_.Present -eq [bool]$true -and
            ($_.FriendlyName -like "*Wi-Fi*" -or $_.FriendlyName -like "*Wireless*" -or $_.Service -match "netrwn|athw|rtwlan|mtkwl|iwx|mwl")
        } | Select-Object -First 1
        if ($genericWifi) {
            $detectedWifiDeviceName = "Generic Wi-Fi Adapter ($($genericWifi.FriendlyName))"
            if (($genericWifi.HardwareID -join ';') -match "VEN_8086") { $wifiDriverHint = "Intel" }
            elseif (($genericWifi.HardwareID -join ';') -match "VEN_14C3") { $wifiDriverHint = "MediaTek" }
            elseif (($genericWifi.HardwareID -join ';') -match "VEN_10EC") { $wifiDriverHint = "Realtek" }
            elseif (($genericWifi.HardwareID -join ';') -match "VEN_168C") { $wifiDriverHint = "QualcommAtheros" }

        }
    }

    if (-not $foundSpecificBt) {
        $genericBt = $allPnpDevices | Where-Object {
            $_.Class -eq 'Bluetooth' -and $_.Status -eq "OK" -and $_.Present -eq [bool]$true
        } | Select-Object -First 1
        if (-not $genericBt) {
            $genericBt = $allPnpDevices | Where-Object {
                ($_.Class -eq 'USBDevice' -or $_.Class -eq 'USB' -or $_.FriendlyName -like "*Bluetooth*") -and ($_.FriendlyName -like "*Bluetooth*" -or $_.Service -match "BTHUSB|ibtusb") -and $_.Status -eq "OK" -and $_.Present -eq [bool]$true
            } | Select-Object -First 1
        }
        if ($genericBt) {
            $detectedBtDeviceName = "Generic Bluetooth Adapter ($($genericBt.FriendlyName))"
            if (($genericBt.HardwareID -join ';') -match "VID_8087") { $btDriverHint = "Intel" }
            elseif (($genericBt.HardwareID -join ';') -match "VID_0E8D") { $btDriverHint = "MediaTek" }
            elseif (($genericBt.HardwareID -join ';') -match "VID_0BDA") { $btDriverHint = "Realtek" }
            elseif (($genericBt.HardwareID -join ';') -match "VID_0A5C") { $btDriverHint = "Broadcom" }
            elseif (($genericBt.HardwareID -join ';') -match "VID_13D3") { $btDriverHint = "AzureWave_Generic" }

        }
    }

    if ($detectedWifiDeviceName -or $detectedBtDeviceName) {
        $Global:WifiBtHardwareDetected = [bool]$true
        $names = @()
        if ($detectedWifiDeviceName) { $names += $detectedWifiDeviceName }
        if ($detectedBtDeviceName) { $names += $detectedBtDeviceName }
        $Global:WifiBtDetectedName = ($names -join " & ")

        if ($wifiDriverHint -and $btDriverHint) {
            if ($wifiDriverHint -eq $btDriverHint) {
                $Global:WifiBtDriverFolderHint = $wifiDriverHint
            }
            else {

            }
        }
        elseif ($wifiDriverHint) {
            $Global:WifiBtDriverFolderHint = $wifiDriverHint
        }
        elseif ($btDriverHint) {
            $Global:WifiBtDriverFolderHint = $btDriverHint
        }
        else {
            $Global:WifiBtDriverFolderHint = "Generic"
        }

    }
    else {

    }
}

function Get-CpuInfo {

    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $manufacturer = $cpu.Manufacturer

        if ($manufacturer -match "AMD") {
            $Global:CpuManufacturer = "AMD"
        }
        elseif ($manufacturer -match "Intel") {
            $Global:CpuManufacturer = "Intel"
        }
        else {
            $Global:CpuManufacturer = "Other"
        }

    }
    catch {
        Write-Warning "Error detecting CPU: $($_.Exception.Message)"
        $Global:CpuManufacturer = "Unknown"
    }
}

function Detect-OfficeInstallation {

    $Global:OfficeIsActuallyInstalled = [bool](
        (Test-Path "C:\Program Files\Microsoft Office" -PathType Container -ErrorAction SilentlyContinue) -or
        (Test-Path "C:\Program Files (x86)\Microsoft Office" -PathType Container -ErrorAction SilentlyContinue) -or
        ((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "Microsoft Office*" -or ($_.Publisher -like "Microsoft Corporation" -and $_.DisplayName -like "*Office*") }).Count -gt 0)
    )

}



function Check-UnassignedDrives {

    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "This script must be run with Administrator privileges."
        return $true
    }

    try {
        $physicalDisks = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object { $_.MediaType -eq 'Fixed hard disk media' }
        if ($null -eq $physicalDisks) {
            return $true # No disks means nothing to fix.
        }
        $uninitializedDisks = $physicalDisks | Where-Object { $_.Partitions -eq 0 }
        if ($uninitializedDisks) {
            return $false # A fix is needed
        }
    }
    catch {
        Write-Warning "WMI CHECK: An error occurred while checking drives: $($_.Exception.Message)"
        return $true # Assume OK if the check itself errors out.
    }
    return $true
}

function Get-NextAvailableDriveLetter {
    $usedLetters = Get-Volume | ForEach-Object { $_.DriveLetter }
    $possibleLetters = [char[]]([int][char]'D'..[int][char]'Z')
    foreach ($letter in $possibleLetters) {
        if ($letter -notin $usedLetters) {
            return $letter
        }
    }
    return $null
}

function Fix-UnassignedDrives {
    Update-Status "Configuring uninitialized drives..." $global:colorChecking
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Update-Status "Administrator privileges required." $global:colorError
        return $false
    }

    # First, eject removable drives to free up drive letters
    try {
        $removableDrives = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter }
        foreach ($vol in $removableDrives) {
            $letter = $vol.DriveLetter
            Write-Host "[DISKPART] Ejecting removable drive $letter`: to free up letter..." -ForegroundColor Yellow
            $ejectScript = @"
select volume $letter
remove
exit
"@
            $ejectPath = [System.IO.Path]::Combine($env:TEMP, "diskpart-eject-$letter.txt")
            $ejectScript | Out-File -FilePath $ejectPath -Encoding ascii
            diskpart.exe /s $ejectPath 2>&1 | Out-Null
            Remove-Item $ejectPath -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "[DISKPART] Warning: Could not eject removable drives: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    $disksToProcess = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object { $_.MediaType -eq 'Fixed hard disk media' -and $_.Partitions -eq 0 }
    if ($disksToProcess.Count -eq 0) {
        Update-Status "No unassigned drives found to fix." $global:colorSuccess
        return $true
    }
    $allFixed = $true
    foreach ($disk in $disksToProcess) {
        $diskNumber = $disk.Index
        $scriptPath = $null
        try {
            Update-Status "Processing Disk $diskNumber with DISKPART..." $global:colorInProgress
            Write-Host "[DISKPART] Configuring Disk $diskNumber..." -ForegroundColor Cyan

            $driveLetter = Get-NextAvailableDriveLetter
            if (-not $driveLetter) { throw "No available drive letters found." }

            Write-Host "[DISKPART] Assigning letter: $driveLetter" -ForegroundColor Green

            $diskpartScript = @"
select disk $diskNumber
online disk noerr
attributes disk clear readonly noerr
clean
convert gpt noerr
create partition primary noerr
format fs=ntfs label="Local Disk" quick noerr
assign letter=$driveLetter noerr
exit
"@
            $scriptPath = [System.IO.Path]::Combine($env:TEMP, "diskpart-script-$diskNumber.txt")
            $diskpartScript | Out-File -FilePath $scriptPath -Encoding ascii

            # Run diskpart and capture output for debugging
            $diskpartOutput = diskpart.exe /s $scriptPath 2>&1
            Write-Host "[DISKPART] Output: $diskpartOutput" -ForegroundColor Gray

            # Check if critical operations succeeded (ignore "already online" warnings)
            $criticalSuccess = $diskpartOutput -match "successfully (formatted|assigned|converted|created)"
            $criticalFailure = $diskpartOutput -match "DiskPart has encountered an error|failed to|cannot|could not"

            if ($criticalFailure -or -not $criticalSuccess) {
                throw "Diskpart failed to complete critical operations"
            }

            Write-Host "[DISKPART] Disk $diskNumber configured successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host "[DISKPART] Error configuring Disk $diskNumber`: $($_.Exception.Message)" -ForegroundColor Red
            Update-Status "Error configuring Disk $diskNumber." $global:colorFailed
            $allFixed = $false
        }
        finally {
            if ($scriptPath -and (Test-Path $scriptPath)) {
                Remove-Item $scriptPath -Force
            }
        }
    }
    try { Update-HostStorageCache } catch { }
    Start-Sleep -Seconds 5
    if ($allFixed -and (Check-UnassignedDrives)) {
        Update-Status "All extra drives configured successfully." $global:colorSuccess
        return $true
    }
    else {
        Update-Status "Failed to configure one or more drives." $global:colorError
        return $false
    }
}

function Check-LaptopDisplayTimeout {
    try {
        $activeSchemeGuid = (powercfg /getactivescheme | Select-String 'GUID:').Line.Split(' ')[3]
        if (-not $activeSchemeGuid) { return $false }
        $subgroupDisplayGuid = "7516b95f-f776-4464-8c53-06167f40cc99"
        $settingVideoIdleGuid = "3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e"
        $queryResult = powercfg /query $activeSchemeGuid $subgroupDisplayGuid $settingVideoIdleGuid
        $acSettingLine = $queryResult | Select-String -Pattern "Current AC Power Setting Index"
        if ($acSettingLine) {
            $acValueHex = ($acSettingLine.Line.Split(':')[-1]).Trim()
            $acValueSeconds = [System.Convert]::ToInt32($acValueHex, 16)
            return ($acValueSeconds -eq 0)
        }
    }
    catch { }
    return $false
}

function Set-LaptopDisplayTimeout {
    Update-Status "Setting display timeout to 'Never' (when plugged in)..." $global:colorChecking
    try {
        powercfg /change monitor-timeout-ac 0
        Start-Sleep -Seconds 1
        if (Check-LaptopDisplayTimeout) {
            Update-Status "Display timeout set to 'Never'." $global:colorSuccess
            return $true
        }
        else {
            Update-Status "Failed to verify display timeout change." $global:colorFailed
            return $false
        }
    }
    catch {
        Update-Status "Error setting display timeout." $global:colorFailed
        return $false
    }
}

function Get-InstallerPath {
    param(
        [string]$BasePath,
        [string]$ManufacturerOrVendorOrFolder,
        [string]$SpecificFileName = ""
    )
    if ([string]::IsNullOrWhiteSpace($BasePath)) { return $null }
    $targetFolder = if ([string]::IsNullOrWhiteSpace($ManufacturerOrVendorOrFolder) -or $ManufacturerOrVendorOrFolder -eq ".") {
        $BasePath
    }
    else {
        Join-Path $BasePath $ManufacturerOrVendorOrFolder
    }
    if (Test-Path $targetFolder) {
        if (-not [string]::IsNullOrWhiteSpace($SpecificFileName)) {
            $fullPath = Join-Path $targetFolder $SpecificFileName
            if (Test-Path $fullPath) { return $fullPath }
        }
        return Get-ChildItem -Path $targetFolder -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -eq ".exe" -or $_.Extension -eq ".msi" } |
            Select-Object -First 1 | ForEach-Object { $_.FullName }
    }
    return $null
}

function Invoke-DriverInstallation {
    param(
        [System.Collections.Generic.List[hashtable]]$SelectedInstallers = $null
    )

    # If no selected installers provided, use all required installers
    if ($null -eq $SelectedInstallers) {
        $requiredInstallers = $Global:InstallerQueue | Where-Object { $_.IsOptional -eq $false }
    } else {
        $requiredInstallers = $SelectedInstallers
    }

    if ($requiredInstallers.Count -gt 0) {
        $buttonCheck.Enabled = $false; $buttonActivate.Enabled = $false; $buttonFinalize.Enabled = $false
        if ($buttonInstallDrivers) { $buttonInstallDrivers.Enabled = $false }
        if ($buttonOptionalInstallers) { $buttonOptionalInstallers.Enabled = $false }
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        Update-Status "Automatically launching required hardware installers..." $global:colorChecking
        if ($global:AutoClickEnabled) {
            $installerList = @()
            foreach ($installerObj in $requiredInstallers) {
                $installerList += @{
                    Path = $installerObj.InstallerPath
                    VendorType = if ($installerObj.DeviceType -eq "Motherboard") {
                        $installerObj.DisplayName -replace ' Drivers', ''
                    } elseif ($installerObj.DeviceType -eq "GPU") {
                        $installerObj.DisplayName -replace ' GPU Driver', ''
                    } elseif ($installerObj.DeviceType -eq "Wi-Fi/Bluetooth" -and $installerObj.DriverFolderHint) {
                        $installerObj.DriverFolderHint
                    } else {
                        $installerObj.DisplayName
                    }
                }
            }
            Start-AutoClickerForInstallers -Installers $installerList
            Update-Status "Auto-clicker completed all installers." $global:colorSuccess
        }
        else {
            foreach ($installerObj in $requiredInstallers) {
                if ($form.IsDisposed) { return }
                Execute-InstallerProcess -InstallerPath $installerObj.InstallerPath -Arguments $installerObj.Arguments -DisplayName $installerObj.DisplayName -DeviceType $installerObj.DeviceType
            }
            Update-Status "All installers launched. Complete setups, then run checks." $global:colorWarning
            Show-Popup -Message "All required installers have been launched. Please complete each installation manually." -Title "Installers Launched"
        }
        $buttonCheck.Enabled = $true; $buttonActivate.Enabled = (-not [string]::IsNullOrWhiteSpace($textBoxIdInput.Text))
        $buttonFinalize.Enabled = (-not [string]::IsNullOrWhiteSpace($textBoxIdInput.Text))
        if ($buttonInstallDrivers) { $buttonInstallDrivers.Enabled = $true }
        if ($buttonOptionalInstallers) { $buttonOptionalInstallers.Enabled = $true }
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
    else {
        Update-Status "No required installers found to run." $global:colorSuccess
        Show-Popup -Message "Hardware detection complete. No mandatory installers were found." -Title "No Installers"
    }
}

function Find-IdFromUsb {
    try {
        $usbDrives = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter }
        foreach ($drive in $usbDrives) {
            $idFilePath = Join-Path -Path ($drive.DriveLetter + ":\") -ChildPath "diaxxa_id.txt"
            if (Test-Path $idFilePath) {
                $id = Get-Content -Path $idFilePath | Select-Object -First 1
                $trimmedId = $id.Trim()
                if (-not [string]::IsNullOrWhiteSpace($trimmedId)) {
                    return $trimmedId
                }
            }
        }
    }
    catch { }
    return $null
}

function Check-GpuApp {
    $paths = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432NODE\Microsoft\Windows\CurrentVersion\Uninstall\*")
    $apps = $paths | ForEach-Object { Get-ItemProperty $_ -ErrorAction SilentlyContinue } | Where-Object { $_.DisplayName -like "*NVIDIA*" -or $_.DisplayName -like "*Adrenalin*" -or $_.DisplayName -like "*AMD Software*" -or $_.DisplayName -like "*Intel Arc Control*" -or $_.DisplayName -like "*Intel Graphics Command Center*" }
    $folderCheck = (Test-Path "C:\Program Files\AMD\CNext") -or (Test-Path "C:\Program Files\NVIDIA Corporation") -or (Test-Path "C:\Program Files\Intel\Intel(R) Graphics Command Center") -or (Test-Path "C:\Program Files (x86)\Intel\Intel(R) Graphics Command Center")
    return [bool]($apps -or $folderCheck)
}

function Check-MotherboardApp {
    $paths = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432NODE\Microsoft\Windows\CurrentVersion\Uninstall\*")
    $apps = $paths | ForEach-Object { Get-ItemProperty $_ -ErrorAction SilentlyContinue } | Where-Object { $_.DisplayName -like "*Armoury Crate*" -or $_.DisplayName -like "*MSI Center*" -or $_.DisplayName -like "*Gigabyte Control Center*" -or $_.DisplayName -like "*ASRock*" -or $_.DisplayName -like "*Dragon Center*" }
    $folders = @("C:\Program Files (x86)\ASUS\Armoury Crate Lite Service", "C:\Program Files\ASUS\ARMOURY CRATE Lite Service", "C:\Program Files (x86)\MSI\MSI Center", "C:\Program Files\GIGABYTE\Control Center") | ForEach-Object { Test-Path $_ } | Where-Object { $_ }
    return [bool]($apps -or $folders)
}

function Check-WifiDriver {
    if (-not $Global::WifiBtHardwareDetected) { return $true }
    return [bool](Get-PnpDevice -Class Net -EA SilentlyContinue | Where-Object { ($_.FriendlyName -like "*Wi-Fi*" -or $_.FriendlyName -like "*Wireless*") -and $_.Status -eq "OK" -and $_.Present })
}

function Check-BluetoothDriver {
    if (-not $Global::WifiBtHardwareDetected) { return $true }
    return [bool](Get-PnpDevice -Class Bluetooth -EA SilentlyContinue | Where-Object { $_.Status -eq "OK" -and $_.Present })
}

function Set-PowerPlan {
    Update-Status "Setting Power Plan..." $global:colorChecking
    $planGuid = if ($Global:CpuManufacturer -eq "AMD") { "381b4222-f694-41f0-9685-ff5bb260df2e" } else { "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" }
    try {
        powercfg /SetActive $planGuid | Out-Null
        Update-Status "Power Plan set." $global:colorSuccess; return $true
    }
    catch {
        Update-Status "Error setting power plan." $global:colorFailed; return $false
    }
}

function Check-PowerPlan {
    $activeGuid = ((powercfg /GetActiveScheme) -split ' ')[3]
    $expectedGuids = if ($Global:CpuManufacturer -eq "AMD") { @("381b4222-f694-41f0-9685-ff5bb260df2e") } else { @("8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c", "e9a42b02-d5df-448d-aa00-03f14749eb61") }
    return $expectedGuids -contains $activeGuid
}

function Check-DeviceManagerErrors {
    $ignore = @("Monitor", "Keyboard", "Mouse", "USB", "System", "")
    $errors = Get-CimInstance Win32_PnPEntity -EA SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -ne 0 -and $_.ConfigManagerErrorCode -ne 22 -and $_.PNPClass -notin $ignore }
    if ($errors) {
        $details = $errors | ForEach-Object { "Device: $($_.Name), Class: $($_.PNPClass), Status: Error" } | Out-String
        Write-Warning "Device Manager Errors Detected:`n$details"
        [System.Windows.Forms.MessageBox]::Show("Device Manager Errors Detected:`n$details", "Device Manager Alert", "OK", "Warning") | Out-Null
        return $details
    }
    return $null
}

function Check-EdgeDataCleared {
    $downloadsPath = "$env:USERPROFILE\Downloads"
    $edgeHistoryPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
    return (-not (Test-Path $edgeHistoryPath)) -and ((-not (Test-Path $downloadsPath)) -or ((Get-ChildItem $downloadsPath -Force -EA SilentlyContinue).Count -eq 0))
}

function Clear-EdgeData {
    Update-Status "Clearing Edge data and downloads..." $global:colorChecking
    try { Get-Process -Name "msedge" -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue; Start-Sleep 2 } catch { }
    $edgeProfilePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
    if (Test-Path $edgeProfilePath) {
        @("History*", "Favicons*", "Top Sites*", "Shortcuts*", "Cache", "Code Cache", "GPUCache", "Service Worker\CacheStorage") | ForEach-Object {
            Remove-Item (Join-Path $edgeProfilePath $_) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    if (Test-Path "$env:USERPROFILE\Downloads") {
        Get-ChildItem "$env:USERPROFILE\Downloads" -Force -EA SilentlyContinue | Remove-Item -Recurse -Force -EA SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
    if (Check-EdgeDataCleared) { Update-Status "Traces cleared." $global:colorSuccess; return $true }
    else { Update-Status "Trace clearing incomplete." $global:colorFailed; return $false }
}

function Check-LearnAboutPicture {
    return -not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{2cc5ca98-6485-489a-920e-b3e88a6ccce3}")
}

function Fix-LearnAboutPicture {
    Update-Status "Removing 'Learn about this picture' icon..." $global:colorChecking
    try {
        Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -Recurse -Force -EA Stop
        $shell = New-Object -ComObject Shell.Application; $shell.RefreshAppDir()
        Update-Status "'Learn about this picture' icon removed." $global:colorSuccess; return $true
    }
    catch {
        Update-Status "Error removing 'Learn about this picture'." $global:colorFailed; return $false
    }
}

function Check-OfficeDesktopShortcuts {
    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    return (Test-Path (Join-Path $desktopPath "Microsoft Word.lnk")) -and (Test-Path (Join-Path $desktopPath "Microsoft Excel.lnk")) -and (Test-Path (Join-Path $desktopPath "Microsoft PowerPoint.lnk"))
}

function Set-OfficeDesktopShortcuts {
    Update-Status "Creating Office shortcuts..." $global:colorChecking
    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    $officePath = "C:\Program Files\Microsoft Office\root\Office16"
    if (-not (Test-Path $officePath)) { $officePath = "C:\Program Files (x86)\Microsoft Office\root\Office16" }
    $apps = @{ "Microsoft Word" = "WINWORD.EXE"; "Microsoft Excel" = "EXCEL.EXE"; "Microsoft PowerPoint" = "POWERPNT.EXE" }
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        foreach ($name in $apps.Keys) {
            $exePath = Join-Path $officePath $apps[$name]
            if (Test-Path $exePath) {
                $shortcut = $WshShell.CreateShortcut((Join-Path $desktopPath "$name.lnk"))
                $shortcut.TargetPath = $exePath
                $shortcut.Save()
            }
        }
        Update-Status "Office shortcuts created." $global:colorSuccess; return $true
    }
    catch {
        Update-Status "Failed to create Office shortcuts." $global:colorFailed; return $false
    }
}

function Check-Timezone {
    return (Get-TimeZone).Id -eq "GTB Standard Time"
}

function Set-TimezoneGTB {
    Update-Status "Setting timezone to GTB Standard Time..." $global:colorChecking
    try {
        Set-TimeZone -Id "GTB Standard Time" -ErrorAction Stop
        Update-Status "Timezone set to GTB Standard Time." $global:colorSuccess; return $true
    }
    catch {
        Update-Status "Failed to set timezone." $global:colorFailed; return $false
    }
}

function Check-CustomDesktopBackground {
    $expectedPath = Join-Path $script:PSScriptRoot "Desktop Background\desktop.png"
    $currentPath = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -ErrorAction SilentlyContinue
    return $currentPath.Wallpaper -eq $expectedPath
}

function Set-CustomDesktopBackground {
    Update-Status "Setting custom desktop background..." $global:colorChecking
    $imagePath = Join-Path $script:PSScriptRoot "Desktop Background\desktop.png"
    if (-not (Test-Path $imagePath)) { Update-Status "Custom background image not found." $global:colorError; return $false }
    try {
        [Wallpaper]::Set($imagePath)
        Start-Sleep -Seconds 2
        Update-Status "Custom desktop background set." $global:colorSuccess; return $true
    }
    catch {
        Update-Status "Error setting custom background." $global:colorFailed; return $false
    }
}





function Validate-KeyFormat($key) {
    return $key -match '^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$'
}

function Invoke-HardwareIdentification {
    Update-Status "Identifying hardware via API..." $global:colorChecking
    $hardwareLogPayload = Write-HardwareLog -ID "API_IDENTIFY" -ReturnAsString $true
    if (-not $hardwareLogPayload) {
        Update-Status "Failed to generate hardware log for API." $global:colorError
        return $null
    }
    $url = "$($global:apiURL_Base)&action=identify"
    try {
        $rawResponse = Invoke-RestMethod -Uri $url -Method Post -Body $hardwareLogPayload -ContentType "text/plain" -ErrorAction Stop
        if ($rawResponse -is [string]) {
            return $rawResponse | ConvertFrom-Json
        }
        return $rawResponse
    }
    catch {
        Update-Status "Error identifying hardware via API." $global:colorError
        return $null
    }
}

function Get-AvailableUsers {

    try {
        $url = "$($global:apiURL_Base)&action=identify"

        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop


        if ($response.availableSoftwareUsers) {

            foreach ($user in $response.availableSoftwareUsers) {

            }
            return $response.availableSoftwareUsers
        }
        throw "API response did not contain availableSoftwareUsers."
    }
    catch {
        Write-Warning "Failed to fetch user list from API. Error: $($_.Exception.Message)"
        return @()
    }
}

function Invoke-ConfirmIdentity {
    param(
        [string]$Identity,
        [string]$SoftwareInstallBy = ""
    )

    Update-Status "Confirming ID '$Identity' with API..." $global:colorChecking
    $url = "$($global:apiURL_Base)&action=confirmidentify&identity=$Identity"

    if (-not [string]::IsNullOrWhiteSpace($SoftwareInstallBy)) {
        $url += "&softwareInstallBy=$SoftwareInstallBy"

    }


    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop

        if ($response -is [string]) {
            $response = $response | ConvertFrom-Json
        }

        if ($response.status) {
            Update-Status "ID '$Identity' confirmed with server." $global:colorSuccess
            return $response
        } else {
            throw "API response indicated failure during confirmation."
        }
    }
    catch {
        Update-Status "Failed to confirm ID '$Identity'." $global:colorError
        Write-Warning "Error in Invoke-ConfirmIdentity: $($_.Exception.Message)"
        return $null
    }
}

function Invoke-RequestKeys {
    param([string]$Identity, [string]$OSName)

    Update-Status "Requesting keys for ID '$Identity'..." $global:colorChecking
    [System.Windows.Forms.Application]::DoEvents()

    $encodedOS = [System.Web.HttpUtility]::UrlEncode($OSName)
    $url = "$($global:apiURL_Base)&action=requestKey&identity=$Identity&os=$encodedOS"

    Write-Host "[DIAGNOSTIC] Calling API: $url with POST"

    $body = @{
        requestKey = "1"
    }

    try {

        $rawResponse = Invoke-RestMethod -Uri $url -Method Post -Body $body -ErrorAction Stop
        [System.Windows.Forms.Application]::DoEvents()

        if ($rawResponse -is [string]) {
            return $rawResponse | ConvertFrom-Json
        }
        else {
            return $rawResponse
        }
    }
    catch {
        Update-Status "Failed to request keys for ID '$Identity'." $global:colorError
        [System.Windows.Forms.Application]::DoEvents()
        return $null
    }
}

function Report-BlockedKey {
    param(
        [string]$Identity,
        [string]$ErrorCode,
        [string]$Model = "windows-11-pro-retail",
        [string]$Reason = "The activation server determined that the specified product key is blocked"
    )

    Update-Status "Reporting blocked key to API for ID: $Identity..." $global:colorInProgress

    try {
        $encodedReason = [System.Web.HttpUtility]::UrlEncode($Reason)
        $url = "$($global:apiURL_Base)&action=reportkey&identity=$Identity&model=$Model&reason=$encodedReason&errorCode=$ErrorCode"

        Write-Host "[ACTION] Calling key report API: $url with POST"

        $body = @{
            requestKey = "1"
        }

        Invoke-RestMethod -Uri $url -Method Post -Body $body -TimeoutSec 30 -ErrorAction Stop | Out-Null

        Update-Status "Blocked key reported successfully." $global:colorSuccess
        return $true
    }
    catch {
        Update-Status "Failed to report blocked key via API." $global:colorError
        Write-Warning "Error in Report-BlockedKey: $($_.Exception.Message)"
        return $false
    }
}

$script:ActivationErrorCodes = @{
    "0xC004F074" = "The Software Licensing Service reported that the product key is invalid."
    "0xC004F075" = "The Software Licensing Service reported that the operation cannot be completed because the service is stopping."
    "0xC004F038" = "The Software Licensing Service reported that the product key does not match any of the partial product keys found on the system."
    "0xC004F050" = "The Software Licensing Service reported that the product key is invalid."
    "0xC004F025" = "Access denied: the requested action requires elevated privileges."
    "0xC004E028" = "The Software Licensing Service reported that the activation server is busy."
    "0xC004F014" = "The Software Licensing Service reported that the product key is not available."
    "0xC004F02C" = "The Software Licensing Service reported that the format for the offline activation data is incorrect."
    "0xC004F035" = "The Software Licensing Service reported that the computer could not be activated with a Volume license product key."
    "0xC004F041" = "The Software Licensing Service determined that the Key Management Server (KMS) is not enabled."
    "0xC004F056" = "The Software Licensing Service reported that the product key cannot be used to activate this edition of Windows."
    "0xC004C008" = "The activation server determined that the specified product key is blocked."
    "0xC004C003" = "The activation server determined that the specified product key has been blocked for this geographic location."
    "0xC004C060" = "The activation server determined that the specified product key cannot be used."
    "0x8007232B" = "DNS name does not exist (KMS server not found)."
    "0x8007007E" = "The specified module could not be found."
}

function Get-ActivationErrorDescription {
    param([string]$ErrorCode)

    if ($script:ActivationErrorCodes.ContainsKey($ErrorCode)) {
        return $script:ActivationErrorCodes[$ErrorCode]
    }
    return "Unknown activation error"
}

function Initialize-LicensingServices {
    Update-Status "Verifying licensing services..." $global:colorInProgress

    $services = @("LicenseManager", "wuauserv")
    $result = @()
    $failedCount = 0

    foreach ($serviceName in $services) {
        $serviceStatus = @{
            "serviceName"  = $serviceName
            "status"       = ""
            "errorMessage" = ""
        }

        try {

            $serviceExists = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if (-not $serviceExists) {

                $serviceStatus["status"] = "not found"
                $serviceStatus["errorMessage"] = "Service does not exist on this system"
                $result += , $serviceStatus
                continue
            }

            Set-Service -Name $serviceName -StartupType Automatic -ErrorAction Stop

            $service = Get-Service -Name $serviceName -ErrorAction Stop
            if ($service.Status -eq 'Running') {
                $serviceStatus["status"] = "already running"

            }
            else {

                Start-Service -Name $serviceName -ErrorAction Stop

                Start-Sleep -Seconds 2
                $service = Get-Service -Name $serviceName -ErrorAction Stop
                if ($service.Status -eq 'Running') {
                    $serviceStatus["status"] = "started"

                }
                else {
                    $serviceStatus["status"] = "failed to start"
                    $serviceStatus["errorMessage"] = "Service started but not running (Status: $($service.Status))"
                    $failedCount++
                }
            }
        }
        catch {
            $serviceStatus["status"] = "failed"
            $serviceStatus["errorMessage"] = "Error: $($_.Exception.Message)"
            $failedCount++

        }

        $result += , $serviceStatus
    }

    foreach ($serviceResult in $result) {
        $serviceName = $serviceResult.serviceName
        $status = $serviceResult.status
        $errorMsg = $serviceResult.errorMessage

        if ($status -eq "already running" -or $status -eq "started") {
            Update-Status "Service $serviceName`: $status" $global:colorSuccess
        }
        elseif ($status -eq "not found") {
            Update-Status "Service $serviceName`: $status (skipping)" $global:colorInfo
        }
        else {
            Update-Status "Service $serviceName`: $status - $errorMsg" $global:colorError
        }
    }

    $criticalFailures = ($result | Where-Object { $_.status -eq "failed" -or $_.status -eq "failed to start" }).Count
    $success = $criticalFailures -eq 0

    if ($success) {
        Update-Status "Licensing services verification completed successfully." $global:colorSuccess
    }
    else {
        Update-Status "Some licensing services failed to initialize properly." $global:colorError
    }

    return $success
}

function Activate-Windows {
    param([string]$Key)

    Update-Status "Preparing Windows activation..." $global:colorInProgress

    if (-not (Validate-KeyFormat $Key)) {
        Update-Status "Invalid Windows key format." $global:colorError
        return $false
    }

    if (-not (Initialize-LicensingServices)) {
        Update-Status "Failed to initialize licensing services. Activation may fail." $global:colorError

    }

    Update-Status "Starting Windows activation..." $global:colorInProgress

    try {

        $lic = Get-CimInstance -Query "SELECT LicenseStatus FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND LicenseIsAddon = 0 AND Name LIKE 'Windows%'" | Select-Object -First 1
        if ($lic.LicenseStatus -eq 1) {
            Update-Status "Windows is already activated." $global:colorSuccess
            return $true
        }

        Update-Status "Installing Windows product key..." $global:colorInProgress
        $svc = Get-WmiObject -Query "SELECT * FROM SoftwareLicensingService"
        $svc.InstallProductKey($Key) | Out-Null
        $svc.RefreshLicenseStatus() | Out-Null
        Start-Sleep -Seconds 3

        $partialProductKey = $Key.Split('-')[-1]

        $installedProduct = Get-WmiObject -Query "SELECT * FROM SoftwareLicensingProduct WHERE PartialProductKey = '$partialProductKey'"

        if (-not $installedProduct) {
            Update-Status "Could not find installed product with partial key: $partialProductKey" $global:colorError
            return $false
        }



        if ($installedProduct.LicenseStatus -eq 1) {
            Update-Status "Windows activated successfully after key installation." $global:colorSuccess
            return $true
        }

        $retryCount = 0
        $maxRetries = 5
        $retryDelay = 5 # seconds

        Update-Status "Attempting online activation..." $global:colorInProgress

        while ($retryCount -lt $maxRetries) {
            try {

                $installedProduct.Activate() | Out-Null

                Start-Sleep -Seconds 3
                $installedProduct = Get-WmiObject -Query "SELECT * FROM SoftwareLicensingProduct WHERE PartialProductKey = '$partialProductKey'"

                if ($installedProduct.LicenseStatus -eq 1) {
                    Update-Status "Windows activated successfully." $global:colorSuccess
                    return $true
                }

                break

            }
            catch [System.Runtime.InteropServices.COMException] {
                $errorCode = "0x{0:X8}" -f [Int32]($_.Exception.ErrorCode)
                $errorDescription = Get-ActivationErrorDescription $errorCode


                if ($errorCode -eq "0xC004E028") {

                    $retryCount++
                    if ($retryCount -lt $maxRetries) {
                        Update-Status "Activation server busy, retrying in $retryDelay seconds... (Attempt $($retryCount + 1)/$maxRetries)" $global:colorInProgress
                        Start-Sleep -Seconds $retryDelay
                        continue
                    }
                }

                # Check if key is blocked
                if ($errorCode -eq "0xC004C008" -or $errorCode -eq "0xC004C003") {
                    Update-Status "Key blocked by activation server: $errorDescription" $global:colorError
                    Write-Warning "Blocked key detected: $errorCode - $errorDescription"

                    # Report the blocked key (model defaults to "windows-11-pro-retail")
                    $identity = $textBoxIdInput.Text.Trim()
                    Report-BlockedKey -Identity $identity -ErrorCode $errorCode -Reason $errorDescription

                    # Show popup to request new key
                    if (Show-RequestNewKeyConfirmation) {
                        # User wants a new key, request it
                        $keyResponse = Invoke-RequestKeys -Identity $identity -OSName "Windows 11 Pro,office-2021-pro-plus-retail-offline"
                        if ($keyResponse -and $keyResponse.status) {
                            $windowsKeyObject = $keyResponse.data.productKeys | Where-Object { $_.productModel -like "*windows*" } | Select-Object -First 1
                            if ($windowsKeyObject) {
                                Update-Status "Retrying activation with new key..." $global:colorInProgress
                                # Recursive call with new key
                                return Activate-Windows -Key $windowsKeyObject.productKey
                            }
                        }
                    }
                    return $false
                }

                Update-Status "Windows activation failed: $errorDescription" $global:colorError
                Write-Warning "Activation error code: $errorCode - $errorDescription"
                return $false

            }
            catch {

                Update-Status "Windows activation failed with unexpected error." $global:colorError
                Write-Warning "Unexpected error during activation: $($_.Exception.Message)"
                return $false
            }
        }

        if ($retryCount -ge $maxRetries) {
            Update-Status "Windows activation failed after $maxRetries attempts (server busy)." $global:colorError
            return $false
        }

        $finalLic = Get-CimInstance -Query "SELECT LicenseStatus FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND LicenseIsAddon = 0 AND Name LIKE 'Windows%'" | Select-Object -First 1
        if ($finalLic.LicenseStatus -eq 1) {
            Update-Status "Windows activated successfully." $global:colorSuccess
            return $true
        }
        else {
            Update-Status "Windows activation completed but license status is not activated (Status: $($finalLic.LicenseStatus))." $global:colorError
            return $false
        }

    }
    catch {
        Update-Status "Error during Windows activation: $($_.Exception.Message)" $global:colorError
        Write-Warning "Exception in Activate-Windows: $($_.Exception.Message)"
        return $false
    }
}

function Get-CidFromServer {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutMinutes = 3,

        [Parameter(Mandatory=$false)]
        [int]$CheckIntervalSeconds = 10
    )

    Write-Host "[INFO] Starting robust CID polling."



    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $timeout = [System.TimeSpan]::FromMinutes($TimeoutMinutes)
    $cid = $null
    $attempts = 0

    while ($stopwatch.Elapsed -lt $timeout) {
        $attempts++
        [System.Windows.Forms.Application]::DoEvents()

        try {

            $remainingTime = ($timeout - $stopwatch.Elapsed).ToString("mm\:ss")
            Update-Status "Polling for CID... (Attempt $attempts, Time remaining: $remainingTime)" $global:colorInProgress
            [System.Windows.Forms.Application]::DoEvents()

            $body = @{
                requestKey = "1"
            }
            $responseObject = Invoke-RestMethod -Uri $Url -Method Post -Body $body -TimeoutSec ($CheckIntervalSeconds - 1)
            [System.Windows.Forms.Application]::DoEvents()



            if ($responseObject.status -eq $false) {
                $errorMessage = $responseObject.message -or $responseObject.error -or "Unknown server error"

                $isTemporaryError = $false
                if ($errorMessage -is [string] -and $errorMessage -like '*No keys found for this UID*') {
                    $isTemporaryError = $true
                }
                elseif ($errorMessage -is [boolean] -and $errorMessage -eq $true) {

                    $isTemporaryError = $true
                }

                if ($isTemporaryError) {

                    Write-Host "[POLLING] Server returned a temporary error: '$errorMessage'. This is expected to self-correct. Retrying..."
                }
                else {

                    Update-Status "API Error: $errorMessage" $global:colorError
                    Write-Warning "The server returned a fatal failure status: $errorMessage"
                    $stopwatch.Stop()
                    return $null # Exit function on fatal server-side error
                }
            }

            $cidFound = $null
            if ($responseObject.data -and $responseObject.data.cid) {
                $cidFound = $responseObject.data.cid

            }
            elseif ($responseObject.cid) {
                $cidFound = $responseObject.cid

            }

            if ($cidFound) {

                $cid = $cidFound -replace '[\s\-]', ''
                Update-Status "CID received successfully!" $global:colorSuccess
                Write-Host "[SUCCESS] Cleaned CID for activation: '$cid'"
                $stopwatch.Stop()
                return $cid # Exit the function and return the cleaned CID
            }
            elseif ($responseObject.status -ne $false) {

                Write-Host "[POLLING] No CID found yet. Server message: '$($responseObject.message)'. Retrying..."
            }
        }
        catch {

            Write-Warning "Polling attempt $attempts failed: $($_.Exception.Message)"
            Write-Host "[POLLING] This is normal if the server is busy or the connection is slow. Retrying..."
        }

        Start-Sleep -Seconds $CheckIntervalSeconds
    }

    $stopwatch.Stop()
    Update-Status "CID polling timed out after $TimeoutMinutes minutes." $global:colorError
    Write-Warning "Failed to retrieve CID within the specified timeout period."
    return $null # Explicitly return null on failure
}

function Retry-CidPolling {
    if (-not $global:LastCidUrl) {
        Update-Status "No previous CID URL found. Cannot retry." $global:colorError
        return $null
    }

    Update-Status "Retrying CID polling with stored URL..." $global:colorInProgress

    return Get-CidFromServer -Url $global:LastCidUrl -TimeoutMinutes 3 -CheckIntervalSeconds 10
}

function Get-IID {
    Update-Status "Getting Office Installation ID (IID)..." $global:colorInProgress
    if (-not (Test-Path $global:officePath)) {
        Update-Status "Office path not found: $($global:officePath)" $global:colorError
        return $null
    }
    try {

        $iidRaw = cscript.exe (Join-Path $global:officePath "OSPP.VBS") /dinstid | Out-String

        $iid = $null

        if ($iidRaw -match '(\d{54,63})') {
            $iid = $matches[1].Trim()

        }
        else {

        }

        if ($null -eq $iid -or ($iid.Length -ne 54 -and $iid.Length -ne 63)) {
            $length = if ($iid) { $iid.Length } else { 0 }
            $errorMsg = "Extracted IID has an invalid length ($length). Expected 54 or 63."
            Write-Host "[ERROR] $errorMsg"
            throw $errorMsg
        }

        Write-Host "[DIAGNOSTIC] Extracted clean IID: '$iid'"

        Update-Status "Office IID retrieved." $global:colorSuccess

        return $iid
    }
    catch {
        Update-Status "Failed to get Office IID." $global:colorError
        Write-Warning "Error in Get-IID: $($_.Exception.Message)"

        return $null
    }
}

function Activate-Office {
    param(
        [string]$Identity,
        [PSCustomObject]$KeyObject
    )
    Write-Host "MARKER 1: Entering Activate-Office function."

    if (-not $KeyObject -or -not $KeyObject.productKey -or -not $KeyObject.activationMethod) {
        Update-Status "Invalid key object passed to Activate-Office." $global:colorError
        Write-Warning "KeyObject or required fields are null."
        return $false
    }

    Write-Host "MARKER 2: KeyObject is valid. Assigning variables."
    $Key = $KeyObject.productKey
    $ActivationMethod = $KeyObject.activationMethod

    Update-Status "Activating Office (Method: $ActivationMethod)..." $global:colorInProgress
    Write-Host "MARKER 3: Running OSPP.VBS with /inpkey..."
    cscript.exe (Join-Path $global:officePath "OSPP.VBS") /inpkey:$Key | Out-Null

    Write-Host "MARKER 4: Checking if activation method is 'ALT'."
    if ($ActivationMethod -eq 'ALT') {
        Write-Host "MARKER 5: Method is 'ALT'. Calling Get-IID..."
        $iidResult = Get-IID

        Write-Host "MARKER 6: Returned from Get-IID. Checking if IID is valid."



        if ($iidResult -is [array]) {

            $iid = $null
            foreach ($item in $iidResult) {
                $itemStr = [string]$item
                if ($itemStr -match '^\s*\d{54,63}\s*$') {
                    $iid = $itemStr.Trim()
                    break
                }
            }

        }
        else {
            $iid = [string]$iidResult
        }

        if ($iid) {
            $iid = $iid.Trim()

        }

        if (-not $iid -or [string]::IsNullOrWhiteSpace($iid)) {
            Update-Status "Aborting Office activation; IID could not be retrieved or is empty." $global:colorError
            return $false
        }

        Write-Host "MARKER 7: IID is valid. Building URL."
        $global:LastCidUrl = "$($global:apiURL_Base)&action=initiateCid&identity=$Identity&iid=$iid"
        Write-Host "[DIAGNOSTIC] Full URL being requested: $global:LastCidUrl"

        $cidResult = Get-CidFromServer -Url $global:LastCidUrl -TimeoutMinutes 3 -CheckIntervalSeconds 10
        Write-Host "MARKER 9: CID polling completed."

        $cid = $null
        if ($cidResult) {
            if ($cidResult -is [array]) {

                $cid = $cidResult | Where-Object { $_ -match '^\d{48,}$' } | Select-Object -First 1
            }
            else {
                $cid = [string]$cidResult
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($cid)) {
            $cid = $cid.Trim()
            Update-Status "Received CID. Activating Office..." $global:colorInProgress

            try {
                $activationResult = cscript.exe (Join-Path $global:officePath "OSPP.VBS") /actcid:$cid | Out-String

                Start-Sleep -Seconds 5
            }
            catch {
                Write-Warning "Error during CID activation: $($_.Exception.Message)"
            }
        }
        else {
            Update-Status "Failed to receive CID. You can retry CID polling manually." $global:colorError

            Write-Host "[INFO] To retry CID polling manually, run: Retry-CidPolling"
        }

    }
    else {
        Update-Status "Using standard online activation for Office..." $global:colorInfo
        cscript.exe (Join-Path $global:officePath "OSPP.VBS") /act | Out-Null
        Start-Sleep -Seconds 5
    }

    Write-Host "MARKER 10: Checking final license status."
    $finalStatus = cscript.exe (Join-Path $global:officePath "OSPP.VBS") /dstatus | Out-String
    if ($finalStatus -match "---LICENSED---") {
        Update-Status "Office activated successfully." $global:colorSuccess
        return $true
    }
    else {
        Update-Status "Office activation failed." $global:colorError
        return $false
    }
}



function Check-Activation {
    $windowsActivated = [bool]$false
    $officeActivated = [bool]$false
    try {
        $windowsLicense = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f'" -ErrorAction Stop | Where-Object { $_.LicenseStatus -eq 1 }
        $windowsActivated = [bool]($windowsLicense -ne $null)
    }
    catch {
        $windowsActivated = [bool]$false
    }
    if ($Global:OfficeIsActuallyInstalled) {
        try {
            $officeProducts = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name LIKE 'Office%'" -ErrorAction Stop | Where-Object { $_.LicenseStatus -eq 1 }
            $officeActivated = [bool]($officeProducts -ne $null)
        }
        catch {
            $officeActivated = [bool]$false
        }
    }
    return [PSCustomObject]@{
        Windows  = $windowsActivated
        Office   = $officeActivated
        Combined = ($windowsActivated -and ($Global:OfficeIsActuallyInstalled -eq $false -or $officeActivated))
    }
}

function Get-ActivationKeys {
    $windowsKey = "N/A"
    $officeKey = "N/A"
    try {
        $windowsKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
        if ([string]::IsNullOrWhiteSpace($windowsKey)) { $windowsKey = "Not found in WMI" }
    }
    catch {
        $windowsKey = "Error retrieving"
    }
    if ($Global:OfficeIsActuallyInstalled) {
        try {
            $osppPath = ""
            if (Test-Path "$($global:officePath)\OSPP.VBS") { $osppPath = "$($global:officePath)\OSPP.VBS" }
            elseif (Test-Path "C:\Program Files (x86)\Microsoft Office\Office16\OSPP.VBS") { $osppPath = "C:\Program Files (x86)\Microsoft Office\Office16\OSPP.VBS" }
            if ($osppPath) {
                $osppOutput = cscript.exe $osppPath /dstatus
                $lastKey = ($osppOutput | Select-String "Last 5 characters of installed product key:").Line -replace "Last 5 characters of installed product key: ", ""
                if ($lastKey) { $officeKey = "..." + ($lastKey -join ", ...") }
                else { $officeKey = "Not found in OSPP output" }
            }
            else {
                $officeKey = "OSPP.VBS not found"
            }
        }
        catch {
            $officeKey = "Error retrieving"
        }
    }
    else {
        $officeKey = "Office not installed"
    }
    return [PSCustomObject]@{ WindowsKey = $windowsKey; OfficeKey = $officeKey }
}

function Write-HardwareLog {
    param(
        [string]$ID,
        [bool]$IsGoldBuild = $false,
        [bool]$ReturnAsString = $false
    )
    $logFilePath = Join-Path $script:PSScriptRoot "hardware_log.txt"
    try {
        $mbInfo = Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -First 1
        $motherboardLog = "Motherboard: $($mbInfo.Manufacturer) $($mbInfo.Product)"
        $ramSticks = Get-CimInstance -ClassName Win32_PhysicalMemory
        $totalRamGB = ($ramSticks | Measure-Object -Property Capacity -Sum).Sum / 1GB
        $ramDetails = $ramSticks | ForEach-Object { "  - $([math]::Round($_.Capacity / 1GB))GB $($_.Manufacturer) $($_.Speed)MHz" } | Out-String
        $ramLog = "Ram: $($totalRamGB)GB`n$($ramDetails.Trim())"
        $allGpuInfo = Get-GpuInfo
        $gpuNames = ($allGpuInfo | ForEach-Object { $_.Name }) -join " | "
        $gpuLog = "GPU: $gpuNames"
        $cpuInfo = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
        $cpuLog = "CPU: $($cpuInfo.Name)"
        $storageInfo = Get-Disk | Where-Object { $_.BusType -ne 'USB' } | ForEach-Object {
            $diskSizeGB = [math]::Round($_.Size / 1GB)
            "  - $($_.Model) ($($diskSizeGB)GB)"
        } | Out-String
        $storageLog = "Storage:`n$($storageInfo.Trim())"
        $osInfo = Get-ComputerInfo -Property OSName, OSVersion
        $osLog = "OS: $($osInfo.OSName) ($($osInfo.OSVersion))"
        $idLine = "ID: $ID"
        if ($IsGoldBuild) { $idLine += " Asamblare Gold" }
        $logContent = @"
--------------------------------------------------
$($osLog)
$($motherboardLog)
$($ramLog)
$($gpuLog)
$($cpuLog)
$($storageLog)
$($idLine)
"@
        if ($ReturnAsString) {
            return $logContent
        }
        else {
            $logContent | Out-File -FilePath $logFilePath -Append -Encoding UTF8
            return $true
        }
    }
    catch {
        if (-not $ReturnAsString) {
            [System.Windows.Forms.MessageBox]::Show("Failed to write to the hardware log file.`nError: $($_.Exception.Message)", "Log File Error", "OK", "Error") | Out-Null
        }
        return $null
    }
}

function Invoke-ActivationOnlyProcess {
    param([string]$Identity)

    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $buttonActivate.Enabled = $false
    $buttonFinalize.Enabled = $false

    Detect-OfficeInstallation

    if ($Global:OfficeIsActuallyInstalled) {

        try {
            Set-OfficeDesktopShortcuts | Out-Null
        }
        catch {

        }
    }

    $keyResponse = Invoke-RequestKeys -Identity $Identity -OSName "Windows 11 Pro,office-2021-pro-plus-retail-offline"
    if (-not $keyResponse -or -not $keyResponse.status) {
        Show-Popup -Title "Error" -Message "Could not retrieve valid product key data for ID '$Identity'."
        $form.Cursor = [System.Windows.Forms.Cursors]::Default; $buttonActivate.Enabled = $true; $buttonFinalize.Enabled = $true
        return
    }

    $windowsKeyObject = $keyResponse.data.productKeys | Where-Object { $_.productModel -like "*windows*" } | Select-Object -First 1
    $officeKeyObject = $keyResponse.data.productKeys | Where-Object { $_.productModel -like "*office*" } | Select-Object -First 1

    if (-not $windowsKeyObject) {
        Show-Popup -Title "Error" -Message "API response did not contain a Windows product key."
        $form.Cursor = [System.Windows.Forms.Cursors]::Default; $buttonActivate.Enabled = $true; $buttonFinalize.Enabled = $true
        return
    }

    Activate-Windows -Key $windowsKeyObject.productKey

    if ($Global:OfficeIsActuallyInstalled -and $officeKeyObject) {

        Activate-Office -Identity $Identity -KeyObject $officeKeyObject
    }

    Update-Status "Finalizing and logging..." $global:colorChecking
    $activationStatus = Check-Activation
    if ($activationIndicatorPanel) { $activationIndicatorPanel.BackColor = if ($activationStatus.Combined) { $global:colorOK } else { $global:colorError } }
    $softwareTypeForLog = if ($officeKeyObject) { "windows+office" } else { "windows" }
    Write-KeyRequestLog -ID $Identity -SoftwareType $softwareTypeForLog -WindowsKey $windowsKeyObject.productKey -OfficeKey $officeKeyObject.productKey
    if ($activationStatus.Combined) {
        Update-Status "Activation successful for $Identity." $global:colorSuccess
    }
    else {
        Update-Status "Activation process completed with errors for $Identity." $global:colorError
    }

    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    $buttonActivate.Enabled = $true
    $buttonFinalize.Enabled = $true
}

function Invoke-ConfirmAndFinalizeProcess {
    param(
        [string]$Identity,
        [string]$SoftwareInstallBy = ""
    )
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $buttonActivate.Enabled = $false
    $buttonFinalize.Enabled = $false

    $confirmation = Invoke-ConfirmIdentity -Identity $Identity -SoftwareInstallBy $SoftwareInstallBy

    if (-not $confirmation) {
        Show-Popup -Title "Error" -Message "Could not confirm ID '$Identity' with the server."
    }
    else {
        $successMessage = "ID '$Identity' has been finalized on the server."
        if (-not [string]::IsNullOrWhiteSpace($SoftwareInstallBy)) {
            $successMessage += "`nInstalled by: $SoftwareInstallBy"
        }
        Show-Popup -Title "Success" -Message $successMessage
    }
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    $buttonActivate.Enabled = $true
    $buttonFinalize.Enabled = $true
}

function Write-KeyRequestLog {
    param(
        [Parameter(Mandatory = $true)][string]$ID,
        [Parameter(Mandatory = $true)][string]$SoftwareType,
        [Parameter(Mandatory = $true)][string]$WindowsKey,
        [Parameter(Mandatory = $false)][string]$OfficeKey
    )
    if ([string]::IsNullOrWhiteSpace($OfficeKey)) {
        $OfficeKey = "N/A"
    }
    $logFilePath = Join-Path $script:PSScriptRoot "DiaxxaKeysLog.txt"
    $logContent = @"
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
ðŸ“‹ Key Request Log - $(Get-Date)
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
ðŸ†” API Identity Used: $ID
ðŸ“¦ Software Confirmed: $SoftwareType
ðŸ”‘ Windows Key: $WindowsKey
ðŸ¢ Office Key: $OfficeKey
--------------------------------------------------
"@
    try {
        $logContent | Out-File -FilePath $logFilePath -Append -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to write to key request log file at '$logFilePath'. Error: $($_.Exception.Message)"
    }
}



function Invoke-EnableRemoteDesktop {
    Update-Status "Enabling Remote Desktop and sending notification..." $global:colorInProgress
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $buttonActivate.Enabled = $false; $buttonFinalize.Enabled = $false; $buttonEnableRDP.Enabled = $false

    try {
        Update-Status "Configuring RDP service and firewall..." $global:colorChecking

        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0 -Force

        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction Stop
    }
    catch {
        Update-Status "Failed to enable RDP service/firewall." $global:colorError
        Show-Popup -Title "RDP Error" -Message "Failed to enable the Remote Desktop service or configure the firewall."
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $buttonActivate.Enabled = $true; $buttonFinalize.Enabled = $true; $buttonEnableRDP.Enabled = $true
        return
    }

    try {
        Update-Status "Setting blank password policy..." $global:colorChecking
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        Set-ItemProperty -Path $regPath -Name "limitblankpassworduse" -Value 0 -Type DWord -Force
    }
    catch {
        Update-Status "Failed to set RDP security policy." $global:colorError

        Show-Popup -Title "Policy Warning" -Message "Could not set the security policy to allow blank password RDP logon. This may fail if the user has no password."
    }

    try {
        Update-Status "Sending Zulip notification..." $global:colorChecking

        $diaxxaId = $textBoxIdInput.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($diaxxaId)) {
            $diaxxaId = Find-IdFromUsb
        }

        if (-not $diaxxaId) {
            $diaxxaId = "Unknown PC"
        }

        $ipAddress = $null
        $maxWait = 60; $interval = 5
        for ($i = 0; $i -lt ($maxWait / $interval); $i++) {
            $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Ethernet*' |
                Where-Object { $_.PrefixOrigin -ne 'WellKnown' -and $_.IPAddress -ne '127.0.0.1' } |
                Select-Object -ExpandProperty IPAddress -First 1)
            if ($ipAddress) { break }
            Start-Sleep -Seconds $interval
            [System.Windows.Forms.Application]::DoEvents()
        }

        if ($ipAddress) {
            $MessageContent = "**$diaxxaId** is ready for remote desktop at [$ipAddress]."
        }
        else {
            $MessageContent = "**$diaxxaId** is online, but its IP address could not be determined."
        }

        $email = "bootsybot-bot@zulip.cel.ro"
        $apiKey = "vam5DRB46Zq6bzdI2cZkvscm1rx5OFyY"
        $recipientID = "[53]"
        $authHeader = "Basic " + [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${email}:${apiKey}"))

        $body = @{
            type    = "direct"
            to      = $recipientID
            content = $MessageContent
        }

        $bodyEncoded = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $body.GetEnumerator() | ForEach-Object { $bodyEncoded.Add($_.Key, $_.Value) }
        $bodyString = $bodyEncoded.ToString()

        Invoke-WebRequest -Uri "https://zulip.cel.ro/api/v1/messages" `
            -Method Post `
            -Headers @{ Authorization = $authHeader } `
            -Body $bodyString `
            -ContentType "application/x-www-form-urlencoded" `
            -ErrorAction Stop | Out-Null

        Update-Status "Remote Desktop enabled and notification sent." $global:colorSuccess
        Show-Popup -Title "Success" -Message "Remote Desktop has been enabled and the notification was sent to Zulip."
    }
    catch {
        Update-Status "Failed to send Zulip notification." $global:colorError
        Show-Popup -Title "Zulip Error" -Message "Failed to send the Zulip notification. Error: $($_.Exception.Message)"
    }

    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    $buttonActivate.Enabled = $true; $buttonFinalize.Enabled = $true; $buttonEnableRDP.Enabled = $true
}



function Show-RequiredInstallerDialog {
    param(
        [System.Collections.Generic.List[hashtable]]$RequiredInstallers
    )
    $dialogForm = New-Object System.Windows.Forms.Form
    $dialogForm.Text = "Select Drivers to Install"
    $dialogForm.Size = New-Object System.Drawing.Size(600, 450)
    $dialogForm.StartPosition = "CenterParent"
    $dialogForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialogForm.MinimizeBox = $false
    $dialogForm.MaximizeBox = $false
    $dialogForm.ShowInTaskbar = $false
    $dialogForm.BackColor = [System.Drawing.Color]::White
    $labelHeader = New-Object System.Windows.Forms.Label
    $labelHeader.Text = "Select drivers to install (all checked by default):"
    $labelHeader.Font = New-Object System.Drawing.Font($defaultFont, 12, [System.Drawing.FontStyle]::Bold)
    $labelHeader.Location = [System.Drawing.Point]::new(20, 15)
    $labelHeader.AutoSize = $true
    $dialogForm.Controls.Add($labelHeader)
    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Location = [System.Drawing.Point]::new(20, 50)
    $checkedListBox.Size = New-Object System.Drawing.Size(550, 300)
    $checkedListBox.CheckOnClick = $true
    $checkedListBox.Font = New-Object System.Drawing.Font($defaultFont, 9)
    $dialogForm.Controls.Add($checkedListBox)
    $installerObjectsInListBox = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($installer in $RequiredInstallers) {
        $displayItem = "$($installer.DisplayName) (Type: $($installer.DeviceType))"
        $checkedListBox.Items.Add($displayItem, $true)  # All checked by default
        $installerObjectsInListBox.Add($installer)
    }
    $buttonRunSelected = New-Object System.Windows.Forms.Button
    $buttonRunSelected.Text = "Install Selected"
    $buttonRunSelected.Size = New-Object System.Drawing.Size(140, 30)
    $buttonRunSelected.Location = [System.Drawing.Point]::new(20, 365)
    $buttonRunSelected.Font = New-Object System.Drawing.Font($defaultFont, 9, [System.Drawing.FontStyle]::Bold)
    $dialogForm.Controls.Add($buttonRunSelected)
    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = "Cancel"
    $buttonCancel.Size = New-Object System.Drawing.Size(100, 30)
    $buttonCancel.Location = [System.Drawing.Point]::new(($dialogForm.Width - $buttonCancel.Width - 40), 365)
    $buttonCancel.Font = New-Object System.Drawing.Font($defaultFont, 9)
    $dialogForm.Controls.Add($buttonCancel)
    $buttonRunSelected.Add_Click({
        $Global:SelectedInstallersFromDialog.Clear()
        foreach ($i in 0..($checkedListBox.Items.Count - 1)) {
            if ($checkedListBox.GetItemChecked($i)) {
                $itemObject = $installerObjectsInListBox[$i]
                if ($itemObject -ne $null) {
                    $Global:SelectedInstallersFromDialog.Add($itemObject)
                }
            }
        }
        $dialogForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
    })
    $buttonCancel.Add_Click({
        $dialogForm.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    })
    $dialogResult = $dialogForm.ShowDialog() | Out-Null
    $dialogForm.Dispose()
}

function Show-OptionalInstallerDialog {
    param(
        [System.Collections.Generic.List[hashtable]]$OptionalInstallers
    )
    $dialogForm = New-Object System.Windows.Forms.Form
    $dialogForm.Text = "Install Optional Software"
    $dialogForm.Size = New-Object System.Drawing.Size(600, 450)
    $dialogForm.StartPosition = "CenterParent"
    $dialogForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialogForm.MinimizeBox = $false
    $dialogForm.MaximizeBox = $false
    $dialogForm.ShowInTaskbar = $false
    $dialogForm.BackColor = [System.Drawing.Color]::White
    $labelHeader = New-Object System.Windows.Forms.Label
    $labelHeader.Text = "Select optional software to install:"
    $labelHeader.Font = New-Object System.Drawing.Font($defaultFont, 12, [System.Drawing.FontStyle]::Bold)
    $labelHeader.Location = [System.Drawing.Point]::new(20, 15)
    $labelHeader.AutoSize = $true
    $dialogForm.Controls.Add($labelHeader)
    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Location = [System.Drawing.Point]::new(20, 50)
    $checkedListBox.Size = New-Object System.Drawing.Size(550, 300)
    $checkedListBox.CheckOnClick = $true
    $checkedListBox.Font = New-Object System.Drawing.Font($defaultFont, 9)
    $dialogForm.Controls.Add($checkedListBox)
    $installerObjectsInListBox = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($installer in $OptionalInstallers) {
        $displayItem = "$($installer.DisplayName) (Type: $($installer.DeviceType))"
        $checkedListBox.Items.Add($displayItem, $false)
        $installerObjectsInListBox.Add($installer)
    }
    $buttonRunSelected = New-Object System.Windows.Forms.Button
    $buttonRunSelected.Text = "Run Selected"
    $buttonRunSelected.Size = New-Object System.Drawing.Size(120, 30)
    $buttonRunSelected.Location = [System.Drawing.Point]::new(20, 365)
    $buttonRunSelected.Font = New-Object System.Drawing.Font($defaultFont, 9, [System.Drawing.FontStyle]::Bold)
    $dialogForm.Controls.Add($buttonRunSelected)
    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = "Cancel"
    $buttonCancel.Size = New-Object System.Drawing.Size(100, 30)
    $buttonCancel.Location = [System.Drawing.Point]::new(($dialogForm.Width - $buttonCancel.Width - 40), 365)
    $buttonCancel.Font = New-Object System.Drawing.Font($defaultFont, 9)
    $dialogForm.Controls.Add($buttonCancel)
    $buttonRunSelected.Add_Click({
        $Global:SelectedInstallersFromDialog.Clear()
        foreach ($i in 0..($checkedListBox.Items.Count - 1)) {
            if ($checkedListBox.GetItemChecked($i)) {
                $itemObject = $installerObjectsInListBox[$i]
                if ($itemObject -ne $null) {
                    $Global:SelectedInstallersFromDialog.Add($itemObject)
                }
            }
        }
        $dialogForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
    })
    $buttonCancel.Add_Click({
        $dialogForm.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    })
    $dialogResult = $dialogForm.ShowDialog() | Out-Null
    $dialogForm.Dispose()
}

function Show-IdSelectionDialog {
    param(
        [object]$Matches
    )
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Multiple Matches Found"
    $dialog.Size = New-Object System.Drawing.Size(400, 300)
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Multiple possible IDs were found. Please select the correct one:"
    $label.Location = [System.Drawing.Point]::new(10, 10)
    $label.Size = New-Object System.Drawing.Size(360, 40)
    $dialog.Controls.Add($label)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = [System.Drawing.Point]::new(10, 50)
    $listBox.Size = New-Object System.Drawing.Size(360, 150)
    $dialog.Controls.Add($listBox)

    $allItems = @()
    if ($Matches.match) { $allItems += $Matches.match }
    if ($Matches.partialMatch) { $allItems += $Matches.partialMatch }

    foreach ($item in $allItems) {
        $listBox.Items.Add("$($item.id) ($($item.softwareType))")
    }

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = "Select"
    $buttonOK.Location = [System.Drawing.Point]::new(150, 220)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dialog.AcceptButton = $buttonOK
    $dialog.Controls.Add($buttonOK)

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if ($listBox.SelectedItem) {
            $selectedIndex = $listBox.SelectedIndex
            return $allItems[$selectedIndex]
        }
    }
    return $null
}


function Show-Popup {
    param(
        [string]$Message,
        [string]$Title,
        [int]$TimeoutSeconds = 6
    )
    try {
        $wshell = New-Object -ComObject WScript.Shell
        $wshell.Popup($Message, $TimeoutSeconds, $Title, 64) | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($Message, $Title, "OK", "Information") | Out-Null
    }
}

function Show-RequestNewKeyConfirmation {
    $message = "The previously used key was blocked by the activation server.`n`nDo you want to request a NEW key for this ID?`n`n(This will permanently associate a new key with this ID on the server.)"
    $title = "Confirm New Key Request"
    $buttons = [System.Windows.Forms.MessageBoxButtons]::YesNo
    $icon = [System.Windows.Forms.MessageBoxIcon]::Warning

    $result = [System.Windows.Forms.MessageBox]::Show($message, $title, $buttons, $icon)

    return $result -eq [System.Windows.Forms.DialogResult]::Yes
}



$global:apiURL_Base = "https://intern.cel.ro/an_v2/tools/index.php?page=diaxxaBuilder".Trim()
$global:officePath = "C:\Program Files\Microsoft Office\Office16"
if (-not (Test-Path $global:officePath)) {
    $global:officePath = "C:\Program Files (x86)\Microsoft Office\Office16"
}
$global:IsLaptop = $false
$global:AutoClickEnabled = $false
$scriptTitle = "Syscheck"
$defaultFont = "Segoe UI"
$driverLibraryPath = Join-Path $script:PSScriptRoot "Drivers"
$motherboardDriversPath = Join-Path $driverLibraryPath "Motherboard"
$gpuDriversPath = Join-Path $driverLibraryPath "GPU"
$wifiBtDriversPath = Join-Path $driverLibraryPath "WiFiBT"
$officeInstallerFolderPath = Join-Path $driverLibraryPath "Office"
$optionalInstallersFolderPath = Join-Path $script:PSScriptRoot "Optional"
[System.Collections.Generic.List[hashtable]]$Global:SelectedInstallersFromDialog = [System.Collections.Generic.List[hashtable]]::new()
$Global:WifiBtHardwareDetected = [bool]$false
$Global:WifiBtDetectedName = "Not Detected"
$Global:WifiBtDriverFolderHint = $null
$Global:OfficeInstallAttempted = [bool]$false
$Global:CpuManufacturer = "Unknown"
$Global:OfficeIsActuallyInstalled = [bool]$false
$Global:InstallerQueue = [System.Collections.Generic.List[hashtable]]::new()
$Global:SoftwareToActivate = "windows" # Default value

$global:IsLaptop = Detect-IsLaptop
Initialize-GlobalColors
Get-CpuInfo
Discover-WifiBtHardware
Detect-OfficeInstallation

$officeInstallerPathForQueue = Get-InstallerPath -BasePath $officeInstallerFolderPath -ManufacturerOrVendorOrFolder "."
if ($officeInstallerPathForQueue) {
    $Global:InstallerQueue.Add(@{ InstallerPath = $officeInstallerPathForQueue; DisplayName = "Microsoft Office"; DeviceType = "Software"; IsOptional = [bool]$true; RunFunction = $null })
}
if (Test-Path $optionalInstallersFolderPath) {
    $genericOptionalInstallers = Get-ChildItem -Path $optionalInstallersFolderPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq ".exe" -or $_.Extension -eq ".msi" }
    foreach ($installerFile in $genericOptionalInstallers) {
        $Global:InstallerQueue.Add(@{ InstallerPath = $installerFile.FullName; DisplayName = "$($installerFile.BaseName)"; DeviceType = "Optional"; IsOptional = [bool]$true; RunFunction = $null })
    }
}



$tempCheckItems = [System.Collections.Generic.List[hashtable]]::new()
if (-not $global:IsLaptop) {
    $tempCheckItems.Add(@{ Name = "Power Plan Set Correctly"; CheckFunction = 'Check-PowerPlan'; FixFunction = 'Set-PowerPlan' })
}
else {
    $tempCheckItems.Add(@{ Name = "Display Timeout (Plugged In) set to 'Never'"; CheckFunction = 'Check-LaptopDisplayTimeout'; FixFunction = 'Set-LaptopDisplayTimeout' })
}
$tempCheckItems.Add(@{ Name = "All Drives Initialized and Assigned"; CheckFunction = 'Check-UnassignedDrives'; FixFunction = 'Fix-UnassignedDrives' })
if ($Global:WifiBtHardwareDetected) {
    $tempCheckItems.Add(@{ Name = "Wi-Fi Driver Installed"; CheckFunction = 'Check-WifiDriver'; FixFunction = $null })
    $tempCheckItems.Add(@{ Name = "Bluetooth Driver Installed"; CheckFunction = 'Check-BluetoothDriver'; FixFunction = $null })
}
$tempCheckItems.Add(@{ Name = "GPU App Installed (NVIDIA App / AMD Adrenalin / Intel Arc)"; CheckFunction = 'Check-GpuApp'; FixFunction = $null })
$tempCheckItems.Add(@{ Name = "Motherboard App Installed (Armoury Crate / MSI Center / Gigabyte / ASRock)"; CheckFunction = 'Check-MotherboardApp'; FixFunction = $null })
$tempCheckItems.Add(@{ Name = "Changing Timezone to GTB"; CheckFunction = 'Check-Timezone'; FixFunction = 'Set-TimezoneGTB' })
$tempCheckItems.Add(@{ Name = "Custom Desktop Set"; CheckFunction = 'Check-CustomDesktopBackground'; FixFunction = 'Set-CustomDesktopBackground' })
$tempCheckItems.Add(@{ Name = "No Device Manager Errors"; CheckFunction = 'Check-DeviceManagerErrors'; FixFunction = $null; IsDeviceManagerCheck = $true })
$tempCheckItems.Add(@{ Name = "Deleting Traces"; CheckFunction = 'Check-EdgeDataCleared'; FixFunction = 'Clear-EdgeData' })
$tempCheckItems.Add(@{ Name = "Removing 'Learn about this picture'"; CheckFunction = 'Check-LearnAboutPicture'; FixFunction = 'Fix-LearnAboutPicture' })
if ($Global:OfficeIsActuallyInstalled) {
    $tempCheckItems.Add(@{ Name = "Office Desktop Shortcuts Created"; CheckFunction = 'Check-OfficeDesktopShortcuts'; FixFunction = 'Set-OfficeDesktopShortcuts' })
}
$activationCheckName = if ($Global:OfficeIsActuallyInstalled) { "Office and Windows Activated" } else { "Windows Activated" }
$tempCheckItems.Add(@{ Name = $activationCheckName; CheckFunction = 'Check-Activation'; FixFunction = $null; IsActivationCheck = $true })
$checkItems = $tempCheckItems.ToArray()
$indicators = @()
$labels = @()
$activationIndicatorPanel = $null
$activationLabel = $null

$form = New-Object System.Windows.Forms.Form
$form.Text = $scriptTitle
$fixedFormWidth = 1200
$calculatedFormHeight = 350 + ($checkItems.Count * 45) # Increased row height
if ($calculatedFormHeight -lt 750) { $calculatedFormHeight = 750 }
$form.Size = New-Object System.Drawing.Size($fixedFormWidth, $calculatedFormHeight)
$form.MinimumSize = $form.Size # Prevent shrinking
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::White
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$form.MaximizeBox = [bool]$true

$labelHeader = New-Object System.Windows.Forms.Label
$labelHeader.Text = "Driver Utility Checker"
$labelHeader.Font = New-Object System.Drawing.Font($defaultFont, 14, [System.Drawing.FontStyle]::Bold)
$labelHeader.Location = [System.Drawing.Point]::new(20, 15)
$labelHeader.AutoSize = [bool]$true
$form.Controls.Add($labelHeader)

$labelCurrentUser = New-Object System.Windows.Forms.Label
$labelCurrentUser.Text = "User:"
$labelCurrentUser.Font = New-Object System.Drawing.Font($defaultFont, 10, [System.Drawing.FontStyle]::Bold)
$labelCurrentUser.Location = [System.Drawing.Point]::new(850, 20)
$labelCurrentUser.AutoSize = $true
$labelCurrentUser.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($labelCurrentUser)

$comboBoxUser = New-Object System.Windows.Forms.ComboBox
$comboBoxUser.Location = [System.Drawing.Point]::new(900, 18)
$comboBoxUser.Size = New-Object System.Drawing.Size(120, 25)
$comboBoxUser.Font = New-Object System.Drawing.Font($defaultFont, 10)
$comboBoxUser.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$comboBoxUser.Items.AddRange(@("Alex", "Ciprian", "John", "Cosmin", "Vlad", "Gigi"))
$comboBoxUser.SelectedIndex = 0
$comboBoxUser.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($comboBoxUser)

$checkBoxAsamblareGold = New-Object System.Windows.Forms.CheckBox
$checkBoxAsamblareGold.Text = "Asamblare Gold"
$checkBoxAsamblareGold.Font = New-Object System.Drawing.Font($defaultFont, 10)
$checkBoxAsamblareGold.Location = [System.Drawing.Point]::new(1040, 19)
$checkBoxAsamblareGold.AutoSize = $true
$checkBoxAsamblareGold.Visible = $false
$checkBoxAsamblareGold.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($checkBoxAsamblareGold)

$checkBoxAutoClicker = New-Object System.Windows.Forms.CheckBox
$checkBoxAutoClicker.Text = "Auto-Click Installers"
$checkBoxAutoClicker.Font = New-Object System.Drawing.Font($defaultFont, 10)
$checkBoxAutoClicker.Location = [System.Drawing.Point]::new(850, 125)
$checkBoxAutoClicker.AutoSize = $true
$checkBoxAutoClicker.Checked = $false
$checkBoxAutoClicker.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($checkBoxAutoClicker)

$labelIdInput = New-Object System.Windows.Forms.Label
$labelIdInput.Text = "ID / Invoice:"
$labelIdInput.Font = New-Object System.Drawing.Font($defaultFont, 10, [System.Drawing.FontStyle]::Bold)
$labelIdInput.Location = [System.Drawing.Point]::new(850, 55)
$labelIdInput.AutoSize = $true
$labelIdInput.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($labelIdInput)

$textBoxIdInput = New-Object System.Windows.Forms.TextBox
$textBoxIdInput.Location = [System.Drawing.Point]::new(950, 53)
$textBoxIdInput.Size = New-Object System.Drawing.Size(70, 25)
$textBoxIdInput.Font = New-Object System.Drawing.Font($defaultFont, 10)
$textBoxIdInput.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($textBoxIdInput)

$buttonActivate = New-Object System.Windows.Forms.Button
$buttonActivate.Text = "Activate"
$buttonActivate.Size = New-Object System.Drawing.Size(85, 35)
$buttonActivate.Location = [System.Drawing.Point]::new(840, 85)
$buttonActivate.Font = New-Object System.Drawing.Font($defaultFont, 9, [System.Drawing.FontStyle]::Bold)
$buttonActivate.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$buttonActivate.Enabled = $false
$form.Controls.Add($buttonActivate)

$buttonAssociateNewKey = New-Object System.Windows.Forms.Button
$buttonAssociateNewKey.Text = "Assoc. New Key"
$buttonAssociateNewKey.Size = New-Object System.Drawing.Size(110, 35)
$buttonAssociateNewKey.Location = [System.Drawing.Point]::new(935, 85)
$buttonAssociateNewKey.Font = New-Object System.Drawing.Font($defaultFont, 9, [System.Drawing.FontStyle]::Bold)
$buttonAssociateNewKey.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$buttonAssociateNewKey.Enabled = $false
$form.Controls.Add($buttonAssociateNewKey)

$buttonFinalize = New-Object System.Windows.Forms.Button
$buttonFinalize.Text = "Finalize"
$buttonFinalize.Size = New-Object System.Drawing.Size(85, 35)
$buttonFinalize.Location = [System.Drawing.Point]::new(1055, 85)
$buttonFinalize.Font = New-Object System.Drawing.Font($defaultFont, 9, [System.Drawing.FontStyle]::Bold)
$buttonFinalize.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$buttonFinalize.Enabled = $false
$form.Controls.Add($buttonFinalize)

$labelDetectedMotherboard = New-Object System.Windows.Forms.Label
$labelDetectedMotherboard.Text = "Motherboard: Detecting..."
$labelDetectedMotherboard.Font = New-Object System.Drawing.Font($defaultFont, 10, [System.Drawing.FontStyle]::Bold)
$labelDetectedMotherboard.Location = [System.Drawing.Point]::new(20, 50)
$labelDetectedMotherboard.AutoSize = [bool]$true
$labelDetectedMotherboard.ForeColor = $global:colorDetected
$form.Controls.Add($labelDetectedMotherboard)

$labelDetectedGpu = New-Object System.Windows.Forms.Label
$labelDetectedGpu.Text = "GPU: Detecting..."
$labelDetectedGpu.Font = New-Object System.Drawing.Font($defaultFont, 10, [System.Drawing.FontStyle]::Bold)
$labelDetectedGpu.Location = [System.Drawing.Point]::new(20, 75)
$labelDetectedGpu.AutoSize = [bool]$true
$labelDetectedGpu.ForeColor = $global:colorDetected
$form.Controls.Add($labelDetectedGpu)

$labelDetectedWiFiBT = New-Object System.Windows.Forms.Label
$labelDetectedWiFiBT.Text = "Wi-Fi+BT Card/Onboard: Detecting..."
$labelDetectedWiFiBT.Font = New-Object System.Drawing.Font($defaultFont, 10, [System.Drawing.FontStyle]::Bold)
$labelDetectedWiFiBT.Location = [System.Drawing.Point]::new(20, 100)
$labelDetectedWiFiBT.AutoSize = [bool]$true
$labelDetectedWiFiBT.ForeColor = $global:colorDetected
$form.Controls.Add($labelDetectedWiFiBT)

$checkItemsStartY = 130
$fixedRowPanelWidth = 850
for ($i = 0; $i -lt $checkItems.Count; $i++) {
    $rowPanel = New-Object System.Windows.Forms.Panel
    $rowPanel.Size = New-Object System.Drawing.Size([int]$fixedRowPanelWidth, 40)
    $rowPanel.Location = [System.Drawing.Point]::new(20, $checkItemsStartY + ($i * 45))
    $rowPanel.BackColor = [System.Drawing.Color]::White
    $rowPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $form.Controls.Add($rowPanel)

    $indicator = New-Object System.Windows.Forms.Panel
    $indicator.Size = New-Object System.Drawing.Size(16, 16)
    $indicator.Location = [System.Drawing.Point]::new(0, 7)
    $indicator.BackColor = Get-SafeColor $global:colorPending
    $indicator.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $rowPanel.Controls.Add($indicator)
    $indicators += $indicator

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $checkItems[$i].Name
    $label.Location = [System.Drawing.Point]::new(30, 7)
    $label.Font = New-Object System.Drawing.Font($defaultFont, 10)
    $label.ForeColor = [System.Drawing.Color]::Black
    $label.AutoSize = $true
    $label.MaximumSize = New-Object System.Drawing.Size(($rowPanel.Width - $label.Location.X - 10), 0)
    $rowPanel.Controls.Add($label)
    $labels += $label

    if ($checkItems[$i].IsActivationCheck) {
        $activationIndicatorPanel = $indicator
        $activationLabel = $label
    }
}

$buttonRowYPosition = $checkItemsStartY + ($checkItems.Count * 45) + 30

$buttonCheck = New-Object System.Windows.Forms.Button
$buttonCheck.Text = "Run Checks / Auto-Fix"
$buttonCheck.Size = New-Object System.Drawing.Size(200, 40)
$buttonCheck.Location = [System.Drawing.Point]::new(20, $buttonRowYPosition)
$buttonCheck.Font = New-Object System.Drawing.Font($defaultFont, 10, [System.Drawing.FontStyle]::Bold)
$buttonCheck.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($buttonCheck)

$buttonInstallDrivers = New-Object System.Windows.Forms.Button
$buttonInstallDrivers.Text = "Install Drivers"
$buttonInstallDrivers.Size = New-Object System.Drawing.Size(150, 40)
$buttonInstallDrivers.Location = [System.Drawing.Point]::new($buttonCheck.Location.X + $buttonCheck.Width + 10, $buttonRowYPosition)
$buttonInstallDrivers.Font = New-Object System.Drawing.Font($defaultFont, 10, [System.Drawing.FontStyle]::Bold)
$buttonInstallDrivers.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($buttonInstallDrivers)

$buttonOptionalInstallers = New-Object System.Windows.Forms.Button
$buttonOptionalInstallers.Text = "Install Optional Software"
$buttonOptionalInstallers.Size = New-Object System.Drawing.Size(200, 40)
$buttonOptionalInstallers.Location = [System.Drawing.Point]::new($buttonInstallDrivers.Location.X + $buttonInstallDrivers.Width + 10, $buttonRowYPosition)
$buttonOptionalInstallers.Font = New-Object System.Drawing.Font($defaultFont, 10, [System.Drawing.FontStyle]::Bold)
$buttonOptionalInstallers.Enabled = [bool]$false
$buttonOptionalInstallers.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($buttonOptionalInstallers)

$buttonEnableRDP = New-Object System.Windows.Forms.Button
$buttonEnableRDP.Text = "Enable Remote Desktop"
$buttonEnableRDP.Size = New-Object System.Drawing.Size(200, 40)
$buttonEnableRDP.Location = [System.Drawing.Point]::new($buttonOptionalInstallers.Location.X + $buttonOptionalInstallers.Width + 10, $buttonRowYPosition)
$buttonEnableRDP.Font = New-Object System.Drawing.Font($defaultFont, 10, [System.Drawing.FontStyle]::Bold)
$buttonEnableRDP.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($buttonEnableRDP)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = [System.Drawing.Point]::new(20, $buttonRowYPosition + $buttonCheck.Height + 10)
$progressBar.Size = New-Object System.Drawing.Size((([int]$fixedFormWidth) - 60), 20)
$progressBar.Minimum = 0
$progressBar.Maximum = $checkItems.Count
$progressBar.Value = 0
$progressBar.Step = 1
$progressBar.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($progressBar)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Status: Ready"
$statusLabel.Font = New-Object System.Drawing.Font($defaultFont, 9)
$statusLabel.Location = [System.Drawing.Point]::new(20, $progressBar.Location.Y + $progressBar.Height + 5)
$statusLabel.AutoSize = [bool]$true
$statusLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom
$form.Controls.Add($statusLabel)



$buttonCheck.Add_Click({
    $buttonCheck.Enabled = $false; $buttonCheck.Text = "Checking..."
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $buttonInstallDrivers.Enabled = $false
    $buttonOptionalInstallers.Enabled = $false
    $buttonActivate.Enabled = $false
    $buttonFinalize.Enabled = $false
    $buttonEnableRDP.Enabled = $false
    $buttonAssociateNewKey.Enabled = $false

    Update-ProgressBar 0
    $indicators | ForEach-Object { $_.BackColor = Get-SafeColor $global:colorPending }
    $form.Refresh()

    for ($i = 0; $i -lt $checkItems.Count; $i++) {
        if ($form.IsDisposed) { break }
        $item = $checkItems[$i]; $indicator = $indicators[$i]

        if ($item.IsActivationCheck) {
            $activationStatusObject = Check-Activation
            if ($activationStatusObject.Combined) { $indicator.BackColor = Get-SafeColor $global:colorOK }
            else { $indicator.BackColor = Get-SafeColor $global:colorError }
            Update-ProgressBar ($i + 1)
            [System.Windows.Forms.Application]::DoEvents()
            continue
        }

        if ($item.IsDeviceManagerCheck) {
            $dmErrors = Check-DeviceManagerErrors
            if ($null -eq $dmErrors) { $indicator.BackColor = Get-SafeColor $global:colorOK }
            else { $indicator.BackColor = Get-SafeColor $global:colorError }
            Update-ProgressBar ($i + 1)
            [System.Windows.Forms.Application]::DoEvents()
            continue
        }

        $indicator.BackColor = Get-SafeColor $global:colorInProgress
        Update-Status "Checking: $($item.Name)" $global:colorChecking
        Update-ProgressBar ($i + 1)
        [System.Windows.Forms.Application]::DoEvents()

        $checkResult = $true
        try {
            $checkResult = & $item.CheckFunction
        }
        catch {
            $indicator.BackColor = Get-SafeColor $global:colorCheckError
            Update-Status "$($item.Name): ERROR during check." $global:colorFailed
            [System.Windows.Forms.Application]::DoEvents()
            continue
        }

        if (-not $checkResult) {
            if ($item.FixFunction) {
                Update-Status "$($item.Name): Issue found. Attempting auto-fix..." $global:colorChecking
                [System.Windows.Forms.Application]::DoEvents()
                try { & $item.FixFunction } catch { }
                [System.Windows.Forms.Application]::DoEvents()
                $recheckResult = & $item.CheckFunction
                if ($recheckResult) {
                    $indicator.BackColor = Get-SafeColor $global:colorOK
                    Update-Status "$($item.Name): Fixed successfully." $global:colorSuccess
                }
                else {
                    $indicator.BackColor = Get-SafeColor $global:colorError
                    Update-Status "$($item.Name): Auto-fix failed or was incomplete." $global:colorFailed
                }
                [System.Windows.Forms.Application]::DoEvents()
            }
            else {
                $indicator.BackColor = Get-SafeColor $global:colorError
                Update-Status "$($item.Name): Issue found (No auto-fix available)." $global:colorWarning
            }
        }
        else {
            $indicator.BackColor = Get-SafeColor $global:colorOK
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    Update-ProgressBar $progressBar.Maximum
    Update-Status "All main checks & fixes processed. Use other buttons for activation or installation." $global:colorSuccess

    $buttonCheck.Enabled = $true; $buttonCheck.Text = "Run Checks / Auto-Fix"
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
    $buttonInstallDrivers.Enabled = $true
    if (($Global:InstallerQueue | Where-Object { $_.IsOptional -eq $true }).Count -gt 0) { $buttonOptionalInstallers.Enabled = $true }
    $idIsPresent = -not [string]::IsNullOrWhiteSpace($textBoxIdInput.Text)
    $buttonActivate.Enabled = $idIsPresent
    $buttonFinalize.Enabled = $idIsPresent
    $buttonEnableRDP.Enabled = $true
    $buttonAssociateNewKey.Enabled = $idIsPresent
    Update-ProgressBar 0
})

$buttonInstallDrivers.Add_MouseDown({
    param($sender, $e)

    # Right-click shows dialog to select installers
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        $requiredInstallers = $Global:InstallerQueue | Where-Object { $_.IsOptional -eq $false }
        if ($requiredInstallers.Count -gt 0) {
            Show-RequiredInstallerDialog -RequiredInstallers $requiredInstallers
            [System.Collections.Generic.List[hashtable]]$selectedInstallers = $Global:SelectedInstallersFromDialog
            if ($selectedInstallers.Count -gt 0) {
                Invoke-DriverInstallation -SelectedInstallers $selectedInstallers
            }
        } else {
            Show-Popup -Message "No drivers found to install." -Title "No Drivers"
        }
    }
    # Left-click installs all drivers automatically
    elseif ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        Invoke-DriverInstallation
    }
})

$buttonOptionalInstallers.Add_Click({
    $optionalInstallers = $Global:InstallerQueue | Where-Object { $_.IsOptional -eq $true }
    Show-OptionalInstallerDialog -OptionalInstallers $optionalInstallers
    [System.Collections.Generic.List[hashtable]]$selectedInstallers = $Global:SelectedInstallersFromDialog
    if ($selectedInstallers.Count -gt 0) {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        Update-Status "Running selected optional software installers..." $global:colorChecking

        $officeWasSelected = $false
        foreach ($installerObj in $selectedInstallers) {
            if ($form.IsDisposed) { return }
            if ($installerObj.DisplayName -like "*Office*") {
                $officeWasSelected = $true
            }
            Execute-InstallerProcess -InstallerPath $installerObj.InstallerPath -DisplayName $installerObj.DisplayName -DeviceType $installerObj.DeviceType
        }

        if ($officeWasSelected) {

            Detect-OfficeInstallation
        }

        Update-Status "All selected optional software has been run." $global:colorSuccess
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
    else {
        Update-Status "No optional software selected or user cancelled." $global:colorFailed
    }
})

$buttonActivate.Add_Click({
    $id = $textBoxIdInput.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($id)) {
        Show-Popup -Title "Input Error" -Message "Please enter an ID before activating."
        return
    }
    try {
        Invoke-ActivationOnlyProcess -Identity $id
    }
    catch {
        Update-Status "A critical error occurred during activation: $($_.Exception.Message)" $global:colorError
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $buttonActivate.Enabled = $true
        $buttonFinalize.Enabled = $true
    }
})

$buttonAssociateNewKey.Add_Click({
    $id = $textBoxIdInput.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($id)) {
        Show-Popup -Title "Input Error" -Message "Please enter an ID before associating a new key."
        return
    }

    if (Show-RequestNewKeyConfirmation) {
        try {

            Invoke-ActivationOnlyProcess -Identity $id
        }
        catch {
            Update-Status "A critical error occurred during new key association: $($_.Exception.Message)" $global:colorError
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            $buttonActivate.Enabled = $true
            $buttonFinalize.Enabled = $true
            $buttonAssociateNewKey.Enabled = $true
        }
    } else {
        Update-Status "User cancelled new key association." $global:colorInfo
    }
})

$buttonFinalize.Add_Click({
    $id = $textBoxIdInput.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($id)) {
        Show-Popup -Title "Input Error" -Message "Please enter an ID before finalizing."
        return
    }

    $selectedUserId = ""
    if ($comboBoxUser.SelectedItem -and $comboBoxUser.Tag -and $comboBoxUser.Tag.ContainsKey($comboBoxUser.SelectedItem.ToString())) {
        $selectedUserId = $comboBoxUser.Tag[$comboBoxUser.SelectedItem.ToString()]

    }

    try {
        Invoke-ConfirmAndFinalizeProcess -Identity $id -SoftwareInstallBy $selectedUserId
    }
    catch {
        Update-Status "A critical error occurred during finalization: $($_.Exception.Message)" $global:colorError
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $buttonActivate.Enabled = $true
        $buttonFinalize.Enabled = $true
    }
})

$buttonEnableRDP.Add_Click({
    try {
        Invoke-EnableRemoteDesktop
    }
    catch {
        Update-Status "A critical error occurred while enabling RDP: $($_.Exception.Message)" $global:colorError
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $buttonActivate.Enabled = $true
        $buttonFinalize.Enabled = $true
        $buttonEnableRDP.Enabled = $true
    }
})

$textBoxIdInput.Add_TextChanged({
    $idIsPresent = -not [string]::IsNullOrWhiteSpace($textBoxIdInput.Text)
    $buttonActivate.Enabled = $idIsPresent
    $buttonFinalize.Enabled = $idIsPresent
    $buttonAssociateNewKey.Enabled = $idIsPresent
})

$checkBoxAsamblareGold.Add_CheckedChanged({
    if ($checkBoxAsamblareGold.Checked) {
        $labelCurrentUser.ForeColor = $global:colorGold
    }
    else {
        $labelCurrentUser.ForeColor = [System.Drawing.Color]::Black
    }
})

$checkBoxAutoClicker.Add_CheckedChanged({
    $global:AutoClickEnabled = $checkBoxAutoClicker.Checked
})

$comboBoxUser.Add_SelectedIndexChanged({
    $selectedUser = $comboBoxUser.SelectedItem.ToString()
    if ($selectedUser -eq "John" -or $selectedUser -eq "Gigi") {
        $checkBoxAsamblareGold.Visible = $true
    }
    else {
        $checkBoxAsamblareGold.Visible = $false
        $checkBoxAsamblareGold.Checked = $false
    }
})

$form.Add_Shown({

    $users = Get-AvailableUsers
    if ($users -and $users.Count -gt 0) {
        $comboBoxUser.Items.Clear()
        foreach ($user in $users) {
            $displayText = "$($user.nume) (ID: $($user.id))"
            $comboBoxUser.Items.Add($displayText) | Out-Null

            if ($comboBoxUser.Items.Count -eq 1) {
                $comboBoxUser.Tag = @{$displayText = $user.id}
            } else {
                $comboBoxUser.Tag[$displayText] = $user.id
            }
        }
        if ($comboBoxUser.Items.Count -gt 0) {
            $comboBoxUser.SelectedIndex = 0
        }
    } else {
        $comboBoxUser.Items.Clear()
        $comboBoxUser.Items.Add("No users available") | Out-Null
        $comboBoxUser.SelectedIndex = 0
    }

    $foundId = Find-IdFromUsb
    if ($foundId) {
        $form.Invoke([Action]{
            $textBoxIdInput.Text = $foundId
            Update-Status "ID '$foundId' loaded automatically from USB." $global:colorInfo
        })
    }
    Update-Status "Detecting hardware..." $global:colorChecking; $form.Refresh()
    $motherboard = Get-MotherboardInfo
    if ($motherboard) {
        $labelDetectedMotherboard.Text = "Motherboard: $($motherboard.Manufacturer) - $($motherboard.Product)"
        $mbInstaller = Get-InstallerPath -BasePath $motherboardDriversPath -ManufacturerOrVendorOrFolder $motherboard.NormalizedManufacturer
        if ($mbInstaller) {
            $Global:InstallerQueue.Add(@{ InstallerPath = $mbInstaller; DisplayName = "$($motherboard.NormalizedManufacturer) Drivers"; DeviceType = "Motherboard"; IsOptional = $false; Arguments = $null })
        }
    }
    else {
        $labelDetectedMotherboard.Text = "Motherboard: Not Detected/Error"; $labelDetectedMotherboard.ForeColor = $global:colorError;
    }
    $gpus = Get-GpuInfo
    if ($gpus) {
        $labelDetectedGpu.Text = "GPU(s): $(($gpus | ForEach-Object { "$($_.Vendor) - $($_.Name)" }) -join ", ")"
        $isNvidiaPresent = ($gpus | Where-Object { $_.Vendor -eq "NVIDIA" }).Count -gt 0
        $processedVendors = [System.Collections.Generic.List[string]]::new()
        foreach ($gpu in $gpus) {
            if ($isNvidiaPresent -and $gpu.Vendor -ne "NVIDIA") { continue }
            if ($gpu.Vendor -ne "Unknown" -and !$processedVendors.Contains($gpu.Vendor)) {
                $gpuInstaller = Get-InstallerPath -BasePath $gpuDriversPath -ManufacturerOrVendorOrFolder $gpu.Vendor
                if ($gpuInstaller) {
                    $Global:InstallerQueue.Add(@{ InstallerPath = $gpuInstaller; DisplayName = "$($gpu.Vendor) GPU Driver"; DeviceType = "GPU"; IsOptional = $false })
                }
                $processedVendors.Add($gpu.Vendor)
            }
        }
    }
    else {
        $labelDetectedGpu.Text = "GPU: Not Detected/Error"; $labelDetectedGpu.ForeColor = $global:colorError;
    }
    if ($Global:WifiBtHardwareDetected) {
        $labelDetectedWiFiBT.Text = "Wi-Fi+BT: $($Global:WifiBtDetectedName)"
        if (-not [string]::IsNullOrWhiteSpace($Global:WifiBtDriverFolderHint) -and $Global:WifiBtDriverFolderHint -ne "Generic") {
            $wifiBtInstaller = Get-InstallerPath -BasePath $wifiBtDriversPath -ManufacturerOrVendorOrFolder $Global:WifiBtDriverFolderHint
            if ($wifiBtInstaller) {
                $Global:InstallerQueue.Add(@{ InstallerPath = $wifiBtInstaller; DisplayName = $Global:WifiBtDetectedName; DeviceType = "Wi-Fi/Bluetooth"; IsOptional = $false; DriverFolderHint = $Global:WifiBtDriverFolderHint })
            }
        }
    }
    else {
        $labelDetectedWiFiBT.Text = "Wi-Fi+BT: Not Detected"
    }
    if (($Global:InstallerQueue | Where-Object { $_.IsOptional -eq $true }).Count -gt 0) {
        if ($buttonOptionalInstallers) { $buttonOptionalInstallers.Enabled = $true }
    }

    $idResponse = Invoke-HardwareIdentification
    if ($idResponse) {
        $allItems = @()
        if ($idResponse.match) { $allItems += $idResponse.match }
        if ($idResponse.partialMatch) { $allItems += $idResponse.partialMatch }
        if ($allItems.Count -eq 1) {
            $textBoxIdInput.Text = $allItems[0].id
            $global:SoftwareToActivate = $allItems[0].softwareType
            Update-Status "Single matching ID found and set automatically." $global:colorSuccess
        }
        elseif ($allItems.Count -gt 1) {
            $selectedItem = Show-IdSelectionDialog -Matches $idResponse
            if ($selectedItem) {
                $textBoxIdInput.Text = $selectedItem.id
                $global:SoftwareToActivate = $selectedItem.softwareType
                Update-Status "ID selected by user." $global:colorInfo
            }
            else {
                Update-Status "User cancelled ID selection. Please enter manually." $global:colorWarning
            }
        }
        else {
            Update-Status "No automatic ID match found. Please enter manually." $global:colorWarning
        }
    }
    Update-Status "Hardware detection complete. Ready for checks or driver installation." $global:colorSuccess
})

$form.Add_FormClosed({

})



try {
    $form.ResumeLayout($false); $form.PerformLayout()

    $form.ShowDialog() | Out-Null
}
catch {
    Write-Warning "Form display/execution error: $($_.Exception.Message)`nStack Trace: $($_.ScriptStackTrace)"
    if ($form -and -not $form.IsDisposed) {
        try { [System.Windows.Forms.MessageBox]::Show("Critical GUI error: $($_.Exception.Message)", "GUI Error", "OK", "Error") | Out-Null }
        catch { }
    }
}
finally {

    if ($form -and (-not $form.IsDisposed)) {
        try { $form.Dispose() }
        catch { }
    }
}


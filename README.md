# SysCheck

**Comprehensive Windows System Configuration and Driver Installation Tool**

## Overview

SysCheck is an automated PowerShell-based system configuration utility designed to streamline the setup process for Windows installations. It handles hardware detection, driver installation, system checks, and various Windows configurations.

## Key Features

- **Automated Hardware Detection**: Identifies Wi-Fi adapters, Bluetooth devices, GPUs, and other hardware components
- **Driver Installation Automation**: Automatically installs drivers with intelligent UI automation and template matching
- **Multi-Phase Installer Support**: Handles complex installers with multiple windows and stages
- **Template Matching**: OpenCV-powered visual automation for installers without UI Automation support
- **System Checks**: Validates activation status, display settings, power configuration, and more
- **Drive Configuration**: Automatically initializes and configures unassigned drives
- **Hardware-Specific Profiles**: Custom automation profiles for various manufacturers:
  - NVIDIA/AMD Graphics Drivers
  - Intel/MediaTek/Realtek Network Adapters
  - MSI Center, Gigabyte Control Center, ASRock APP Shop
  - TP-Link, ASUS, and other hardware utilities

## Technical Highlights

- **Two-Phase Automation**: Pre-programmed steps (Phase 1) + Template matching (Phase 2)
- **Window Detection**: Multi-window installer support with automatic window switching
- **OCR Integration**: Text recognition for dynamic UI elements
- **Error Handling**: Automatic retry logic with scroll-and-retry for template matching
- **UI Automation**: Leverages Windows UI Automation framework for reliable button clicking

## Project Structure

```
SysCheck/
├── Syscheckv5.ps1              # Main system check script
├── ActivatorNew.ps1            # Windows & Office activation tool
├── ScreenshotTemplates/        # Template images for pattern matching
│   ├── amd/
│   ├── gigabyte/
│   ├── msi/
│   ├── tx20e/
│   └── ...
├── opencvpython/               # Template matching engine
│   ├── template_matcher.exe
│   └── template_matcher.py
└── Drivers/                    # Hardware driver packages
```

## Requirements

- Windows 10/11
- PowerShell 5.1 or higher
- Administrator privileges
- .NET Framework 4.5+
- Python 3.x (optional - for template matching script fallback)

## Usage

**Run as Administrator:**

```powershell
powershell -ExecutionPolicy Bypass -File "Syscheckv5.ps1"
```

The GUI will launch and guide you through the system configuration process.

## Configuration

The script includes configurable profiles for various hardware installers in the `$Global:InstallerProfiles` hashtable. Each profile can specify:

- Window title patterns
- Automation steps (clicks, waits, key presses)
- Template matching folders
- Launch application settings

## License

**PROPRIETARY - ALL RIGHTS RESERVED**

Copyright (c) 2025 Alexandru Stoian

This code is proprietary and confidential. Unauthorized copying, distribution,
modification, or use of this software, via any medium, is strictly prohibited.

## Notice

⚠️ **DO NOT DISTRIBUTE** - This software is provided for reference purposes only.

---

*For authorized use only.*

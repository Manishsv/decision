# Python Installation & Environment Management

## Overview

The application includes automatic Python detection and installation assistance for business users who may not know how to install Python manually.

## Features

1. **Automatic Detection**: Checks if Python 3.x is installed
2. **Package Verification**: Verifies required packages (pandas, matplotlib, seaborn)
3. **Installation Assistance**: Platform-specific installation guidance
4. **Auto-Install Attempts**: Attempts automatic installation where possible (Windows winget)
5. **User-Friendly UI**: Settings page integration with clear status indicators

## Implementation

### Service: `PythonService`

Located in `lib/services/python_service.dart`, this service provides:

- `checkPythonInstallation()`: Checks for Python and required packages
- `installPython()`: Attempts platform-specific installation
- `installRequiredPackages()`: Installs missing Python packages via pip
- `getPythonExecutable()`: Returns the Python executable path for running scripts

### Platform Support

#### macOS
- Checks for Homebrew installation
- Provides download link to python.org
- Shows Homebrew installation instructions

#### Windows
- Attempts installation via `winget` (Windows 10/11)
- Falls back to opening python.org download page
- Provides clear PATH configuration instructions

#### Linux
- Detects package manager (apt, yum, dnf, pacman)
- Provides installation commands for each distribution

### Settings Page Integration

The Settings page now includes a "Python Environment" section that:

1. Automatically checks Python status on load
2. Shows visual status indicators (green = ready, orange = needs setup)
3. Provides "Install Python" button when not installed
4. Provides "Install Packages" button when packages are missing
5. Shows refresh button to re-check status

## Usage

### In Code

```dart
// Get Python service
final pythonService = ref.read(pythonServiceProvider);

// Check installation
final check = await pythonService.checkPythonInstallation();
if (check.isReady) {
  // Python is installed and packages are available
  final pythonExec = await pythonService.getPythonExecutable();
  // Use pythonExec to run Python scripts
} else {
  // Show installation instructions
  final instructions = pythonService.getInstallationInstructions(check);
}
```

### For Visualization Feature

When implementing the visualization feature, check Python before generating visualizations:

```dart
// In visualization service
Future<Map<String, dynamic>> generateVisualization(...) async {
  final pythonService = ref.read(pythonServiceProvider);
  final check = await pythonService.checkPythonInstallation();
  
  if (!check.isReady) {
    return {
      'success': false,
      'error': 'Python not ready',
      'instructions': pythonService.getInstallationInstructions(check),
    };
  }
  
  final pythonExec = await pythonService.getPythonExecutable();
  // Proceed with visualization generation...
}
```

## Required Python Packages

The following packages are automatically checked and can be installed:

- `pandas`: Data manipulation and analysis
- `matplotlib`: Plotting and visualization
- `seaborn`: Statistical data visualization

## Installation Methods

### Automatic (Where Supported)

- **Windows**: Uses `winget` if available (Windows 10/11)
- **macOS/Linux**: Provides instructions (requires manual installation due to sudo requirements)

### Manual Installation

If automatic installation fails or is not supported:

1. **macOS**: Download from [python.org](https://www.python.org/downloads/)
2. **Windows**: Download from [python.org](https://www.python.org/downloads/) - **Important**: Check "Add Python to PATH" during installation
3. **Linux**: Use distribution package manager:
   - Ubuntu/Debian: `sudo apt-get install python3 python3-pip`
   - Fedora/RHEL: `sudo dnf install python3 python3-pip`
   - Arch: `sudo pacman -S python python-pip`

After manual installation, install required packages:

```bash
python3 -m pip install pandas matplotlib seaborn
```

## User Experience

1. User opens Settings page
2. Python status is automatically checked
3. If not installed:
   - Orange status card appears
   - "Install Python" button is shown
   - Clicking opens browser or attempts installation
4. If installed but packages missing:
   - Orange status card appears
   - "Install Packages" button is shown
   - Clicking installs via pip
5. If ready:
   - Green status card appears
   - Shows Python version and path

## Future Enhancements

1. **Progress Indicators**: Show installation progress for long-running operations
2. **Version Checking**: Ensure Python 3.8+ is installed
3. **Virtual Environments**: Support for isolated Python environments
4. **Package Updates**: Check for package updates
5. **Error Recovery**: Better error messages and recovery suggestions

## Security Considerations

- Installation requires user consent (no silent installations)
- Platform-specific security prompts are respected (sudo on Linux/macOS)
- No automatic package installation without user approval
- Clear instructions provided if automatic installation fails

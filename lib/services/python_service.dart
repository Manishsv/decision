/// Python Installation and Environment Service
/// Checks for Python installation, installs if needed, and verifies required packages

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of Python environment check
class PythonCheckResult {
  final bool isInstalled;
  final String? version;
  final String? executablePath;
  final bool hasRequiredPackages;
  final List<String> missingPackages;
  final String? error;

  PythonCheckResult({
    required this.isInstalled,
    this.version,
    this.executablePath,
    required this.hasRequiredPackages,
    this.missingPackages = const [],
    this.error,
  });

  bool get isReady => isInstalled && hasRequiredPackages;
}

/// Python installation result
class PythonInstallResult {
  final bool success;
  final String? error;
  final String? message;

  PythonInstallResult({
    required this.success,
    this.error,
    this.message,
  });
}

/// Service for managing Python installation and environment
class PythonService {
  static const List<String> requiredPackages = [
    'pandas',
    'matplotlib',
    'seaborn',
  ];

  /// Check if Python is installed and has required packages
  Future<PythonCheckResult> checkPythonInstallation() async {
    try {
      // Try python3 first (standard on macOS/Linux)
      ProcessResult result = await Process.run(
        'python3',
        ['--version'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        final executablePath = await _findPythonExecutable('python3');
        
        // Check for required packages
        final packageCheck = await _checkRequiredPackages('python3');
        
        return PythonCheckResult(
          isInstalled: true,
          version: version,
          executablePath: executablePath,
          hasRequiredPackages: packageCheck['hasAll'] as bool,
          missingPackages: packageCheck['missing'] as List<String>,
        );
      }
    } catch (e) {
      // python3 not found, try python (Windows)
      try {
        ProcessResult result = await Process.run(
          'python',
          ['--version'],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          final version = result.stdout.toString().trim();
          final executablePath = await _findPythonExecutable('python');
          
          final packageCheck = await _checkRequiredPackages('python');
          
          return PythonCheckResult(
            isInstalled: true,
            version: version,
            executablePath: executablePath,
            hasRequiredPackages: packageCheck['hasAll'] as bool,
            missingPackages: packageCheck['missing'] as List<String>,
          );
        }
      } catch (e2) {
        // Neither python3 nor python found
        return PythonCheckResult(
          isInstalled: false,
          hasRequiredPackages: false,
          missingPackages: requiredPackages,
          error: 'Python not found. Error: $e',
        );
      }
    }

    return PythonCheckResult(
      isInstalled: false,
      hasRequiredPackages: false,
      missingPackages: requiredPackages,
      error: 'Python not found on system',
    );
  }

  /// Find Python executable path
  Future<String?> _findPythonExecutable(String command) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'where',
          [command],
          runInShell: true,
        );
        if (result.exitCode == 0) {
          return result.stdout.toString().trim().split('\n').first;
        }
      } else {
        final result = await Process.run(
          'which',
          [command],
          runInShell: true,
        );
        if (result.exitCode == 0) {
          return result.stdout.toString().trim();
        }
      }
    } catch (e) {
      debugPrint('Error finding Python executable: $e');
    }
    return command; // Fallback to command name
  }

  /// Check if required packages are installed
  Future<Map<String, dynamic>> _checkRequiredPackages(String pythonCommand) async {
    final missing = <String>[];
    
    for (final package in requiredPackages) {
      try {
        final result = await Process.run(
          pythonCommand,
          ['-c', 'import $package'],
          runInShell: true,
        );
        
        if (result.exitCode != 0) {
          missing.add(package);
        }
      } catch (e) {
        missing.add(package);
      }
    }

    return {
      'hasAll': missing.isEmpty,
      'missing': missing,
    };
  }

  /// Install Python (platform-specific)
  /// Returns installation instructions if auto-install fails
  Future<PythonInstallResult> installPython() async {
    if (Platform.isMacOS) {
      return await _installPythonMacOS();
    } else if (Platform.isWindows) {
      return await _installPythonWindows();
    } else if (Platform.isLinux) {
      return await _installPythonLinux();
    } else {
      return PythonInstallResult(
        success: false,
        error: 'Unsupported platform',
        message: 'Python installation is not supported on this platform. Please install Python 3.8+ manually.',
      );
    }
  }

  /// Install Python on macOS
  Future<PythonInstallResult> _installPythonMacOS() async {
    // Check if Homebrew is available
    try {
      final brewCheck = await Process.run(
        'brew',
        ['--version'],
        runInShell: true,
      );

      if (brewCheck.exitCode == 0) {
        // Try installing via Homebrew (requires user password)
        debugPrint('Homebrew found. Attempting to install Python via Homebrew...');
        
        // Note: This will prompt for password, so we'll show instructions instead
        // For automatic installation, we'd need to handle sudo prompts
        return PythonInstallResult(
          success: false,
          message: 'To install Python on macOS:\n\n'
              'Option 1 (Recommended): Download from python.org\n'
              '1. Visit https://www.python.org/downloads/\n'
              '2. Download Python 3.8 or later\n'
              '3. Run the installer\n\n'
              'Option 2: Use Homebrew:\n'
              '1. Open Terminal\n'
              '2. Run: brew install python3\n'
              '3. Enter your password when prompted',
        );
      }
    } catch (e) {
      // Homebrew not found
    }

    // Fallback: Open Python download page
    try {
      await Process.run('open', ['https://www.python.org/downloads/']);
      return PythonInstallResult(
        success: false,
        message: 'Opening Python download page in your browser.\n\n'
            'Please download and install Python 3.8 or later, then restart this app.',
      );
    } catch (e) {
      return PythonInstallResult(
        success: false,
        error: 'Could not open browser',
        message: 'Please visit https://www.python.org/downloads/ to download Python.',
      );
    }
  }

  /// Install Python on Windows
  Future<PythonInstallResult> _installPythonWindows() async {
    // Check if winget is available (Windows 10/11)
    try {
      final wingetCheck = await Process.run(
        'winget',
        ['--version'],
        runInShell: true,
      );

      if (wingetCheck.exitCode == 0) {
        // Try installing via winget
        debugPrint('Winget found. Attempting to install Python via winget...');
        
        try {
          final result = await Process.run(
            'winget',
            ['install', 'Python.Python.3.12', '--silent', '--accept-package-agreements', '--accept-source-agreements'],
            runInShell: true,
          );

          if (result.exitCode == 0) {
            // Wait a bit for installation to complete
            await Future.delayed(const Duration(seconds: 5));
            
            // Verify installation
            final check = await checkPythonInstallation();
            if (check.isInstalled) {
              return PythonInstallResult(
                success: true,
                message: 'Python installed successfully! Version: ${check.version}',
              );
            }
          }
        } catch (e) {
          debugPrint('Winget installation failed: $e');
        }
      }
    } catch (e) {
      // Winget not available
    }

    // Fallback: Open Python download page
    try {
      await Process.run('start', ['https://www.python.org/downloads/'], runInShell: true);
      return PythonInstallResult(
        success: false,
        message: 'Opening Python download page in your browser.\n\n'
            'Please download and install Python 3.8 or later.\n'
            'Make sure to check "Add Python to PATH" during installation, then restart this app.',
      );
    } catch (e) {
      return PythonInstallResult(
        success: false,
        error: 'Could not open browser',
        message: 'Please visit https://www.python.org/downloads/ to download Python.',
      );
    }
  }

  /// Install Python on Linux
  Future<PythonInstallResult> _installPythonLinux() async {
    // Try different package managers
    final packageManagers = [
      {'cmd': 'apt-get', 'install': ['sudo', 'apt-get', 'install', '-y', 'python3', 'python3-pip']},
      {'cmd': 'yum', 'install': ['sudo', 'yum', 'install', '-y', 'python3', 'python3-pip']},
      {'cmd': 'dnf', 'install': ['sudo', 'dnf', 'install', '-y', 'python3', 'python3-pip']},
      {'cmd': 'pacman', 'install': ['sudo', 'pacman', '-S', '--noconfirm', 'python', 'python-pip']},
    ];

    for (final pm in packageManagers) {
      try {
        final check = await Process.run(
          pm['cmd'] as String,
          ['--version'],
          runInShell: true,
        );

        if (check.exitCode == 0) {
          debugPrint('Found ${pm['cmd']}. Attempting to install Python...');
          
          // Note: This requires sudo, so we'll show instructions
          return PythonInstallResult(
            success: false,
            message: 'To install Python on Linux:\n\n'
                'Open Terminal and run:\n'
                '${(pm['install'] as List<String>).join(' ')}\n\n'
                'You will be prompted for your password.',
          );
        }
      } catch (e) {
        // Package manager not found, try next
        continue;
      }
    }

    return PythonInstallResult(
      success: false,
      error: 'No supported package manager found',
      message: 'Please install Python 3.8+ using your distribution\'s package manager.',
    );
  }

  /// Install required Python packages
  Future<PythonInstallResult> installRequiredPackages() async {
    final check = await checkPythonInstallation();
    
    if (!check.isInstalled) {
      return PythonInstallResult(
        success: false,
        error: 'Python not installed',
        message: 'Please install Python first.',
      );
    }

    final pythonCommand = check.executablePath ?? 'python3';
    final missing = check.missingPackages;

    if (missing.isEmpty) {
      return PythonInstallResult(
        success: true,
        message: 'All required packages are already installed.',
      );
    }

    try {
      // Try pip3 first
      ProcessResult result = await Process.run(
        '${pythonCommand} -m pip',
        ['install', ...missing],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        // Verify installation
        final verifyCheck = await checkPythonInstallation();
        if (verifyCheck.hasRequiredPackages) {
          return PythonInstallResult(
            success: true,
            message: 'Successfully installed: ${missing.join(', ')}',
          );
        }
      }

      // If pip3 failed, try pip
      result = await Process.run(
        '${pythonCommand} -m pip',
        ['install', ...missing],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final verifyCheck = await checkPythonInstallation();
        if (verifyCheck.hasRequiredPackages) {
          return PythonInstallResult(
            success: true,
            message: 'Successfully installed: ${missing.join(', ')}',
          );
        }
      }

      return PythonInstallResult(
        success: false,
        error: 'Failed to install packages',
        message: 'Could not install required packages. Please run manually:\n'
            '$pythonCommand -m pip install ${missing.join(' ')}',
      );
    } catch (e) {
      return PythonInstallResult(
        success: false,
        error: e.toString(),
        message: 'Error installing packages: $e\n\n'
            'Please run manually:\n'
            '$pythonCommand -m pip install ${missing.join(' ')}',
      );
    }
  }

  /// Get Python executable path (for running scripts)
  Future<String?> getPythonExecutable() async {
    final check = await checkPythonInstallation();
    if (check.isInstalled) {
      return check.executablePath ?? (Platform.isWindows ? 'python' : 'python3');
    }
    return null;
  }

  /// Get installation instructions as formatted text
  String getInstallationInstructions(PythonCheckResult check) {
    if (check.isInstalled && check.hasRequiredPackages) {
      return 'Python is installed and ready!';
    }

    final buffer = StringBuffer();
    
    if (!check.isInstalled) {
      buffer.writeln('Python is not installed.\n');
      
      if (Platform.isMacOS) {
        buffer.writeln('macOS Installation:');
        buffer.writeln('1. Visit https://www.python.org/downloads/');
        buffer.writeln('2. Download Python 3.8 or later');
        buffer.writeln('3. Run the installer\n');
        buffer.writeln('Or use Homebrew:');
        buffer.writeln('  brew install python3');
      } else if (Platform.isWindows) {
        buffer.writeln('Windows Installation:');
        buffer.writeln('1. Visit https://www.python.org/downloads/');
        buffer.writeln('2. Download Python 3.8 or later');
        buffer.writeln('3. Run the installer');
        buffer.writeln('4. IMPORTANT: Check "Add Python to PATH" during installation\n');
        buffer.writeln('Or use winget (Windows 10/11):');
        buffer.writeln('  winget install Python.Python.3.12');
      } else if (Platform.isLinux) {
        buffer.writeln('Linux Installation:');
        buffer.writeln('Ubuntu/Debian:');
        buffer.writeln('  sudo apt-get install python3 python3-pip');
        buffer.writeln('Fedora/RHEL:');
        buffer.writeln('  sudo dnf install python3 python3-pip');
        buffer.writeln('Arch:');
        buffer.writeln('  sudo pacman -S python python-pip');
      }
    }

    if (check.isInstalled && !check.hasRequiredPackages) {
      buffer.writeln('\nMissing Python packages: ${check.missingPackages.join(', ')}');
      buffer.writeln('\nTo install, run:');
      final pythonCmd = check.executablePath ?? 'python3';
      buffer.writeln('  $pythonCmd -m pip install ${check.missingPackages.join(' ')}');
    }

    return buffer.toString();
  }
}

/// Provider for PythonService
final pythonServiceProvider = Provider<PythonService>((ref) {
  return PythonService();
});

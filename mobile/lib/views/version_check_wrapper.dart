import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import '../config/api_config.dart';

class VersionCheckWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const VersionCheckWrapper({super.key, required this.child});

  @override
  ConsumerState<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends ConsumerState<VersionCheckWrapper> {
  bool _isLoading = true;
  bool _needsUpdate = false;
  String? _apkUrl;
  bool _isMandatory = true;
  String? _errorMessage;

  // Download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  String? _updateError;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final packageInfo = await PackageInfo.fromPlatform();
    final localVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    final localVersionName = packageInfo.version;
    debugPrint('Local Version: $localVersionName+$localVersionCode');

    int maxRetries = 4;
    int retryDelaySeconds = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Checking for update: Attempt $attempt of $maxRetries');
        final response = await http
            .get(Uri.parse(ApiConfig.appVersion))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            final serverVersionCode = data['versionCode'] as int;
            final serverVersionName = data['versionName'] as String;
            final apkUrl = data['apkUrl'] as String;
            final isMandatory = data['isMandatory'] ?? true;

            debugPrint('Server Version: $serverVersionName+$serverVersionCode');

            if (serverVersionCode > localVersionCode) {
              setState(() {
                _needsUpdate = true;
                _apkUrl = apkUrl;
                _isMandatory = isMandatory;
                _isLoading = false;
              });
              return;
            }

            // No update needed or success condition met
            setState(() {
              _needsUpdate = false;
              _isLoading = false;
            });
            return;
          }
        }
      } catch (e) {
        debugPrint('Version check attempt $attempt error: $e');
        if (attempt < maxRetries) {
          debugPrint('Waiting $retryDelaySeconds seconds before retrying...');
          await Future.delayed(Duration(seconds: retryDelaySeconds));
          retryDelaySeconds += 3;
          continue;
        }
      }
    }

    // All retries failed
    setState(() {
      _errorMessage = 'Unable to check for updates. Please verify your connection.';
      _isLoading = false;
    });
  }

  void _startUpdate() {
    if (_apkUrl == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Initializing download...';
      _updateError = null;
    });

    try {
      OtaUpdate().execute(
        _apkUrl!,
        destinationFilename: 'app-release.apk',
      ).listen(
        (OtaEvent event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final val = double.tryParse(event.value ?? '0') ?? 0.0;
              setState(() {
                _downloadProgress = val;
                _downloadStatus = 'Downloading: ${val.toStringAsFixed(0)}%';
              });
              break;
            case OtaStatus.INSTALLING:
              setState(() {
                _downloadStatus = 'Opening system installer...';
              });
              break;
            case OtaStatus.INSTALLATION_DONE:
              setState(() {
                _isDownloading = false;
                _needsUpdate = false;
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setState(() {
                _isDownloading = false;
                _updateError = 'Installation permissions not granted.';
              });
              break;
            case OtaStatus.DOWNLOAD_ERROR:
              setState(() {
                _isDownloading = false;
                _updateError = 'Download failed. Check your internet connection.';
              });
              break;
            case OtaStatus.INTERNAL_ERROR:
              setState(() {
                _isDownloading = false;
                _updateError = 'Internal error during background installation.';
              });
              break;
            default:
              setState(() {
                _isDownloading = false;
                _updateError = 'Update failed. Code: ${event.status}';
              });
          }
        },
        onError: (err) {
          setState(() {
            _isDownloading = false;
            _updateError = 'Error occurred: $err';
          });
        },
      );
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _updateError = 'Failed to execute update process: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF030712),
        body: Center(
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF030712),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connection Error',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _checkForUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Retry Connection',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_needsUpdate) {
      return Scaffold(
        backgroundColor: const Color(0xFF030712),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App update icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.system_update_rounded,
                      size: 48,
                      color: Colors.amber[400],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'UPDATE REQUIRED',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A new version of the Grandmaster Lobby application is available. It is mandatory to update the app to continue playing.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  if (!_isDownloading) ...[
                    // Download CTA
                    ElevatedButton.icon(
                      onPressed: _startUpdate,
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      label: Text(
                        'UPDATE NOW',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 5,
                      ),
                    ),
                    if (_updateError != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _updateError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ]
                  ] else ...[
                    // Download progress section
                    Text(
                      _downloadStatus,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.teal[300],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _downloadProgress / 100.0,
                        backgroundColor: Colors.white12,
                        color: Colors.teal[400],
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_downloadProgress.toStringAsFixed(0)}%',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    // No update required: proceed to child app flow
    return widget.child;
  }
}

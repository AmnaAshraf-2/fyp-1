import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import "package:flutter_sound/flutter_sound.dart";
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:io' as io if (dart.library.html) 'package:logistics_app/services/file_stub.dart' as io;

/// Cross-platform audio recorder using flutter_sound
/// Works on Android, iOS, Web, Windows, macOS, and Linux
class AudioRecorderService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  
  bool _isInitialized = false;
  String? _recordedFilePath;  // for mobile platforms
  Uint8List? _recordedBytes;   // for web platform

  /// Initialize the recorder and player
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Request microphone permission (not needed on web)
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          throw Exception('Microphone permission denied');
        }
      }

      await _recorder.openRecorder();
      await _player.openPlayer();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing audio recorder: $e');
      rethrow;
    }
  }

  /// Start recording audio
  Future<void> startRecording() async {
    if (!_isInitialized) {
      await init();
    }

    try {
      final String fileName = "audio_${DateTime.now().millisecondsSinceEpoch}.aac";
      
      if (kIsWeb) {
        // On web, record to memory (toFile: null)
        await _recorder.startRecorder(
          toFile: null,
          codec: Codec.aacMP4,
        );
      } else {
        // On mobile/desktop, record to file
        await _recorder.startRecorder(
          toFile: fileName,
          codec: Codec.aacMP4,
        );
      }
    } catch (e) {
      print('Error starting recording: $e');
      rethrow;
    }
  }

  /// Stop recording and save the audio
  Future<void> stopRecording() async {
    if (!_isInitialized) return;

    try {
      final result = await _recorder.stopRecorder();
      
      if (kIsWeb) {
        // On web, result is a blob URL - we need to fetch the bytes
        if (result != null) {
          // For web, we'll use the path directly for playback
          // and convert to bytes when uploading
          _recordedFilePath = result;
          _recordedBytes = null; // Will be fetched during upload
        }
      } else {
        // On mobile/desktop, result is the file path
        _recordedFilePath = result;
        _recordedBytes = null;
      }
    } catch (e) {
      print('Error stopping recording: $e');
      rethrow;
    }
  }

  /// Check if currently recording
  Future<bool> isRecording() async {
    if (!_isInitialized) return false;
    return await _recorder.isRecording;
  }

  /// Play the recorded audio
  Future<void> play() async {
    if (!_isInitialized) return;
    if (_recordedFilePath == null) return;

    try {
      if (kIsWeb) {
        // On web, use the blob URL directly
        await _player.startPlayer(
          fromURI: _recordedFilePath!,
          codec: Codec.aacMP4,
        );
      } else {
        // On mobile/desktop, use file path
        await _player.startPlayer(
          fromURI: _recordedFilePath!,
          codec: Codec.aacMP4,
        );
      }
    } catch (e) {
      print('Error playing audio: $e');
      rethrow;
    }
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    if (!_isInitialized) return;
    try {
      await _player.stopPlayer();
    } catch (e) {
      print('Error stopping playback: $e');
    }
  }

  /// Pause playback
  Future<void> pausePlayback() async {
    if (!_isInitialized) return;
    try {
      await _player.pausePlayer();
    } catch (e) {
      print('Error pausing playback: $e');
    }
  }

  /// Resume playback
  Future<void> resumePlayback() async {
    if (!_isInitialized) return;
    try {
      await _player.resumePlayer();
    } catch (e) {
      print('Error resuming playback: $e');
    }
  }

  /// Check if currently playing
  Future<bool> isPlaying() async {
    if (!_isInitialized) return false;
    return await _player.isPlaying;
  }

  /// Get playback position
  Future<Duration?> getPosition() async {
    if (!_isInitialized) return null;
    try {
      return await _player.getCurrentPosition();
    } catch (e) {
      return null;
    }
  }

  /// Get playback duration
  Future<Duration?> getDuration() async {
    if (!_isInitialized) return null;
    try {
      return await _player.getDuration();
    } catch (e) {
      return null;
    }
  }

  /// Stream of playback position updates
  Stream<Duration>? get onPositionChanged {
    if (!_isInitialized) return null;
    return _player.onProgress?.map((progress) => progress.position);
  }

  /// Stream for when playback completes
  Stream<void>? get onPlayerComplete {
    if (!_isInitialized) return null;
    return _player.onProgress?.where((progress) => progress.position >= (progress.duration ?? Duration.zero)).map((_) => null);
  }

  /// Upload recorded audio to Firebase Storage
  /// Returns the download URL
  Future<String> uploadToFirebase() async {
    if (_recordedFilePath == null) {
      throw Exception('No audio recorded');
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('audio_notes')
          .child('${timestamp}.aac');

      UploadTask task;

      if (kIsWeb) {
        // On web, fetch the blob as bytes
        if (_recordedBytes == null && _recordedFilePath != null) {
          // Fetch the blob URL as bytes using http package
          final response = await http.get(Uri.parse(_recordedFilePath!));
          if (response.statusCode == 200) {
            _recordedBytes = response.bodyBytes;
          } else {
            throw Exception('Failed to fetch audio bytes: ${response.statusCode}');
          }
        }
        
        if (_recordedBytes == null) {
          throw Exception('Failed to get audio bytes');
        }
        
        task = ref.putData(
          _recordedBytes!,
          SettableMetadata(contentType: 'audio/mp4'),
        );
      } else {
        // On mobile/desktop, upload file directly
        final file = io.File(_recordedFilePath!);
        if (!file.existsSync()) {
          throw Exception('Audio file does not exist');
        }
        task = ref.putFile(
          file,
          SettableMetadata(contentType: 'audio/mp4'),
        );
      }

      final snapshot = await task;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading audio to Firebase: $e');
      rethrow;
    }
  }

  /// Get the recorded file path (for mobile) or bytes (for web)
  String? get recordedFilePath => _recordedFilePath;
  Uint8List? get recordedBytes => _recordedBytes;

  /// Check if audio is recorded
  bool get hasRecording => _recordedFilePath != null;

  /// Delete the recorded audio
  void deleteRecording() {
    if (!kIsWeb && _recordedFilePath != null) {
      try {
        final file = io.File(_recordedFilePath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        print('Error deleting audio file: $e');
      }
    }
    _recordedFilePath = null;
    _recordedBytes = null;
  }

  /// Dispose resources
  void dispose() {
    try {
      _player.closePlayer();
      _recorder.closeRecorder();
      _isInitialized = false;
    } catch (e) {
      print('Error disposing audio recorder: $e');
    }
  }
}


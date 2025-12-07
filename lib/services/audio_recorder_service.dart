import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  
  String? _recordingPath;
  bool _isRecording = false;
  bool _isPlaying = false;
  DateTime? _recordingStartTime;

  String? get path => _recordingPath;
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  /// Start recording audio
  Future<bool> startRecording() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('Microphone permission denied');
      }

      // Get directory for saving audio
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${directory.path}/audio_note_$timestamp.m4a';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      return true;
    } catch (e) {
      print('Error starting recording: $e');
      _isRecording = false;
      _recordingPath = null;
      return false;
    }
  }

  /// Stop recording
  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      if (path != null) {
        _recordingPath = path;
      }
      return _recordingPath;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Play the recorded audio
  Future<void> play() async {
    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      throw Exception('No audio file to play');
    }

    try {
      if (_isPlaying) {
        await _player.pause();
        _isPlaying = false;
      } else {
        await _player.play(DeviceFileSource(_recordingPath!));
        _isPlaying = true;

        // Listen for completion
        _player.onPlayerComplete.listen((_) {
          _isPlaying = false;
        });
      }
    } catch (e) {
      print('Error playing audio: $e');
      _isPlaying = false;
      rethrow;
    }
  }

  /// Play audio from URL (for driver/enterprise playback)
  Future<void> playFromUrl(String url) async {
    try {
      if (_isPlaying) {
        await _player.pause();
        _isPlaying = false;
      } else {
        await _player.play(UrlSource(url));
        _isPlaying = true;

        // Listen for completion
        _player.onPlayerComplete.listen((_) {
          _isPlaying = false;
        });
      }
    } catch (e) {
      print('Error playing audio from URL: $e');
      _isPlaying = false;
      rethrow;
    }
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    try {
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      print('Error stopping playback: $e');
    }
  }

  /// Upload audio to Firebase Storage
  Future<String?> upload({String? requestId}) async {
    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      throw Exception('No audio file to upload');
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final audioFile = File(_recordingPath!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = requestId != null
          ? '${user.uid}_${requestId}_$timestamp.m4a'
          : '${user.uid}_$timestamp.m4a';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('audio_notes')
          .child(fileName);

      await storageRef.putFile(audioFile);
      final downloadUrl = await storageRef.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading audio: $e');
      rethrow;
    }
  }

  /// Delete the local recording
  void deleteRecording() {
    if (_recordingPath != null) {
      try {
        final file = File(_recordingPath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        print('Error deleting recording: $e');
      }
    }
    _recordingPath = null;
    _isRecording = false;
    _isPlaying = false;
  }

  /// Get recording duration
  Duration? getRecordingDuration() {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Dispose resources
  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}


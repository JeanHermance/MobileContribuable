import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as path;

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const Duration _defaultCacheDuration = Duration(minutes: 10);
  static const String _cachePrefix = 'cache_';

  /// Get the directory where cache files are stored
  Future<Directory> _getCacheDirectory() async {
    final directory = await getTemporaryDirectory();
    final cacheDir = Directory(path.join(directory.path, 'api_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Get the file for a specific key
  Future<File> _getCacheFile(String key) async {
    final dir = await _getCacheDirectory();
    // Sanitize key to be a valid filename
    final safeKey = key.replaceAll(RegExp(r'[^\w\d_]'), '_');
    return File(path.join(dir.path, '$_cachePrefix$safeKey.json'));
  }

  // Cache data with expiration
  Future<void> setCache(String key, dynamic data, {Duration? duration}) async {
    try {
      final file = await _getCacheFile(key);
      
      final cacheObject = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': data,
        'duration_ms': (duration ?? _defaultCacheDuration).inMilliseconds,
      };
      
      final jsonData = jsonEncode(cacheObject);
      await file.writeAsString(jsonData);
      
      debugPrint('Cache set for key: $key (File: ${file.path})');
    } catch (e) {
      debugPrint('Error setting cache for key $key: $e');
    }
  }

  // Get cached data if not expired
  Future<T?> getCache<T>(String key, {Duration? duration}) async {
    try {
      final file = await _getCacheFile(key);
      
      if (!await file.exists()) {
        return null;
      }
      
      final content = await file.readAsString();
      if (content.isEmpty) return null;
      
      final Map<String, dynamic> cacheObject = jsonDecode(content);
      
      final timestamp = cacheObject['timestamp'] as int?;
      final storedDurationMs = cacheObject['duration_ms'] as int?;
      final data = cacheObject['data'];
      
      if (timestamp == null || data == null) {
        return null;
      }
      
      // Use provided duration or stored duration or default
      final effectiveDuration = duration ?? 
                               (storedDurationMs != null ? Duration(milliseconds: storedDurationMs) : _defaultCacheDuration);
      
      final expirationTime = timestamp + effectiveDuration.inMilliseconds;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      if (currentTime > expirationTime) {
        // Cache expired, remove it
        await file.delete();
        debugPrint('Cache expired for key: $key');
        return null;
      }
      
      debugPrint('Cache hit for key: $key');
      return data as T;
    } catch (e) {
      debugPrint('Error getting cache for key $key: $e');
      // If file is corrupted, delete it
      try {
        final file = await _getCacheFile(key);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      return null;
    }
  }

  // Clear specific cache
  Future<void> clearCache(String key) async {
    try {
      final file = await _getCacheFile(key);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Cache cleared for key: $key');
      }
    } catch (e) {
      debugPrint('Error clearing cache for key $key: $e');
    }
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    try {
      final dir = await _getCacheDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('All cache cleared (Directory deleted)');
      }
    } catch (e) {
      debugPrint('Error clearing all cache: $e');
    }
  }

  // Check if cache exists and is valid
  Future<bool> isCacheValid(String key, {Duration? duration}) async {
    try {
      final file = await _getCacheFile(key);
      
      if (!await file.exists()) {
        return false;
      }
      
      final content = await file.readAsString();
      final Map<String, dynamic> cacheObject = jsonDecode(content);
      
      final timestamp = cacheObject['timestamp'] as int?;
      final storedDurationMs = cacheObject['duration_ms'] as int?;
      
      if (timestamp == null) {
        return false;
      }
      
      final effectiveDuration = duration ?? 
                               (storedDurationMs != null ? Duration(milliseconds: storedDurationMs) : _defaultCacheDuration);
      
      final expirationTime = timestamp + effectiveDuration.inMilliseconds;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      return currentTime <= expirationTime;
    } catch (e) {
      debugPrint('Error checking cache validity for key $key: $e');
      return false;
    }
  }

  // Get cache size info
  Future<Map<String, int>> getCacheInfo() async {
    try {
      final dir = await _getCacheDirectory();
      if (!await dir.exists()) {
        return {'count': 0, 'size': 0};
      }
      
      int cacheCount = 0;
      int totalSize = 0;
      
      await for (final entity in dir.list()) {
        if (entity is File) {
          cacheCount++;
          totalSize += await entity.length();
        }
      }
      
      return {
        'count': cacheCount,
        'size': totalSize,
      };
    } catch (e) {
      debugPrint('Error getting cache info: $e');
      return {'count': 0, 'size': 0};
    }
  }
}

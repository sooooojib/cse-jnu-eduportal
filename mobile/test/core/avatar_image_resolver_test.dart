import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/core/utils/avatar_image_resolver.dart';

void main() {
  group('AvatarImageResolver Tests', () {
    test('returns null for null, empty or whitespace strings', () {
      expect(AvatarImageResolver.resolve(null), isNull);
      expect(AvatarImageResolver.resolve(''), isNull);
      expect(AvatarImageResolver.resolve('   '), isNull);
    });

    test('returns MemoryImage for valid base64 data URI', () {
      final sampleBytes = utf8.encode('fake-image-bytes');
      final base64String = base64Encode(sampleBytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';

      final provider = AvatarImageResolver.resolve(dataUri);
      expect(provider, isA<MemoryImage>());
    });

    test('returns NetworkImage for valid http and https URLs with valid host', () {
      final validHttps = 'https://images.unsplash.com/photo-1534528741775';
      final provider = AvatarImageResolver.resolve(validHttps);
      expect(provider, isA<NetworkImage>());
      expect((provider as NetworkImage).url, equals(validHttps));
    });

    test('returns null for malformed http URLs with no host', () {
      expect(AvatarImageResolver.resolve('http:///malformed-path'), isNull);
      expect(AvatarImageResolver.resolve('https:///no-host/test.jpg'), isNull);
    });

    test('safely returns null (never NetworkImage) for file:/// URIs when file does not exist', () {
      const fileUri = 'file:///data/user/0/bd.ac.jnu.cse.cse_jnu_eduportal/cache/scaled_1000128381.jpg';
      final provider = AvatarImageResolver.resolve(fileUri);
      // Must NOT return NetworkImage (which would cause "No host specified in URI")
      expect(provider, isNull);
    });

    test('safely returns null (never NetworkImage) for raw filesystem paths when file does not exist', () {
      const rawPath = '/data/user/0/bd.ac.jnu.cse.cse_jnu_eduportal/cache/scaled_1000128381.jpg';
      final provider = AvatarImageResolver.resolve(rawPath);
      expect(provider, isNull);
    });

    test('returns FileImage when local file actually exists on device', () {
      final tempFile = File('${Directory.systemTemp.path}/test_avatar.jpg');
      tempFile.writeAsStringSync('dummy');
      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });

      final providerByPath = AvatarImageResolver.resolve(tempFile.path);
      expect(providerByPath, isA<FileImage>());

      final providerByUri = AvatarImageResolver.resolve('file://${tempFile.path}');
      expect(providerByUri, isA<FileImage>());
    });
  });
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cse_jnu_eduportal/core/storage/cloud_storage_service.dart';

class MockFirebaseStorage extends Mock implements FirebaseStorage {}
class MockReference extends Mock implements Reference {}
class MockTaskSnapshot extends Mock implements TaskSnapshot {}
class FakeSettableMetadata extends Fake implements SettableMetadata {}

class FakeUploadTask extends Fake implements UploadTask {
  final TaskSnapshot snapshot;
  FakeUploadTask(this.snapshot);

  @override
  Future<S> then<S>(FutureOr<S> Function(TaskSnapshot) onValue, {Function? onError}) {
    return Future.value(snapshot).then(onValue, onError: onError);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseStorage mockStorage;
  late MockReference mockTargetRef;
  late FakeUploadTask fakeUploadTask;
  late MockTaskSnapshot mockSnapshot;
  late CloudStorageServiceImpl storageService;

  setUpAll(() {
    registerFallbackValue(FakeSettableMetadata());
    registerFallbackValue(File(''));
  });

  setUp(() {
    mockStorage = MockFirebaseStorage();
    mockTargetRef = MockReference();
    mockSnapshot = MockTaskSnapshot();
    fakeUploadTask = FakeUploadTask(mockSnapshot);

    when(() => mockStorage.ref(any())).thenReturn(mockTargetRef);
    when(() => mockStorage.refFromURL(any())).thenReturn(mockTargetRef);
    when(() => mockTargetRef.child(any())).thenReturn(mockTargetRef);
    when(() => mockTargetRef.putFile(any(), any())).thenAnswer((_) => fakeUploadTask);
    when(() => mockSnapshot.ref).thenReturn(mockTargetRef);
    when(() => mockTargetRef.getDownloadURL()).thenAnswer((_) async => 'https://firebasestorage.googleapis.com/v0/b/app/o/file.jpg?alt=media');
    when(() => mockTargetRef.delete()).thenAnswer((_) async {});

    storageService = CloudStorageServiceImpl(storage: mockStorage);
  });

  group('STAGE 26: Cloud Storage Service & Path Security Tests', () {
    test('1. StoragePathBuilder generates secure canonical paths for all approved scopes', () {
      final feedPath = StoragePathBuilder.feedbackAttachment(
        feedbackId: 'fb_101',
        attachmentId: 'att_1',
        fileName: 'screenshot.png',
      );
      expect(feedPath, 'feedback/fb_101/attachments/att_1_screenshot.png');
      expect(StoragePathBuilder.isApprovedPath(feedPath), isTrue);

      final replyPath = StoragePathBuilder.feedbackReplyAttachment(
        feedbackId: 'fb_101',
        attachmentId: 'att_2',
        fileName: 'clarification.pdf',
      );
      expect(replyPath, 'feedback/fb_101/replies/att_2_clarification.pdf');
      expect(StoragePathBuilder.isApprovedPath(replyPath), isTrue);

      final noticePath = StoragePathBuilder.noticeAttachment(
        noticeId: 'notice_5',
        fileName: 'routine.pdf',
      );
      expect(noticePath, 'notices/notice_5/routine.pdf');
      expect(StoragePathBuilder.isApprovedPath(noticePath), isTrue);

      final avatarPath = StoragePathBuilder.avatar(
        userId: 'user_42',
        fileName: 'profile.jpg',
      );
      expect(avatarPath, 'avatars/user_42/profile.jpg');
      expect(StoragePathBuilder.isApprovedPath(avatarPath), isTrue);

      final counselPath = StoragePathBuilder.counselingAttachment(
        bookingId: 'book_7',
        attachmentId: 'att_3',
        fileName: 'grades.pdf',
      );
      expect(counselPath, 'counseling/book_7/att_3_grades.pdf');
      expect(StoragePathBuilder.isApprovedPath(counselPath), isTrue);
    });

    test('2. StoragePathBuilder blocks arbitrary paths, root paths, and path traversal', () {
      expect(StoragePathBuilder.isApprovedPath('system/keys.json'), isFalse);
      expect(StoragePathBuilder.isApprovedPath('../etc/passwd'), isFalse);
      expect(StoragePathBuilder.isApprovedPath('/notices/file.pdf'), isFalse);
      expect(StoragePathBuilder.isApprovedPath('feedback/../secret.pem'), isFalse);
      expect(StoragePathBuilder.isApprovedPath('arbitrary/folder/image.png'), isFalse);
    });

    test('3. MIME type resolver identifies allowed images and documents', () {
      expect(CloudStorageServiceImpl.resolveMimeType('photo.jpg', isImageOnly: true), 'image/jpeg');
      expect(CloudStorageServiceImpl.resolveMimeType('photo.jpeg', isImageOnly: true), 'image/jpeg');
      expect(CloudStorageServiceImpl.resolveMimeType('graphic.png', isImageOnly: true), 'image/png');
      expect(CloudStorageServiceImpl.resolveMimeType('asset.webp', isImageOnly: true), 'image/webp');
      expect(CloudStorageServiceImpl.resolveMimeType('document.pdf'), 'application/pdf');
      expect(CloudStorageServiceImpl.resolveMimeType('notes.txt'), 'text/plain');
      expect(CloudStorageServiceImpl.resolveMimeType('report.docx'), 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    });

    test('4. MIME type resolver rejects unsupported or dangerous extensions', () {
      expect(
        () => CloudStorageServiceImpl.resolveMimeType('malware.exe'),
        throwsA(isA<StorageUnsupportedFileTypeException>()),
      );
      expect(
        () => CloudStorageServiceImpl.resolveMimeType('script.sh'),
        throwsA(isA<StorageUnsupportedFileTypeException>()),
      );
      expect(
        () => CloudStorageServiceImpl.resolveMimeType('document.pdf', isImageOnly: true),
        throwsA(isA<StorageUnsupportedFileTypeException>()),
      );
      expect(
        () => CloudStorageServiceImpl.resolveMimeType('no_extension'),
        throwsA(isA<StorageUnsupportedFileTypeException>()),
      );
    });

    test('5. Rejects upload when unauthenticated / missing uploadedBy UID', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final tempFile = File('${tempDir.path}/test_upload.jpg')..createSync(recursive: true);
      await tempFile.writeAsBytes(List.filled(100, 0), flush: true);

      try {
        expect(
          () => storageService.uploadFile(
            file: tempFile,
            storagePath: 'avatars/u1/photo.jpg',
            uploadedBy: '',
          ),
          throwsA(isA<StorageUnauthorizedException>()),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('6. Rejects upload when target path is not within approved scopes', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final tempFile = File('${tempDir.path}/test_upload.jpg')..createSync(recursive: true);
      await tempFile.writeAsBytes(List.filled(100, 0), flush: true);

      try {
        expect(
          () => storageService.uploadFile(
            file: tempFile,
            storagePath: 'unapproved_folder/test.jpg',
            uploadedBy: 'user_1',
          ),
          throwsA(isA<StoragePathValidationException>()),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('7. Rejects upload when image exceeds 5MB limit', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final tempFile = File('${tempDir.path}/oversized_image.jpg')..createSync(recursive: true);
      await tempFile.writeAsBytes(List.filled(5200 * 1024, 0), flush: true);

      try {
        await storageService.uploadFile(
          file: tempFile,
          storagePath: 'avatars/u1/photo.jpg',
          uploadedBy: 'user_1',
          isImageOnly: true,
        );
        fail('Expected StorageFileTooLargeException');
      } on StorageFileTooLargeException catch (e) {
        expect(e.maxBytes, 5 * 1024 * 1024);
        expect(e.actualBytes, 5200 * 1024);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('8. Authorized upload succeeds and attaches required metadata', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final tempFile = File('${tempDir.path}/valid_feedback.png')..createSync(recursive: true);
      await tempFile.writeAsBytes(List.filled(500, 0), flush: true);

      try {
        final result = await storageService.uploadFile(
          file: tempFile,
          storagePath: 'feedback/fb_1/attachments/att_1_valid_feedback.png',
          uploadedBy: 'student_42',
          customMetadata: {'scope': 'feedback'},
        );

        expect(result.downloadUrl, contains('https://firebasestorage.googleapis.com'));
        expect(result.storagePath, 'feedback/fb_1/attachments/att_1_valid_feedback.png');
        expect(result.contentType, 'image/png');
        expect(result.metadata['uploadedBy'], 'student_42');
        expect(result.metadata['scope'], 'feedback');

        verify(() => mockTargetRef.putFile(any(), any())).called(1);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('9. Authorized deletion successfully calls ref.delete()', () async {
      await storageService.deleteFile(
        storagePathOrUrl: 'feedback/fb_1/attachments/att_1.png',
        requestedBy: 'student_42',
      );

      verify(() => mockStorage.ref('feedback/fb_1/attachments/att_1.png')).called(1);
      verify(() => mockTargetRef.delete()).called(1);
    });

    test('10. Deletion rejects unauthenticated caller or unapproved path', () async {
      expect(
        () => storageService.deleteFile(
          storagePathOrUrl: 'feedback/fb_1/attachments/att_1.png',
          requestedBy: '',
        ),
        throwsA(isA<StorageUnauthorizedException>()),
      );

      expect(
        () => storageService.deleteFile(
          storagePathOrUrl: 'system/sensitive.key',
          requestedBy: 'user_1',
        ),
        throwsA(isA<StoragePathValidationException>()),
      );
    });

    test('11. Authorized download retrieves bytes with size safety limit', () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      when(() => mockTargetRef.getData(any())).thenAnswer((_) async => sampleBytes);

      final data = await storageService.downloadFileBytes(
        storagePathOrUrl: 'notices/n1/file.pdf',
        maxDownloadBytes: 5 * 1024 * 1024,
      );

      expect(data, sampleBytes);
      verify(() => mockTargetRef.getData(5 * 1024 * 1024)).called(1);
    });
  });
}

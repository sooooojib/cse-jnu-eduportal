/// App-wide feature switches.
class AppFeatures {
  AppFeatures._();

  /// Uploading files (photos, PDFs, documents) needs Firebase Storage, which is
  /// not set up on this project (it needs the paid Blaze plan). While this is
  /// false every "upload from phone" button is hidden. Notices can still attach
  /// a pasted link. Turn on once Storage is set up and `storage.rules` deployed.
  static const bool fileUploads = false;

  static const String uploadsOffMessage = 'Photo and file upload is not available yet.';
}

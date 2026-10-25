import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/cloud_storage_service.dart';
import '../../../../core/utils/avatar_image_resolver.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/repositories/user_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';

class StudentProfileDialog extends StatefulWidget {
  final User student;
  final Future<void> Function() onLogout;

  const StudentProfileDialog({
    super.key,
    required this.student,
    required this.onLogout,
  });

  static Future<void> show({
    required BuildContext context,
    required User student,
    required Future<void> Function() onLogout,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentProfileDialog(
        student: student,
        onLogout: onLogout,
      ),
    );
  }

  @override
  State<StudentProfileDialog> createState() => _StudentProfileDialogState();
}

class _StudentProfileDialogState extends State<StudentProfileDialog> {
  late User _currentStudent;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _localPhotoPath;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
    _nameController = TextEditingController(text: _currentStudent.fullName);
    _phoneController = TextEditingController(text: _currentStudent.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  ImageProvider? _resolveAvatarImage(String? url, String? localPath) {
    return AvatarImageResolver.resolve(url, localPath);
  }

  Future<void> _showPhotoPickerSheet(BuildContext context, bool isDark) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13263E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Profile Photo Source',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // 1. Photo Gallery
            _buildSourceOptionTile(
              icon: Icons.photo_library_rounded,
              iconColor: const Color(0xFF047857),
              title: 'Photo Gallery',
              subtitle: 'Choose a portrait from phone gallery',
              isDark: isDark,
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),

            // 2. Camera
            _buildSourceOptionTile(
              icon: Icons.camera_alt_rounded,
              iconColor: const Color(0xFF2563EB),
              title: 'Camera',
              subtitle: 'Take a new student photo with phone camera',
              isDark: isDark,
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),

            // 3. Choose from Device Files / File System
            _buildSourceOptionTile(
              icon: Icons.folder_open_rounded,
              iconColor: const Color(0xFFD97706),
              title: 'Device Storage / Files',
              subtitle: 'Browse storage & file system for an image',
              isDark: isDark,
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUploadMedia();
              },
            ),

            if (_currentStudent.avatarUrl != null && _currentStudent.avatarUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildSourceOptionTile(
                icon: Icons.delete_outline_rounded,
                iconColor: const Color(0xFFDC2626),
                title: 'Remove Photo',
                subtitle: 'Revert to default initials avatar',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _removePhoto();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (picked != null) {
        await _uploadImageFile(picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadMedia() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMedia(
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (picked != null) {
        await _uploadImageFile(picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access file system: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _uploadImageFile(XFile pickedFile) async {
    setState(() {
      _isUploadingPhoto = true;
      _localPhotoPath = kIsWeb ? null : pickedFile.path;
    });

    String? uploadedUrl;
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = StoragePathBuilder.avatar(
      userId: widget.student.id,
      fileName: fileName,
    );

    Uint8List? fileBytes;
    try {
      fileBytes = await pickedFile.readAsBytes();
    } catch (_) {}

    // 1. Upload via CloudStorageService
    try {
      if (!kIsWeb && sl.isRegistered<CloudStorageService>()) {
        final storageService = sl<CloudStorageService>();
        final uploadResult = await storageService.uploadFile(
          file: File(pickedFile.path),
          storagePath: storagePath,
          uploadedBy: widget.student.id,
          isImageOnly: true,
        );
        uploadedUrl = uploadResult.downloadUrl;
      } else {
        final storageRef = FirebaseStorage.instance.ref(storagePath);
        UploadTask uploadTask;
        if (kIsWeb && fileBytes != null) {
          uploadTask = storageRef.putData(
            fileBytes,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {'uploadedBy': widget.student.id},
            ),
          );
        } else {
          uploadTask = storageRef.putFile(
            File(pickedFile.path),
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {'uploadedBy': widget.student.id},
            ),
          );
        }
        await uploadTask.timeout(const Duration(milliseconds: 4000));
        uploadedUrl = await storageRef.getDownloadURL();
      }
    } catch (e) {
      debugPrint('Student avatar upload error: $e');
      fileBytes ??= await pickedFile.readAsBytes().catchError((_) => Uint8List(0));
      if (fileBytes.isNotEmpty) {
        uploadedUrl = 'data:image/jpeg;base64,${base64Encode(fileBytes)}';
      } else {
        uploadedUrl = null;
      }
    }

    // 2. Persist to Firestore and AuthController
    try {
      if (sl.isRegistered<UserRepository>()) {
        final repo = sl<UserRepository>();
        await repo.updateProfile(
          uid: _currentStudent.id,
          avatarUrl: uploadedUrl,
        );
      }

      final updatedUser = _currentStudent.copyWith(avatarUrl: uploadedUrl);

      if (sl.isRegistered<AuthController>()) {
        sl<AuthController>().updateUserProfile(updatedUser);
      }

      if (mounted) {
        setState(() {
          _currentStudent = updatedUser;
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo uploaded and updated successfully!'),
            backgroundColor: Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save avatar: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _isUploadingPhoto = true);
    try {
      if (sl.isRegistered<UserRepository>()) {
        final repo = sl<UserRepository>();
        await repo.updateProfile(
          uid: _currentStudent.id,
          avatarUrl: '',
        );
      }

      final updatedUser = _currentStudent.copyWith(avatarUrl: '');

      if (sl.isRegistered<AuthController>()) {
        sl<AuthController>().updateUserProfile(updatedUser);
      }

      if (mounted) {
        setState(() {
          _currentStudent = updatedUser;
          _localPhotoPath = null;
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed.'),
            backgroundColor: Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove photo: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSaveProfile() async {
    final newName = _nameController.text.trim();
    final newPhone = _phoneController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full name cannot be empty.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (sl.isRegistered<UserRepository>()) {
        final repo = sl<UserRepository>();
        await repo.updateProfile(
          uid: _currentStudent.id,
          fullName: newName,
          phone: newPhone,
        );
      }

      final updatedUser = _currentStudent.copyWith(
        fullName: newName,
        phone: newPhone,
      );

      if (sl.isRegistered<AuthController>()) {
        sl<AuthController>().updateUserProfile(updatedUser);
      }

      if (mounted) {
        setState(() {
          _currentStudent = updatedUser;
          _isEditing = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showUpgradeSemesterDialog(BuildContext context) {
    int targetYear = _currentStudent.year ?? 1;
    int targetSemester = _currentStudent.semester == 1 ? 2 : 1;
    if (_currentStudent.semester == 2 && targetYear < 4) {
      targetYear += 1;
    }
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Request Semester Upgrade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Submit an academic progression request to the department coordinator.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: targetYear,
                      decoration: InputDecoration(
                        labelText: 'Target Year',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => targetYear = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: targetSemester,
                      decoration: InputDecoration(
                        labelText: 'Target Sem',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [1, 2].map((s) => DropdownMenuItem(value: s, child: Text('Sem $s'))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => targetSemester = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dCtx);
                if (sl.isRegistered<ProfileController>()) {
                  try {
                    await sl<ProfileController>().requestUpgrade(
                      requestedYear: targetYear,
                      requestedSemester: targetSemester,
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Semester upgrade request submitted.'),
                          backgroundColor: Color(0xFF047857),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Request error: $e'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                }
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final avatarProvider = _resolveAvatarImage(_currentStudent.avatarUrl, _localPhotoPath);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13263E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + keyboardPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle & Action Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  tooltip: _isEditing ? 'Cancel Edit' : 'Edit Profile',
                  icon: Icon(
                    _isEditing ? Icons.close_rounded : Icons.edit_outlined,
                    size: 20,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  onPressed: () {
                    setState(() {
                      if (_isEditing) {
                        _nameController.text = _currentStudent.fullName;
                        _phoneController.text = _currentStudent.phone ?? '';
                      }
                      _isEditing = !_isEditing;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Profile Photo with Camera Badge (Same as Faculty)
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF047857).withValues(alpha: 0.3),
                      width: 2.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: isDark
                        ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                        : const Color(0xFFECFDF5),
                    backgroundImage: avatarProvider,
                    onBackgroundImageError: avatarProvider != null ? (_, __) {} : null,
                    child: avatarProvider == null
                        ? Text(
                            _currentStudent.fullName.isNotEmpty
                                ? _currentStudent.fullName.substring(0, 1).toUpperCase()
                                : (_currentStudent.role == UserRole.cr ? 'C' : 'S'),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF047857),
                            ),
                          )
                        : null,
                  ),
                ),
                if (_isUploadingPhoto)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isUploadingPhoto ? null : () => _showPhotoPickerSheet(context, isDark),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF047857),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF13263E) : Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Student Name (or Edit Field)
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
              Text(
                _currentStudent.fullName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),

            const SizedBox(height: 6),

            // RoleBadgeChip & Edit Info Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RoleBadgeChip(role: _currentStudent.role),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Edit Info'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF047857),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Account Details Card (Clean 4-row card matching exact design)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.business_outlined,
                    label: 'Department',
                    value: 'Computer Science & Engineering',
                    isDark: isDark,
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    icon: Icons.school_outlined,
                    label: 'Academic Term',
                    value: 'Year ${_currentStudent.year ?? "—"}, Semester ${_currentStudent.semester ?? "—"}',
                    isDark: isDark,
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Contact Phone',
                    value: (_currentStudent.phone != null && _currentStudent.phone!.isNotEmpty)
                        ? _currentStudent.phone!
                        : 'Tap to add phone',
                    isDark: isDark,
                    onTap: () => setState(() => _isEditing = true),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.palette_outlined,
                            size: 18,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Theme Mode',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const ThemeToggleButton(showBackground: true),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (!_isEditing) ...[
              // Upgrade Semester Action Tile
              InkWell(
                onTap: () => _showUpgradeSemesterDialog(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF047857).withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF047857).withValues(alpha: isDark ? 0.3 : 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.upgrade_rounded, color: Color(0xFF047857), size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Request Academic Semester Upgrade',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                    ],
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSaveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save Profile Changes',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final isCr = _currentStudent.role == UserRole.cr;
                  final confirmed = await AppConfirmationDialog.show(
                    context: context,
                    title: 'Sign Out?',
                    message: 'Are you sure you want to end your ${isCr ? "CR" : "student"} session and sign out?',
                    confirmText: 'Sign Out',
                    isDestructive: true,
                    icon: Icons.logout_rounded,
                  );
                  if (confirmed == true && mounted) {
                    Navigator.pop(context);
                    await widget.onLogout();
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                label: Text(
                  _currentStudent.role == UserRole.cr
                      ? 'Sign Out CR Session'
                      : 'Sign Out Student Session',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: onTap != null
                      ? const Color(0xFF047857)
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF047857)),
            ],
          ],
        ),
      ),
    );
  }
}

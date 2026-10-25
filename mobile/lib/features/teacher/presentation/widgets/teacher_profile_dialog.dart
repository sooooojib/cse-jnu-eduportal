import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/cloud_storage_service.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/repositories/user_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/utils/avatar_image_resolver.dart';

class TeacherProfileDialog extends StatefulWidget {
  final User teacher;
  final int assignedCoursesCount;
  final Future<void> Function() onLogout;

  const TeacherProfileDialog({
    super.key,
    required this.teacher,
    required this.assignedCoursesCount,
    required this.onLogout,
  });

  static Future<void> show({
    required BuildContext context,
    required User teacher,
    required int assignedCoursesCount,
    required Future<void> Function() onLogout,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TeacherProfileDialog(
        teacher: teacher,
        assignedCoursesCount: assignedCoursesCount,
        onLogout: onLogout,
      ),
    );
  }

  @override
  State<TeacherProfileDialog> createState() => _TeacherProfileDialogState();
}

class _TeacherProfileDialogState extends State<TeacherProfileDialog> {
  late User _currentTeacher;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _localPhotoPath;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _avatarController;

  @override
  void initState() {
    super.initState();
    _currentTeacher = widget.teacher;
    _nameController = TextEditingController(text: _currentTeacher.fullName);
    _phoneController = TextEditingController(text: _currentTeacher.phone ?? '');
    _avatarController = TextEditingController(text: _currentTeacher.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
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
              iconColor: const Color(0xFF6366F1),
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
              iconColor: const Color(0xFF047857),
              title: 'Camera',
              subtitle: 'Take a new faculty photo with phone camera',
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

            if (_currentTeacher.avatarUrl != null && _currentTeacher.avatarUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildSourceOptionTile(
                icon: Icons.delete_outline_rounded,
                iconColor: const Color(0xFFDC2626),
                title: 'Remove Photo',
                subtitle: 'Revert to faculty initial avatar',
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
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
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
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
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
      userId: widget.teacher.id,
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
          uploadedBy: widget.teacher.id,
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
              customMetadata: {'uploadedBy': widget.teacher.id},
            ),
          );
        } else {
          uploadTask = storageRef.putFile(
            File(pickedFile.path),
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {'uploadedBy': widget.teacher.id},
            ),
          );
        }
        await uploadTask.timeout(const Duration(milliseconds: 3000));
        uploadedUrl = await storageRef.getDownloadURL();
      }
    } catch (e) {
      debugPrint('Cloud storage avatar upload error: $e');
      fileBytes ??= await pickedFile.readAsBytes().catchError((_) => Uint8List(0));
      if (fileBytes.isNotEmpty) {
        uploadedUrl = 'data:image/jpeg;base64,${base64Encode(fileBytes)}';
      } else {
        uploadedUrl = null;
      }
    }

    // 3. Persist to Firestore and state
    try {
      if (sl.isRegistered<UserRepository>()) {
        final repo = sl<UserRepository>();
        await repo.updateProfile(
          uid: _currentTeacher.id,
          avatarUrl: uploadedUrl,
        );
      }

      final updatedUser = _currentTeacher.copyWith(avatarUrl: uploadedUrl);

      if (sl.isRegistered<AuthController>()) {
        sl<AuthController>().updateUserProfile(updatedUser);
      }

      if (mounted) {
        setState(() {
          _currentTeacher = updatedUser;
          _avatarController.text = uploadedUrl ?? '';
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
          uid: _currentTeacher.id,
          avatarUrl: '',
        );
      }

      final updatedUser = _currentTeacher.copyWith(avatarUrl: '');

      if (sl.isRegistered<AuthController>()) {
        sl<AuthController>().updateUserProfile(updatedUser);
      }

      if (mounted) {
        setState(() {
          _currentTeacher = updatedUser;
          _avatarController.text = '';
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
    final newAvatar = _avatarController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faculty name cannot be empty.'),
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
          uid: _currentTeacher.id,
          fullName: newName,
          phone: newPhone,
          avatarUrl: newAvatar.isNotEmpty ? newAvatar : null,
        );
      }

      final updatedUser = _currentTeacher.copyWith(
        fullName: newName,
        phone: newPhone,
        avatarUrl: newAvatar.isNotEmpty ? newAvatar : null,
      );

      if (sl.isRegistered<AuthController>()) {
        sl<AuthController>().updateUserProfile(updatedUser);
      }

      if (mounted) {
        setState(() {
          _currentTeacher = updatedUser;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final avatarProvider = _resolveAvatarImage(_currentTeacher.avatarUrl, _localPhotoPath);

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
                        _nameController.text = _currentTeacher.fullName;
                        _phoneController.text = _currentTeacher.phone ?? '';
                        _avatarController.text = _currentTeacher.avatarUrl ?? '';
                      }
                      _isEditing = !_isEditing;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Avatar & Identity with Camera Badge
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: () => _showPhotoPickerSheet(context, isDark),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: isDark
                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                            : const Color(0xFFEFF6FF),
                        backgroundImage: avatarProvider,
                        onBackgroundImageError: avatarProvider != null ? (_, __) {} : null,
                        child: (avatarProvider == null)
                            ? Text(
                                _currentTeacher.fullName.isNotEmpty
                                    ? _currentTeacher.fullName.substring(0, 1).toUpperCase()
                                    : (_currentTeacher.role == UserRole.admin ? 'A' : 'P'),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1D4ED8),
                                ),
                              )
                            : null,
                      ),
                      if (_isUploadingPhoto)
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
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
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showPhotoPickerSheet(context, isDark),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF13263E) : Colors.white,
                        width: 2.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_isEditing)
              _buildEditForm(isDark)
            else
              _buildViewContent(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildViewContent(bool isDark) {
    return Column(
      children: [
        Text(
          _currentTeacher.fullName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _currentTeacher.email,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoleBadgeChip(role: _currentTeacher.role),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: const Text('Edit Info'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.primaryLight,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Details List (Zero overflow with flexible constraints)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE2E8F0),
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
              if (_currentTeacher.role == UserRole.admin) ...[
                _buildDetailRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Access Level',
                  value: 'Full System Control',
                  isDark: isDark,
                ),
              ] else ...[
                _buildDetailRow(
                  icon: Icons.menu_book_outlined,
                  label: 'Assigned Courses',
                  value: '${widget.assignedCoursesCount} Courses',
                  isDark: isDark,
                ),
              ],
              const Divider(height: 20),
              _buildDetailRow(
                icon: Icons.phone_outlined,
                label: 'Contact Phone',
                value: (_currentTeacher.phone != null && _currentTeacher.phone!.isNotEmpty)
                    ? _currentTeacher.phone!
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

        const SizedBox(height: 20),

        // Logout Action
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final isAdm = _currentTeacher.role == UserRole.admin;
              final confirmed = await AppConfirmationDialog.show(
                context: context,
                title: 'Sign Out?',
                message: 'Are you sure you want to end your ${isAdm ? "administrator" : "faculty"} session and sign out?',
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
              _currentTeacher.role == UserRole.admin
                  ? 'Sign Out Admin Session'
                  : 'Sign Out Faculty Session',
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
    );
  }

  Widget _buildEditForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            _currentTeacher.role == UserRole.admin
                ? 'Edit Administrator Profile'
                : 'Edit Faculty Profile',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Button to pick photo from phone / file system
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showPhotoPickerSheet(context, isDark),
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Upload Photo from Phone / Files'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryLight,
              side: const BorderSide(color: AppColors.primaryLight),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Name Field
        Text(
          'Full Name',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'Enter faculty full name',
            prefixIcon: const Icon(Icons.person_outline, size: 20),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Phone Field
        Text(
          'Contact Phone',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'e.g. +8801711223344',
            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Avatar URL Field (Optional manual input)
        Text(
          'Avatar Image URL (Optional)',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _avatarController,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'https://... or photo chosen above',
            prefixIcon: const Icon(Icons.link_rounded, size: 20),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _nameController.text = _currentTeacher.fullName;
                          _phoneController.text = _currentTeacher.phone ?? '';
                          _avatarController.text = _currentTeacher.avatarUrl ?? '';
                          _isEditing = false;
                        });
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSaveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
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
                      ? AppColors.primaryLight
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.edit_outlined, size: 13, color: AppColors.primaryLight),
            ],
          ],
        ),
      ),
    );
  }
}

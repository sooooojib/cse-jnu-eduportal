import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/states/app_empty_state_view.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../../../shared/widgets/states/app_loading_view.dart';
import '../../domain/entities/department_notice.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminNotificationHubScreen extends StatefulWidget {
  final AdminRepository? repository;

  const AdminNotificationHubScreen({super.key, this.repository});

  @override
  State<AdminNotificationHubScreen> createState() => _AdminNotificationHubScreenState();
}

class _AdminNotificationHubScreenState extends State<AdminNotificationHubScreen> {
  late final AdminRepository _repository;
  List<DepartmentNotice> _notices = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? sl<AdminRepository>();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getAllNotices();
      if (!mounted) return;
      setState(() {
        _notices = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  List<DepartmentNotice> get _filteredNotices {
    if (_selectedFilter == 'ALL') return _notices;
    return _notices.where((n) => n.noticeType == _selectedFilter).toList();
  }

  Future<void> _deleteNotice(DepartmentNotice notice) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Recall Broadcast Notice?',
      message: 'Are you sure you want to recall and delete "${notice.title}"? This will also remove it from the public routine archive if synced.',
      confirmText: 'Recall & Delete',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteNotice(notice.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notice recalled and removed successfully.'),
              backgroundColor: Color(0xFF047857),
            ),
          );
          _loadNotices();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
          );
        }
      }
    }
  }

  void _showComposeNoticeSheet() {
    final titleController = TextEditingController();

    String noticeType = 'SEMESTER_EXAM';
    String targetAudience = 'ALL';
    String priority = 'HIGH';
    bool syncToPublicRoutines = true;
    bool isSubmitting = false;

    // Attachment state
    String? attachedFileName;
    String? attachedFileUrl;
    String? attachedFileType; // 'PDF', 'IMAGE', 'DOCUMENT'
    String? attachedFilePath;
    int? attachedFileSizeKb;
    bool isProcessingUpload = false;

    String detectType(String nameOrUrl) {
      final clean = nameOrUrl.toLowerCase().split('?').first;
      if (clean.endsWith('.pdf')) return 'PDF';
      if (clean.endsWith('.jpg') || clean.endsWith('.jpeg') ||
          clean.endsWith('.png') || clean.endsWith('.webp') ||
          clean.endsWith('.gif')) {
        return 'IMAGE';
      }
      return 'DOCUMENT';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            // Helper to build a picker option tile
            Widget _buildPickerTile({
              required IconData icon,
              required Color iconColor,
              required String title,
              required String subtitle,
              required VoidCallback onTap,
            }) {
              return Material(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: iconColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : const Color(0xFFCBD5E1)),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Resilient helper: Attach file locally, try cloud upload, and fallback to Base64
            Future<void> uploadAndSetFile(String filePath, String fileName, String fileType) async {
              final file = File(filePath);
              int? sizeKb;
              try {
                final length = await file.length();
                sizeKb = (length / 1024).round();
              } catch (_) {}

              // 1. Immediately show file on screen so it never vanishes
              setSheetState(() {
                attachedFileName = fileName;
                attachedFileType = fileType;
                attachedFilePath = filePath;
                attachedFileSizeKb = sizeKb;
                isProcessingUpload = true;
              });

              String? finalUrl;

              // 2. Try Firebase Storage with proper MIME metadata and 4-second timeout
              try {
                final mime = fileType == 'IMAGE'
                    ? (fileName.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg')
                    : (fileType == 'PDF' ? 'application/pdf' : 'application/octet-stream');

                final ref = FirebaseStorage.instance
                    .ref('notices/${DateTime.now().millisecondsSinceEpoch}_$fileName');

                await ref.putFile(file, SettableMetadata(contentType: mime)).timeout(const Duration(seconds: 4));
                finalUrl = await ref.getDownloadURL();
              } catch (storageErr) {
                debugPrint('Cloud storage upload bypassed ($storageErr). Storing as compressed direct attachment.');
              }

              // 3. Fallback: If cloud storage failed (e.g. project Spark plan or bucket unconfigured),
              // embed image/doc as Base64 Data URL so it is preserved in Firestore
              if (finalUrl == null) {
                try {
                  final bytes = await file.readAsBytes();
                  if (bytes.lengthInBytes < 850 * 1024) {
                    final mime = fileType == 'IMAGE'
                        ? (fileName.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg')
                        : (fileType == 'PDF' ? 'application/pdf' : 'application/octet-stream');
                    finalUrl = 'data:$mime;base64,${base64Encode(bytes)}';
                  } else {
                    finalUrl = filePath;
                  }
                } catch (readErr) {
                  debugPrint('Error reading file bytes: $readErr');
                }
              }

              // 4. Update state with final URL (keeps file attached!)
              setSheetState(() {
                attachedFileName = fileName;
                attachedFileUrl = finalUrl;
                attachedFileType = fileType;
                attachedFilePath = filePath;
                isProcessingUpload = false;
              });
            }

            Future<void> pickFileFromDevice() async {
              final picker = ImagePicker();

              await showModalBottomSheet(
                context: ctx,
                backgroundColor: Colors.transparent,
                builder: (sheetCtx) => Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select File Source',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),

                      // 1. Photo Gallery
                      _buildPickerTile(
                        icon: Icons.photo_library_rounded,
                        iconColor: const Color(0xFF6366F1),
                        title: 'Photo Gallery',
                        subtitle: 'Pick an image from your gallery',
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await Future.delayed(const Duration(milliseconds: 200));
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            maxHeight: 1200,
                            imageQuality: 75,
                          );
                          if (picked != null) {
                            await uploadAndSetFile(picked.path, picked.name, 'IMAGE');
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // 2. Camera
                      _buildPickerTile(
                        icon: Icons.camera_alt_rounded,
                        iconColor: const Color(0xFF047857),
                        title: 'Camera',
                        subtitle: 'Take a photo of the notice board',
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await Future.delayed(const Duration(milliseconds: 200));
                          final picked = await picker.pickImage(
                            source: ImageSource.camera,
                            maxWidth: 1200,
                            maxHeight: 1200,
                            imageQuality: 75,
                          );
                          if (picked != null) {
                            final fname = 'notice_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
                            await uploadAndSetFile(picked.path, fname, 'IMAGE');
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // 3. Choose from Files
                      _buildPickerTile(
                        icon: Icons.folder_open_rounded,
                        iconColor: const Color(0xFFD97706),
                        title: 'Choose from Files',
                        subtitle: 'Browse files & documents from phone storage',
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await Future.delayed(const Duration(milliseconds: 200));
                          final picked = await picker.pickMedia(
                            maxWidth: 1200,
                            maxHeight: 1200,
                            imageQuality: 75,
                          );
                          if (picked != null) {
                            await uploadAndSetFile(picked.path, picked.name, detectType(picked.name));
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // 4. PDF / Document URL
                      _buildPickerTile(
                        icon: Icons.link_rounded,
                        iconColor: const Color(0xFFDC2626),
                        title: 'Paste Document URL',
                        subtitle: 'Attach a link to a PDF or hosted document',
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          final urlController = TextEditingController();
                          await showDialog(
                            context: ctx,
                            builder: (dialogCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text('Paste Document URL'),
                              content: TextField(
                                controller: urlController,
                                autofocus: true,
                                keyboardType: TextInputType.url,
                                decoration: InputDecoration(
                                  hintText: 'https://example.com/notice.pdf',
                                  prefixIcon: const Icon(Icons.link_rounded),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    final url = urlController.text.trim();
                                    if (url.isNotEmpty) {
                                      setSheetState(() {
                                        attachedFileName = url.split('/').last.split('?').first;
                                        if (attachedFileName == null || attachedFileName!.isEmpty) {
                                          attachedFileName = 'Online Document';
                                        }
                                        attachedFileUrl = url;
                                        attachedFileType = detectType(url);
                                        attachedFilePath = null;
                                        attachedFileSizeKb = null;
                                        isProcessingUpload = false;
                                      });
                                    }
                                    Navigator.pop(dialogCtx);
                                  },
                                  child: const Text('Attach'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle & Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.campaign_rounded, color: Color(0xFF6366F1), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Broadcast Notice & Notification',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Dispatch circular & sync routines to public section',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Form Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Notice Category
                          const Text('Notice Category:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildNoticeTypeChip(
                                  label: 'Semester Exam',
                                  icon: Icons.school_rounded,
                                  type: 'SEMESTER_EXAM',
                                  currentType: noticeType,
                                  onSelected: (t) => setSheetState(() {
                                    noticeType = t;
                                    syncToPublicRoutines = true;
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _buildNoticeTypeChip(
                                  label: 'Central Routine',
                                  icon: Icons.calendar_month_rounded,
                                  type: 'CENTRAL_ROUTINE',
                                  currentType: noticeType,
                                  onSelected: (t) => setSheetState(() {
                                    noticeType = t;
                                    syncToPublicRoutines = true;
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _buildNoticeTypeChip(
                                  label: 'General Notice',
                                  icon: Icons.article_rounded,
                                  type: 'GENERAL_NOTICE',
                                  currentType: noticeType,
                                  onSelected: (t) => setSheetState(() => noticeType = t),
                                ),
                                const SizedBox(width: 8),
                                _buildNoticeTypeChip(
                                  label: 'Emergency Alert',
                                  icon: Icons.warning_amber_rounded,
                                  type: 'EMERGENCY_ALERT',
                                  currentType: noticeType,
                                  onSelected: (t) => setSheetState(() {
                                    noticeType = t;
                                    priority = 'URGENT';
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 2. Notice Title
                          const Text('Notice Title:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Spring 2026 Semester Final Examination Routine',
                              hintStyle: const TextStyle(fontSize: 13),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3. Target Audience
                          const Text('Send To:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildAudienceChip(
                                value: 'ALL',
                                label: 'All Dept Members',
                                icon: Icons.groups_rounded,
                                selected: targetAudience,
                                onSelect: (v) => setSheetState(() => targetAudience = v),
                                isDark: isDark,
                              ),
                              _buildAudienceChip(
                                value: 'TEACHERS',
                                label: 'All Faculty',
                                icon: Icons.school_rounded,
                                selected: targetAudience,
                                onSelect: (v) => setSheetState(() => targetAudience = v),
                                isDark: isDark,
                              ),
                              _buildAudienceChip(
                                value: 'STUDENTS',
                                label: 'All Students',
                                icon: Icons.person_rounded,
                                selected: targetAudience,
                                onSelect: (v) => setSheetState(() => targetAudience = v),
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 4. Attachment (Optional)
                          const Text('Attachment (Optional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),

                          if (attachedFileName != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: attachedFileType == 'PDF'
                                    ? (isDark ? const Color(0xFF3B1D1D) : const Color(0xFFFEF2F2))
                                    : attachedFileType == 'IMAGE'
                                        ? (isDark ? const Color(0xFF1E2A38) : const Color(0xFFEFF6FF))
                                        : (isDark ? const Color(0xFF1D2E24) : const Color(0xFFF0FDF4)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: attachedFileType == 'PDF'
                                      ? const Color(0xFFFCA5A5)
                                      : attachedFileType == 'IMAGE'
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFF86EFAC),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      color: attachedFileType == 'PDF'
                                          ? const Color(0xFFDC2626)
                                          : attachedFileType == 'IMAGE'
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFF16A34A),
                                      child: (attachedFilePath != null &&
                                              attachedFileType == 'IMAGE' &&
                                              File(attachedFilePath!).existsSync())
                                          ? Image.file(
                                              File(attachedFilePath!),
                                              width: 46,
                                              height: 46,
                                              fit: BoxFit.cover,
                                            )
                                          : Icon(
                                              attachedFileType == 'PDF'
                                                  ? Icons.picture_as_pdf_rounded
                                                  : attachedFileType == 'IMAGE'
                                                      ? Icons.image_rounded
                                                      : Icons.insert_drive_file_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          attachedFileName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            if (isProcessingUpload) ...[
                                              const SizedBox(
                                                width: 11,
                                                height: 11,
                                                child: CircularProgressIndicator(strokeWidth: 1.5),
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                'Attaching...',
                                                style: TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                                              ),
                                            ] else ...[
                                              const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                                              const SizedBox(width: 4),
                                              Text(
                                                attachedFileSizeKb != null
                                                    ? 'Ready • ${attachedFileSizeKb} KB'
                                                    : 'Ready • ${attachedFileType ?? 'File'}',
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_rounded, color: Color(0xFF94A3B8), size: 22),
                                    tooltip: 'Remove',
                                    onPressed: () => setSheetState(() {
                                      attachedFileName = null;
                                      attachedFileUrl = null;
                                      attachedFileType = null;
                                      attachedFilePath = null;
                                      attachedFileSizeKb = null;
                                      isProcessingUpload = false;
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            InkWell(
                              onTap: pickFileFromDevice,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.upload_file_rounded, color: Color(0xFF6366F1), size: 26),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Tap to Upload File',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          'PDF, Photo, or any document',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // 5. Priority Selector
                          const Text('Priority:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildPriorityOption(
                                value: 'NORMAL',
                                label: 'Normal',
                                icon: Icons.circle_outlined,
                                selectedValue: priority,
                                onSelected: (p) => setSheetState(() => priority = p),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildPriorityOption(
                                value: 'HIGH',
                                label: 'High',
                                icon: Icons.priority_high_rounded,
                                selectedValue: priority,
                                onSelected: (p) => setSheetState(() => priority = p),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildPriorityOption(
                                value: 'URGENT',
                                label: 'Urgent',
                                icon: Icons.warning_amber_rounded,
                                selectedValue: priority,
                                onSelected: (p) => setSheetState(() => priority = p),
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 6. Sync to Public Routine Option
                          Material(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: syncToPublicRoutines
                                      ? const Color(0xFF047857)
                                      : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: SwitchListTile(
                                value: syncToPublicRoutines,
                                activeColor: const Color(0xFF047857),
                                title: const Row(
                                  children: [
                                    Icon(Icons.public_rounded, size: 18, color: Color(0xFF047857)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Sync to Public Routine Section',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: const Text(
                                  'Publishes directly to the public Class & Exam Routines archive so anyone can view it without logging in.',
                                  style: TextStyle(fontSize: 11),
                                ),
                                onChanged: (val) => setSheetState(() => syncToPublicRoutines = val),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  // Pinned Action Buttons (Protected with SafeArea for Android navigation buttons)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                isSubmitting ? 'Broadcasting...' : 'Broadcast Notice',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final title = titleController.text.trim();

                                      if (title.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please enter a notice title.')),
                                        );
                                        return;
                                      }

                                      setSheetState(() => isSubmitting = true);

                                      try {
                                        await _repository.sendBroadcastNotice(
                                          title: title,
                                          message: 'Official departmental circular: $title',
                                          noticeType: noticeType,
                                          targetAudience: targetAudience,
                                          attachmentUrl: attachedFileUrl,
                                          attachmentType: attachedFileType,
                                          priority: priority,
                                          syncToPublicRoutines: syncToPublicRoutines,
                                        );

                                        if (mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(syncToPublicRoutines
                                                  ? 'Notice broadcasted & synced to public routine section!'
                                                  : 'Notice broadcasted successfully!'),
                                              backgroundColor: const Color(0xFF047857),
                                            ),
                                          );
                                          _loadNotices();
                                        }
                                      } catch (e) {
                                        setSheetState(() => isSubmitting = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error broadcasting notice: $e'),
                                              backgroundColor: const Color(0xFFDC2626),
                                            ),
                                          );
                                        }
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPriorityOption({
    required String value,
    required String label,
    required IconData icon,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    required bool isDark,
  }) {
    final isSelected = selectedValue == value;
    Color activeBg;
    Color activeText;
    Color activeBorder;

    if (value == 'URGENT') {
      activeBg = const Color(0xFFFEE2E2);
      activeText = const Color(0xFFDC2626);
      activeBorder = const Color(0xFFF87171);
    } else if (value == 'HIGH') {
      activeBg = const Color(0xFFFEF3C7);
      activeText = const Color(0xFFD97706);
      activeBorder = const Color(0xFFFBBF24);
    } else {
      activeBg = const Color(0xFFEEF2FF);
      activeText = const Color(0xFF4F46E5);
      activeBorder = const Color(0xFF818CF8);
    }

    return Expanded(
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? activeBg : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeBorder : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeText : (isDark ? Colors.white54 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeText : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeTypeChip({
    required String label,
    required IconData icon,
    required String type,
    required String currentType,
    required ValueChanged<String> onSelected,
  }) {
    final isSelected = currentType == type;
    return InkWell(
      onTap: () => onSelected(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredNotices;
    final totalExamNotices = _notices.where((n) => n.noticeType == 'SEMESTER_EXAM').length;
    final totalRoutineNotices = _notices.where((n) => n.noticeType == 'CENTRAL_ROUTINE').length;
    final totalPublicSynced = _notices.where((n) => n.syncedToPublicRoutines).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notice & Alerts Hub',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadNotices),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('Broadcast Notice', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: _showComposeNoticeSheet,
      ),
      body: _isLoading
          ? const Center(child: AppLoadingView(message: 'Loading departmental notices...'))
          : _errorMessage != null
              ? Center(child: AppErrorStateView(message: _errorMessage!, onRetry: _loadNotices))
              : Column(
                  children: [
                    // Overview Stats Strip
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildMetricChip(
                                  label: '${_notices.length} Total Notices',
                                  bgColor: isDark ? const Color(0xFF312E81).withValues(alpha: 0.3) : const Color(0xFFEEF2FF),
                                  textColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                                  borderColor: isDark ? const Color(0xFF6366F1).withValues(alpha: 0.4) : const Color(0xFFC7D2FE),
                                ),
                                const SizedBox(width: 8),
                                _buildMetricChip(
                                  label: '$totalExamNotices Exam Circulars',
                                  bgColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                                  textColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                  borderColor: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : const Color(0xFFBFDBFE),
                                ),
                                const SizedBox(width: 8),
                                _buildMetricChip(
                                  label: '$totalRoutineNotices Routine Notices',
                                  bgColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                                  textColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                  borderColor: isDark ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFA7F3D0),
                                ),
                                const SizedBox(width: 8),
                                _buildMetricChip(
                                  label: '$totalPublicSynced Public Synced',
                                  bgColor: isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7),
                                  textColor: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                                  borderColor: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : const Color(0xFFFDE68A),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Filter Row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterTab('All Notices', 'ALL', isDark: isDark),
                                const SizedBox(width: 8),
                                _buildFilterTab('Semester Exams', 'SEMESTER_EXAM', isDark: isDark),
                                const SizedBox(width: 8),
                                _buildFilterTab('Central Routines', 'CENTRAL_ROUTINE', isDark: isDark),
                                const SizedBox(width: 8),
                                _buildFilterTab('General Notices', 'GENERAL_NOTICE', isDark: isDark),
                                const SizedBox(width: 8),
                                _buildFilterTab('Urgent Alerts', 'EMERGENCY_ALERT', isDark: isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Notice Cards List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: AppEmptyStateView(
                                title: 'No Notices in this Category',
                                message: 'Broadcast notices, exam schedules, or routines using the button below.',
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (context, i) {
                                final notice = filtered[i];
                                return _buildNoticeCard(notice);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, String value, {bool isDark = false}) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: isDark && !isSelected
              ? Border.all(color: Colors.white.withValues(alpha: 0.1))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildAudienceChip({
    required String value,
    required String label,
    required IconData icon,
    required String selected,
    required void Function(String) onSelect,
    required bool isDark,
  }) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeCard(DepartmentNotice notice) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color typeColor = const Color(0xFF6366F1);
    String typeLabel = 'Notice';
    IconData typeIcon = Icons.article_rounded;

    if (notice.noticeType == 'SEMESTER_EXAM') {
      typeColor = const Color(0xFF2563EB);
      typeLabel = 'Semester Exam';
      typeIcon = Icons.school_rounded;
    } else if (notice.noticeType == 'CENTRAL_ROUTINE') {
      typeColor = const Color(0xFF047857);
      typeLabel = 'Central Routine';
      typeIcon = Icons.calendar_month_rounded;
    } else if (notice.noticeType == 'EMERGENCY_ALERT') {
      typeColor = const Color(0xFFDC2626);
      typeLabel = 'Emergency Alert';
      typeIcon = Icons.warning_amber_rounded;
    } else if (notice.noticeType == 'ACADEMIC_UPDATE') {
      typeColor = const Color(0xFFD97706);
      typeLabel = 'Academic Update';
      typeIcon = Icons.menu_book_rounded;
    }

    String audienceLabel = 'All Dept Members';
    if (notice.targetAudience == 'STUDENTS') audienceLabel = 'All Students';
    if (notice.targetAudience == 'TEACHERS') audienceLabel = 'All Faculty';
    if (notice.targetAudience == 'CRS') audienceLabel = 'CRs Only';
    if (notice.targetAudience.startsWith('BATCH_')) {
      audienceLabel = notice.targetAudience.replaceAll('_', ' ');
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Type badge, Priority badge, Recall action
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, size: 14, color: typeColor),
                    const SizedBox(width: 4),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (notice.priority == 'URGENT')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    'URGENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                tooltip: 'Recall Notice',
                onPressed: () => _deleteNotice(notice),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            notice.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),

          // Body text
          Text(
            notice.message,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              height: 1.4,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Attachment Container if present
          if (notice.attachmentUrl != null && notice.attachmentUrl!.isNotEmpty) ...[
            InkWell(
              onTap: () => _viewAttachment(notice),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0B1C30)
                      : (notice.attachmentType == 'PDF'
                          ? const Color(0xFFFEF2F2)
                          : notice.attachmentType == 'IMAGE'
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFEFF6FF)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : (notice.attachmentType == 'PDF'
                            ? const Color(0xFFFECACA)
                            : notice.attachmentType == 'IMAGE'
                                ? const Color(0xFFBBF7D0)
                                : const Color(0xFFBFDBFE)),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 38,
                        height: 38,
                        color: notice.attachmentType == 'PDF'
                            ? const Color(0xFFDC2626)
                            : notice.attachmentType == 'IMAGE'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF2563EB),
                        child: (notice.attachmentType == 'IMAGE' &&
                                notice.attachmentUrl!.startsWith('data:image'))
                            ? Image.memory(
                                base64Decode(notice.attachmentUrl!.split(',').last),
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: Colors.white, size: 20),
                              )
                            : (notice.attachmentType == 'IMAGE' && notice.attachmentUrl!.startsWith('http'))
                                ? Image.network(
                                    notice.attachmentUrl!,
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: Colors.white, size: 20),
                                  )
                                : Icon(
                                    notice.attachmentType == 'PDF'
                                        ? Icons.picture_as_pdf_rounded
                                        : notice.attachmentType == 'IMAGE'
                                            ? Icons.image_rounded
                                            : Icons.link_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notice.attachmentType == 'PDF'
                                ? 'Official PDF Notice Document'
                                : notice.attachmentType == 'IMAGE'
                                    ? 'Notice Board Photo / Routine Scan'
                                    : 'External Document / Resource',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            notice.attachmentUrl!.startsWith('data:')
                                ? 'Embedded Photo Attachment • Tap to view'
                                : notice.attachmentUrl!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Footer Meta: Target audience badge, Public routine badge, and date
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  audienceLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
              if (notice.syncedToPublicRoutines)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.public_rounded, size: 12, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)),
                      const SizedBox(width: 4),
                      Text(
                        'Public Routine Section',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'By ${notice.sentBy}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewAttachment(DepartmentNotice notice) {
    if (notice.attachmentUrl == null || notice.attachmentUrl!.isEmpty) return;
    final url = notice.attachmentUrl!;
    final isBase64 = url.startsWith('data:image');

    if (notice.attachmentType == 'IMAGE' || isBase64) {
      showDialog(
        context: context,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(8),
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: isBase64
                        ? Image.memory(
                            base64Decode(url.split(',').last),
                            fit: BoxFit.contain,
                          )
                        : Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(24),
                              child: const Text('Unable to load photo preview'),
                            ),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 18,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

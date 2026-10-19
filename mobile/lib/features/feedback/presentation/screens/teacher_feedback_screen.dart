import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/cloud_storage_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/feedback_controller.dart';
import '../../domain/entities/feedback_entities.dart';

class TeacherFeedbackScreen extends StatefulWidget {
  final String? teacherId;
  final bool showAppBar;

  const TeacherFeedbackScreen({
    super.key,
    this.teacherId,
    this.showAppBar = true,
  });

  @override
  State<TeacherFeedbackScreen> createState() => _TeacherFeedbackScreenState();
}

class _TeacherFeedbackScreenState extends State<TeacherFeedbackScreen> with SingleTickerProviderStateMixin {
  late final FeedbackController _controller;
  late final TabController _tabController;
  late String _currentTeacherId;
  String _currentFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _controller = sl<FeedbackController>();
    _tabController = TabController(length: 3, vsync: this);
    String tid = widget.teacherId ?? '';
    if (tid.isEmpty && sl.isRegistered<AuthController>()) {
      tid = sl<AuthController>().currentUser?.id ?? '';
    }
    if (tid.isEmpty) {
      try {
        tid = fb.FirebaseAuth.instance.currentUser?.uid ?? 'teacher-1';
      } catch (_) {
        tid = 'teacher-1';
      }
    }
    _currentTeacherId = tid;

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final newFilter = _getFilterForIndex(_tabController.index);
      if (newFilter != _currentFilter) {
        setState(() => _currentFilter = newFilter);
        _controller.fetchTeacherFeedback(_currentTeacherId, filter: newFilter);
      }
    });

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getFilterForIndex(int index) {
    switch (index) {
      case 1:
        return 'REPLIED';
      case 2:
        return 'NOT_REPLIED';
      case 0:
      default:
        return 'ALL';
    }
  }

  Future<void> _loadData() async {
    await _controller.fetchTeacherFeedback(_currentTeacherId, filter: _currentFilter);
  }

  void _showReplyDialog(FeedbackItem item, {FeedbackReply? existingReply}) {
    final isEditing = existingReply != null;
    final replyTextController = TextEditingController(text: existingReply?.replyText ?? '');
    final List<Attachment> replyAttachments = List<Attachment>.from(existingReply?.attachments ?? []);
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;

            Future<void> pickAttachment() async {
              final picker = ImagePicker();
              try {
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1200,
                  maxHeight: 1200,
                  imageQuality: 80,
                );

                if (picked != null) {
                  setSheetState(() => isUploading = true);
                  final file = File(picked.path);
                  final currentUid = _currentTeacherId;
                  final attachmentId = 'att_${DateTime.now().millisecondsSinceEpoch}';
                  final storagePath = StoragePathBuilder.feedbackReplyAttachment(
                    feedbackId: item.id,
                    attachmentId: attachmentId,
                    fileName: picked.name,
                  );

                  String downloadUrl = picked.path;
                  int fileSize = 1024;
                  String mimeType = 'image/jpeg';

                  try {
                    if (sl.isRegistered<CloudStorageService>()) {
                      final storageService = sl<CloudStorageService>();
                      final uploadResult = await storageService.uploadFile(
                        file: file,
                        storagePath: storagePath,
                        uploadedBy: currentUid,
                        isImageOnly: true,
                      );
                      downloadUrl = uploadResult.downloadUrl;
                      fileSize = uploadResult.fileSize;
                      mimeType = uploadResult.contentType;
                    } else if (sl.isRegistered<FirebaseStorage>()) {
                      final storage = sl<FirebaseStorage>();
                      final ref = storage.ref(storagePath);
                      final uploadTask = await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
                      downloadUrl = await uploadTask.ref.getDownloadURL();
                    }
                  } catch (_) {
                    // Fallback to local path or mock url for tests/offline
                  }

                  final newAttachment = Attachment(
                    id: attachmentId,
                    fileName: picked.name,
                    fileUrl: downloadUrl,
                    mimeType: mimeType,
                    fileSize: fileSize,
                  );

                  setSheetState(() {
                    replyAttachments.add(newAttachment);
                    isUploading = false;
                  });
                }
              } catch (e) {
                setSheetState(() => isUploading = false);
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(content: Text('Failed to attach file: $e')),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(
                      children: [
                        Icon(
                          isEditing ? Icons.edit_note_rounded : Icons.reply_rounded,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEditing ? 'Edit Reply' : 'Reply to Feedback',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Context snippet
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.isAnonymous ? 'Anonymous Student' : (item.studentName ?? 'Student'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: List.generate(5, (s) {
                                  return Icon(
                                    s < item.rating ? Icons.star : Icons.star_border,
                                    size: 14,
                                    color: Colors.amber,
                                  );
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.comments,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reply TextField
                    const Text('Your Response', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: replyTextController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write a constructive, professional response...',
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Attachments Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        TextButton.icon(
                          icon: isUploading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.attach_file_rounded, size: 16),
                          label: const Text('Add File', style: TextStyle(fontSize: 12)),
                          onPressed: isUploading ? null : pickAttachment,
                        ),
                      ],
                    ),
                    if (replyAttachments.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: replyAttachments.map((att) {
                          return Chip(
                            label: Text(att.fileName, style: const TextStyle(fontSize: 11)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setSheetState(() => replyAttachments.remove(att));
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _controller.isSubmitting
                            ? null
                            : () async {
                                final text = replyTextController.text.trim();
                                if (text.length < 3) {
                                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                    const SnackBar(content: Text('Response must be at least 3 characters.')),
                                  );
                                  return;
                                }

                                Navigator.pop(sheetCtx);

                                try {
                                  if (isEditing) {
                                    await _controller.editFeedbackReply(
                                      feedbackId: item.id,
                                      replyId: existingReply.id,
                                      replyText: text,
                                      attachments: replyAttachments,
                                      teacherId: _currentTeacherId,
                                    );
                                  } else {
                                    await _controller.replyToFeedback(
                                      feedbackId: item.id,
                                      replyText: text,
                                      attachments: replyAttachments,
                                      teacherId: _currentTeacherId,
                                    );
                                  }

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEditing ? 'Reply updated!' : 'Reply submitted successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
                                    );
                                  }
                                }
                              },
                        child: _controller.isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(isEditing ? 'Update Reply' : 'Send Reply', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;

        if (state is FeedbackLoading && !_controller.isSubmitting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
        }

        if (state is FeedbackError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
                const SizedBox(height: 10),
                Text(state.message, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final items = state is FeedbackLoaded ? state.teacherFeedback : <FeedbackItem>[];

        if (items.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.rate_review_outlined, size: 40, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    _getEmptyMessage(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primaryLight,
          onRefresh: _loadData,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildFeedbackCard(item, isDark);
            },
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Received Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Replied'),
                      Tab(text: 'Not Replied'),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: widget.showAppBar
          ? content
          : Column(
              children: [
                Container(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [
                        Tab(text: 'All'),
                        Tab(text: 'Replied'),
                        Tab(text: 'Not Replied'),
                      ],
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            ),
    );
  }

  String _getEmptyMessage() {
    switch (_currentFilter) {
      case 'REPLIED':
        return 'No replied feedback found.';
      case 'NOT_REPLIED':
        return 'Great! You have answered all received student feedback.';
      case 'ALL':
      default:
        return 'No student feedback has been submitted to you yet.';
    }
  }

  Widget _buildFeedbackCard(FeedbackItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author & Anonymity Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: item.isAnonymous ? Colors.blueGrey : AppColors.primaryLight,
                      child: Icon(
                        item.isAnonymous ? Icons.shield_rounded : Icons.person_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.isAnonymous ? 'Anonymous Student' : (item.studentName ?? 'Student'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.courseCode != null)
                            Text(
                              '${item.courseCode} ${item.courseTitle != null ? '• ${item.courseTitle}' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.hasReplied ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.hasReplied ? 'Replied' : 'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: item.hasReplied ? Colors.green : Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Rating Stars
          Row(
            children: List.generate(5, (starIdx) {
              return Icon(
                starIdx < item.rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 16,
              );
            }),
          ),
          const SizedBox(height: 8),

          // Comments
          Text(
            item.comments,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),

          // Student Attachments
          if (item.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.attachments.map((att) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_file, size: 12),
                      const SizedBox(width: 4),
                      Text(att.fileName, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),

          // Footer Row: Date & Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.createdAt.length >= 10 ? item.createdAt.substring(0, 10) : item.createdAt,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                ),
              ),
              if (!item.hasReplied)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.reply_rounded, size: 14),
                  label: const Text('Reply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _showReplyDialog(item),
                ),
            ],
          ),

          // Existing Replies View
          if (item.replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...item.replies.map((reply) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryLight.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primaryLight),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Your Response (${reply.createdAt.length >= 10 ? reply.createdAt.substring(0, 10) : reply.createdAt}):',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 12),
                          label: const Text('Edit', style: TextStyle(fontSize: 11)),
                          onPressed: () => _showReplyDialog(item, existingReply: reply),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reply.replyText,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (reply.attachments.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: reply.attachments.map((att) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_file, size: 10, color: AppColors.primaryLight),
                                const SizedBox(width: 3),
                                Text(att.fileName, style: const TextStyle(fontSize: 10, color: AppColors.primaryLight)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

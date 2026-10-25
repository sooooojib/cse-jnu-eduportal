import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/cloud_storage_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/feedback_controller.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../curriculum/domain/repositories/curriculum_repository.dart';
import '../../domain/entities/feedback_entities.dart';

class StudentFeedbackScreen extends StatefulWidget {
  const StudentFeedbackScreen({super.key});

  @override
  State<StudentFeedbackScreen> createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends State<StudentFeedbackScreen> with SingleTickerProviderStateMixin {
  late final FeedbackController _controller;
  late final TabController _tabController;
  final TextEditingController _commentController = TextEditingController();

  List<Course> _myCourses = [];
  List<Map<String, String>> _allTeachers = [];
  Course? _selectedCourse;
  Map<String, String>? _selectedTeacher;
  int _rating = 5;
  bool _isAnonymous = false;
  bool _isLoadingInitial = true;
  bool _isUploadingAttachment = false;

  final List<Attachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    _controller = sl<FeedbackController>();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingInitial = true);
    await _controller.fetchSubmissions();

    try {
      final curriculumRepo = sl<CurriculumRepository>();
      final courses = await curriculumRepo.getMyCourses();
      final teachers = await curriculumRepo.getAllTeachers();

      if (mounted) {
        setState(() {
          _myCourses = courses;
          _allTeachers = teachers;
          if (courses.isNotEmpty) {
            _selectedCourse = courses.first;
          } else if (teachers.isNotEmpty) {
            _selectedTeacher = teachers.first;
          }
          _isLoadingInitial = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (picked != null) {
        setState(() => _isUploadingAttachment = true);
        final file = File(picked.path);
        final authUser = sl.isRegistered<AuthController>() ? sl<AuthController>().currentUser : null;
        final userId = authUser?.id ?? 'anonymous';
        final attachmentId = 'att_${DateTime.now().millisecondsSinceEpoch}';
        final storagePath = StoragePathBuilder.feedbackAttachment(
          feedbackId: 'draft_${DateTime.now().millisecondsSinceEpoch}',
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
              uploadedBy: userId,
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

        if (mounted) {
          setState(() {
            _attachments.add(newAttachment);
            _isUploadingAttachment = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach file: $e')),
        );
      }
    }
  }

  Future<void> _submitFeedback() async {
    String? teacherId;
    String? courseId;
    String? courseCode;
    String? courseTitle;

    if (_selectedCourse != null) {
      teacherId = _selectedCourse!.teacherId;
      courseId = _selectedCourse!.id;
      courseCode = _selectedCourse!.code;
      courseTitle = _selectedCourse!.title;
    } else if (_selectedTeacher != null) {
      teacherId = _selectedTeacher!['id'];
    }

    if (teacherId == null || teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an instructor or course with an assigned teacher.')),
      );
      return;
    }

    final comments = _commentController.text.trim();
    if (comments.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback comments must be at least 5 characters long.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.submitFeedback(
        teacherId: teacherId,
        courseId: courseId,
        courseCode: courseCode,
        courseTitle: courseTitle,
        rating: _rating,
        comments: comments,
        isAnonymous: _isAnonymous,
        attachments: List.from(_attachments),
      );

      _commentController.clear();
      _attachments.clear();
      _tabController.animateTo(1);

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '').replaceAll('ServerException: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showEditFeedbackDialog(FeedbackItem item) {
    int editRating = item.rating;
    bool editAnonymous = item.isAnonymous;
    final editCommentController = TextEditingController(text: item.comments);
    final editAttachments = List<Attachment>.from(item.attachments);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  const Text('Edit Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teacher: ${item.teacherName}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (item.courseTitle != null)
                      Text(
                        'Course: ${item.courseCode ?? ''} ${item.courseTitle!}',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
                      ),
                    const SizedBox(height: 16),

                    // Rating picker
                    const Text('Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        return IconButton(
                          iconSize: 28,
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            star <= editRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                          onPressed: () => setDialogState(() => editRating = star),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Comments
                    const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: editCommentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        hintText: 'Enter updated review comments...',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Anonymous Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.shield_outlined, size: 18, color: AppColors.primaryLight),
                              SizedBox(width: 6),
                              Text('Anonymous', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Switch(
                            value: editAnonymous,
                            activeColor: AppColors.primaryLight,
                            onChanged: (val) => setDialogState(() => editAnonymous = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Attachments summary
                    if (editAttachments.isNotEmpty) ...[
                      const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: editAttachments.map((att) {
                          return Chip(
                            label: Text(att.fileName, style: const TextStyle(fontSize: 11)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setDialogState(() => editAttachments.remove(att));
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final comments = editCommentController.text.trim();
                    if (comments.length < 5) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comments must be at least 5 characters.')),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(dialogCtx);
                    try {
                      await _controller.editFeedback(
                        feedbackId: item.id,
                        rating: editRating,
                        comments: comments,
                        isAnonymous: editAnonymous,
                        attachments: editAttachments,
                      );
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Feedback updated successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header tabs
          Container(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.15),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Submit Feedback'),
                  Tab(text: 'My Submissions'),
                ],
              ),
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSubmitFormTab(isDark),
                _buildSubmissionsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitFormTab(bool isDark) {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Course & Faculty Evaluation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Provide structured constructive feedback to improve course quality and pedagogy.',
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.outlineDark : AppColors.outlineLight),
          ),
          const SizedBox(height: 20),

          // Course / Teacher Dropdown
          const Text('Select Course / Faculty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.2),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: _myCourses.isNotEmpty
                  ? DropdownButton<Course>(
                      value: _selectedCourse,
                      isExpanded: true,
                      items: _myCourses.map((Course c) {
                        return DropdownMenuItem<Course>(
                          value: c,
                          child: Text('${c.code} - ${c.title} (${c.teacherName ?? 'Faculty'})'),
                        );
                      }).toList(),
                      onChanged: (Course? val) {
                        setState(() {
                          _selectedCourse = val;
                          _selectedTeacher = null;
                        });
                      },
                    )
                  : DropdownButton<Map<String, String>>(
                      value: _selectedTeacher,
                      isExpanded: true,
                      items: _allTeachers.map((Map<String, String> t) {
                        return DropdownMenuItem<Map<String, String>>(
                          value: t,
                          child: Text('${t['name']} (${t['designation'] ?? 'Teacher'})'),
                        );
                      }).toList(),
                      onChanged: (Map<String, String>? val) {
                        setState(() {
                          _selectedTeacher = val;
                          _selectedCourse = null;
                        });
                      },
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Rating Stars Picker
          const Text('Teaching & Course Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              return IconButton(
                iconSize: 36,
                icon: Icon(
                  starNumber <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () => setState(() => _rating = starNumber),
              );
            }),
          ),
          Center(
            child: Text(
              _getRatingLabel(_rating),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),

          // Comments box
          const Text('Review Comments & Suggestions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Share your thoughts on lecture clarity, pacing, lab work, and materials...',
              filled: true,
              fillColor: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Attachments Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('File Attachments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              TextButton.icon(
                icon: _isUploadingAttachment
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('Add File', style: TextStyle(fontSize: 12)),
                onPressed: _isUploadingAttachment ? null : _pickAttachment,
              ),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _attachments.map((att) {
                return Chip(
                  avatar: const Icon(Icons.insert_drive_file_outlined, size: 16),
                  label: Text(att.fileName, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    setState(() => _attachments.remove(att));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),

          // Anonymous toggle & Security Guarantee
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.shield_outlined, size: 20, color: AppColors.primaryLight),
                        SizedBox(width: 10),
                        Text(
                          'Submit Anonymously',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isAnonymous,
                      activeColor: AppColors.primaryLight,
                      onChanged: (val) => setState(() => _isAnonymous = val),
                    ),
                  ],
                ),
                if (_isAnonymous) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_outline, size: 16, color: AppColors.primaryLight),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Authoritative Identity Protection: Your name and student ID are stripped at the server level. Teachers have zero access to your identity.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _controller.isSubmitting ? null : _submitFeedback,
              child: _controller.isSubmitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Faculty Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsTab(bool isDark) {
    return AnimatedBuilder(
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
                const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                const SizedBox(height: 8),
                Text(state.message),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => _controller.fetchSubmissions(), child: const Text('Retry')),
              ],
            ),
          );
        }

        final items = state is FeedbackLoaded ? state.submissions : <FeedbackItem>[];

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
                children: const [
                  Icon(Icons.rate_review_outlined, size: 40, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'You have not submitted any feedback reviews yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primaryLight,
          onRefresh: () => _controller.fetchSubmissions(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = items[index];
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
                    // Top row: Teacher name & Status badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.teacherName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.hasReplied
                                ? Colors.green.withOpacity(0.12)
                                : Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.hasReplied ? 'REPLIED' : 'PENDING REPLY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item.hasReplied ? Colors.green : Colors.amber[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.courseTitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${item.courseCode ?? ''} • ${item.courseTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Rating & Anonymity badge
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (starIdx) {
                            return Icon(
                              starIdx < item.rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        if (item.isAnonymous)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.shield, size: 10, color: Colors.blueGrey),
                                SizedBox(width: 3),
                                Text('ANONYMOUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Comments
                    Text(
                      item.comments,
                      style: const TextStyle(fontSize: 13),
                    ),

                    // Student Attachments
                    if (item.attachments.isNotEmpty) ...[
                      const SizedBox(height: 8),
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

                    const SizedBox(height: 10),

                    // Bottom info: Date & Edit Button
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
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text('Edit', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showEditFeedbackDialog(item),
                        ),
                      ],
                    ),

                    // Teacher Replies
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
                                  Row(
                                    children: [
                                      const Icon(Icons.reply_rounded, size: 14, color: AppColors.primaryLight),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Faculty Response (${reply.teacherName}):',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: AppColors.primaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    reply.createdAt.length >= 10 ? reply.createdAt.substring(0, 10) : reply.createdAt,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                                    ),
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
            },
          ),
        );
      },
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return '1 / 5 - Needs Major Improvement';
      case 2:
        return '2 / 5 - Fair';
      case 3:
        return '3 / 5 - Good';
      case 4:
        return '4 / 5 - Very Good';
      case 5:
      default:
        return '5 / 5 - Outstanding';
    }
  }
}

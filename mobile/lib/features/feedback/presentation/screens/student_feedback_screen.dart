import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
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
  Course? _selectedCourse;
  int _rating = 5;
  bool _isAnonymous = false;
  bool _isLoadingCourses = true;

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
    setState(() => _isLoadingCourses = true);
    await _controller.fetchSubmissions();
    try {
      final courses = await sl<GetMyCoursesUseCase>().execute();
      if (mounted) {
        setState(() {
          _myCourses = courses;
          if (courses.isNotEmpty) {
            _selectedCourse = courses.first;
          }
          _isLoadingCourses = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> _submitFeedback() async {
    if (_selectedCourse == null || _selectedCourse!.teacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course with an assigned teacher.')),
      );
      return;
    }

    final comments = _commentController.text.trim();
    if (comments.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback comments must be at least 10 characters long.')),
      );
      return;
    }

    try {
      await _controller.submitFeedback(
        teacherId: _selectedCourse!.teacherId!,
        courseId: _selectedCourse!.id,
        rating: _rating,
        comments: comments,
        isAnonymous: _isAnonymous,
      );
      _commentController.clear();
      _tabController.animateTo(1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
    if (_isLoadingCourses) {
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

          // Course dropdown
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
              child: DropdownButton<Course>(
                value: _selectedCourse,
                isExpanded: true,
                items: _myCourses.map((Course c) {
                  return DropdownMenuItem<Course>(
                    value: c,
                    child: Text('${c.code} - ${c.title} (${c.teacherName ?? 'Faculty'})'),
                  );
                }).toList(),
                onChanged: (Course? val) {
                  setState(() => _selectedCourse = val);
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

          // Anonymous toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.outlineDark.withOpacity(0.2) : AppColors.outlineLight.withOpacity(0.2),
              ),
            ),
            child: Row(
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
            separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.teacherName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Row(
                          children: List.generate(5, (starIdx) {
                            return Icon(
                              starIdx < item.rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                      ],
                    ),
                    if (item.courseTitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${item.courseCode ?? ''} • ${item.courseTitle}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      item.comments,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
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
                        if (item.isAnonymous)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('ANONYMOUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    if (item.replies.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
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
                              children: [
                                const Icon(Icons.reply, size: 14, color: AppColors.primaryLight),
                                const SizedBox(width: 4),
                                Text(
                                  'Faculty Response (${item.replies.first.teacherName}):',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.replies.first.replyText,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
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

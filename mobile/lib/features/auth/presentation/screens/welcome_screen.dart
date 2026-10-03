import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 100) {
              return const SizedBox.shrink();
            }
            return AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: ThemeToggleButton(),
                ),
              ],
            );
          },
        ),
      ),
      body: Stack(
        children: [
          // Background ambient light orbs
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  right: -80,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -80,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.terminalGlow.withValues(alpha: isDark ? 0.12 : 0.06),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // University & Department Crest
                      Container(
                        width: 80,
                        height: 80,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primaryDark.withValues(alpha: 0.35)
                              : const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppColors.primaryDark
                                : const Color(0xFFA7F3D0),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/academic_cap_logo.png',
                          color: isDark ? AppColors.terminalGlow : AppColors.primary,
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Institutional Tag Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_balance_rounded,
                              size: 14,
                              color: isDark ? AppColors.terminalGlow : AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Jagannath University · Dept. of CSE',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Brand Titles
                      Text(
                        'JnU EduPortal',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Departmental Operating System',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.terminalGlow : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Schedules, live counseling queues, and terminal attendance verification synchronized in one place.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Primary Authenticated Gateway Buttons
                      AppPrimaryButton(
                        text: 'Sign In to Dashboard',
                        icon: Icons.login_rounded,
                        onPressed: () => context.push(RouteNames.login),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.push(RouteNames.signupRequest);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                            shape: const StadiumBorder(),
                            splashFactory: InkRipple.splashFactory,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_add_outlined,
                                size: 18,
                                color: isDark ? AppColors.terminalGlow : AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Request New Account',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Section Divider for Public Discovery
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFE2E8F0),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'EXPLORE PUBLIC SERVICES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFE2E8F0),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No account required',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 3 Public Discovery Action Cards
                      _PublicServiceTile(
                        icon: Icons.calendar_month_rounded,
                        accentColor: const Color(0xFFC2410C), // Orange / CR theme
                        title: 'Class & Exam Routines',
                        subtitle: 'Central routines, exam schedules & batch timetables (PDF/JPG)',
                        onTap: () => _showRoutinesBottomSheet(context, isDark),
                      ),
                      const SizedBox(height: 10),
                      _PublicServiceTile(
                        icon: Icons.school_rounded,
                        accentColor: const Color(0xFF1D4ED8), // Blue / Teacher theme
                        title: 'Faculty & Teacher Directory',
                        subtitle: 'Professors, designations, research labs & emails',
                        onTap: () => _showFacultyDirectoryBottomSheet(context, isDark),
                      ),
                      const SizedBox(height: 10),
                      _PublicServiceTile(
                        icon: Icons.contact_support_rounded,
                        accentColor: const Color(0xFF7E22CE), // Purple / Admin theme
                        title: 'Department Office & Helpdesk',
                        subtitle: 'Location, office hours, chairman desk & contacts',
                        onTap: () => _showOfficeHelpdeskBottomSheet(context, isDark),
                      ),

                      const SizedBox(height: 36),

                      // Institutional Copyright & Version
                      Text(
                        'Department of Computer Science & Engineering',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jagannath University, Dhaka-1100 · v2.4',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Bottom Sheet 1: Class & Exam Routines
  // ===========================================================================
  void _showRoutinesBottomSheet(BuildContext context, bool isDark) async {
    HapticFeedback.lightImpact();
    final List<Map<String, String>> routineDocuments = [
      {
        'title': 'Central Master Class Routine (Spring 2026)',
        'category': 'Central Routine',
        'type': 'central',
        'format': 'PDF',
        'fileSize': '2.4 MB',
        'publishedDate': 'Jan 15, 2026',
        'description':
            'Central departmental master class routine, room distribution & laboratory schedules across all batches.',
      },
      {
        'title': 'Semester Final Examination Routine & Hall Allocation',
        'category': 'Central Exam',
        'type': 'central',
        'format': 'PDF',
        'fileSize': '1.8 MB',
        'publishedDate': 'Feb 10, 2026',
        'description':
            'Official semester final examination routine, room allocations & invigilation duty roster.',
      },
      {
        'title': 'Central Mid-Semester Exam Schedule (Spring 2026)',
        'category': 'Central Exam',
        'type': 'central',
        'format': 'JPG',
        'fileSize': '3.2 MB',
        'publishedDate': 'Mar 02, 2026',
        'description':
            'Departmental midterm test schedule across 1st to 4th year batches with hall distribution.',
      },
      {
        'title': '13th Batch (4th Year, 2nd Sem) Full Routine',
        'category': 'Batch Routine',
        'type': 'batch',
        'format': 'PDF',
        'fileSize': '1.2 MB',
        'publishedDate': 'Jan 18, 2026',
        'description':
            'Entire semester routine covering theory courses, project/thesis slots & network lab.',
      },
      {
        'title': '14th Batch (3rd Year, 2nd Sem) Full Routine',
        'category': 'Batch Routine',
        'type': 'batch',
        'format': 'PDF',
        'fileSize': '1.1 MB',
        'publishedDate': 'Jan 18, 2026',
        'description':
            'Entire semester routine covering software engineering, computer graphics & labs.',
      },
      {
        'title': '15th Batch (2nd Year, 2nd Sem) Full Routine',
        'category': 'Batch Routine',
        'type': 'batch',
        'format': 'JPG',
        'fileSize': '2.8 MB',
        'publishedDate': 'Jan 20, 2026',
        'description':
            'Official published routine image for algorithms, microprocessor lab & math courses.',
      },
      {
        'title': '16th Batch (1st Year, 2nd Sem) Full Routine',
        'category': 'Batch Routine',
        'type': 'batch',
        'format': 'PDF',
        'fileSize': '1.3 MB',
        'publishedDate': 'Jan 22, 2026',
        'description':
            'Entire foundational semester routine with OOP in Java, data structures & labs.',
      },
      {
        'title': 'M.Sc. in CSE Entire Semester Routine',
        'category': 'Postgraduate',
        'type': 'batch',
        'format': 'PDF',
        'fileSize': '950 KB',
        'publishedDate': 'Jan 25, 2026',
        'description':
            'Official postgraduate evening & regular class timetable and seminar room schedule.',
      },
    ];

    try {
      final snap = await FirebaseFirestore.instance.collection('public_routines').get();
      for (final doc in snap.docs) {
        final d = doc.data();
        routineDocuments.insert(0, {
          'title': (d['title'] as String?) ?? 'Official Department Routine Notice',
          'category': (d['category'] as String?) ?? 'Central Routine',
          'type': (d['type'] as String?) ?? 'central',
          'format': (d['format'] as String?) ?? 'PDF',
          'fileSize': (d['fileSize'] as String?) ?? 'Official Document',
          'publishedDate': (d['publishedDate'] as String?) ?? 'Recent',
          'description': (d['description'] as String?) ?? '',
        });
      }
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String selectedFilter = 'all';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final displayedDocs = routineDocuments.where((doc) {
              if (selectedFilter == 'all') return true;
              return doc['type'] == selectedFilter;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFFC2410C),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Class & Exam Routines',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Spring 2026 Academic Session · JnU CSE',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Disclaimer / Notice Callout
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.15)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.25)
                            : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Official archive for central master routines, semester exam routines & entire batch timetables (PDF/JPG). Daily class updates & CR notices are in your student portal.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRoutineFilterChip(
                          label: 'All Documents (8)',
                          isSelected: selectedFilter == 'all',
                          isDark: isDark,
                          onTap: () => setModalState(() => selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _buildRoutineFilterChip(
                          label: 'Central & Exams (3)',
                          isSelected: selectedFilter == 'central',
                          isDark: isDark,
                          onTap: () => setModalState(() => selectedFilter = 'central'),
                        ),
                        const SizedBox(width: 8),
                        _buildRoutineFilterChip(
                          label: 'Batch Master Routines (5)',
                          isSelected: selectedFilter == 'batch',
                          isDark: isDark,
                          onTap: () => setModalState(() => selectedFilter = 'batch'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 4, bottom: 20),
                      itemCount: displayedDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = displayedDocs[index];
                        return _RoutineCard(
                          isDark: isDark,
                          title: doc['title']!,
                          category: doc['category']!,
                          format: doc['format']!,
                          fileSize: doc['fileSize']!,
                          publishedDate: doc['publishedDate']!,
                          description: doc['description']!,
                        );
                      },
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

  Widget _buildRoutineFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFC2410C)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFC2410C)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Bottom Sheet 2: Faculty & Teacher Directory
  // ===========================================================================
  void _showFacultyDirectoryBottomSheet(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();
    final facultyList = [
      {
        'name': 'Dr. Md. Abu Layek',
        'designation': 'Chairman & Associate Professor',
        'email': 'layek@cse.jnu.ac.bd',
        'room': 'Room 501, 5th Floor',
      },
      {
        'name': 'Dr. Uzzal Kumar Acharjee',
        'designation': 'Professor',
        'email': 'uzzal@cse.jnu.ac.bd',
        'room': 'Room 502, 5th Floor',
      },
      {
        'name': 'Dr. Mohammed Nasir Uddin',
        'designation': 'Professor',
        'email': 'nasir.jnu.cse@gmail.com',
        'room': 'Room 503, 5th Floor',
      },
      {
        'name': 'Dr. Md. Zulfiker Mahmud',
        'designation': 'Professor',
        'email': 'zulfiker@cse.jnu.ac.bd',
        'room': 'Room 504, 5th Floor',
      },
      {
        'name': 'Dr. Selina Sharmin',
        'designation': 'Professor',
        'email': 'selina@cse.jnu.ac.bd',
        'room': 'Room 701, 7th Floor',
      },
      {
        'name': 'Dr. Md. Manowarul Islam',
        'designation': 'Professor',
        'email': 'manowar@cse.jnu.ac.bd',
        'room': 'Room 702, 7th Floor',
      },
      {
        'name': 'Dr Sajeeb Saha',
        'designation': 'Associate Professor',
        'email': 'sajeeb@cse.jnu.ac.bd',
        'room': 'Room 703, 7th Floor',
      },
      {
        'name': 'Md. Aminul Islam',
        'designation': 'Associate Professor',
        'email': 'aminul@cse.jnu.ac.bd',
        'room': 'Room 505, 5th Floor',
      },
      {
        'name': 'Nayeema Islam',
        'designation': 'Assistant Professor',
        'email': 'nayeema@cse.jnu.ac.bd',
        'room': 'Room 506, 5th Floor',
      },
      {
        'name': 'Tanvir Ahammad (On Study Leave)',
        'designation': 'Assistant Professor (On Study Leave)',
        'email': 'tanvir@cse.jnu.ac.bd',
        'room': '5th Floor',
      },
      {
        'name': 'Arnisha Akhter',
        'designation': 'Lecturer',
        'email': 'arnisha@cse.jnu.ac.bd',
        'room': 'Room 704, 7th Floor',
      },
      {
        'name': 'Sonia Corraya',
        'designation': 'Assistant Professor',
        'email': 'sonia@cse.jnu.ac.bd',
        'room': 'Room 705, 7th Floor',
      },
      {
        'name': 'Linta Islam (On Study Leave)',
        'designation': 'Lecturer (On Study Leave)',
        'email': 'lislamcsejnu@gmail.com',
        'room': '7th Floor',
      },
      {
        'name': 'Dr. Md. Ashraf Uddin (On Study Leave)',
        'designation': 'Associate Professor (On Study Leave)',
        'email': 'ashraf@cse.jnu.ac.bd',
        'room': '5th Floor',
      },
      {
        'name': 'Mehnaz Tabassum (On Study Leave)',
        'designation': 'Assistant Professor (On Study Leave)',
        'email': 'mehnaz@cse.jnu.ac.bd',
        'room': '7th Floor',
      },
      {
        'name': 'Roksana Khanom (On Study Leave)',
        'designation': 'Assistant Professor (On Study Leave)',
        'email': 'roksana@cse.jnu.ac.bd',
        'room': '5th Floor',
      },
      {
        'name': 'Fatema Siddika (On Study Leave)',
        'designation': 'Lecturer (On Study Leave)',
        'email': 'fatema@cse.jnu.ac.bd',
        'room': '7th Floor',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Color(0xFF1D4ED8),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Faculty Directory',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Dept. of CSE, Jagannath University',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: facultyList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = facultyList[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name']!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['designation']!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                item['email']!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.meeting_room_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                item['room']!.split(',')[0],
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  // ===========================================================================
  // Bottom Sheet 4: Department Office & Helpdesk
  // ===========================================================================
  void _showOfficeHelpdeskBottomSheet(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.contact_support_rounded,
                      color: Color(0xFF7E22CE),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Department Office',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Office Hours & Academic Inquiries',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _OfficeInfoRow(
                isDark: isDark,
                icon: Icons.location_on_rounded,
                title: 'Department Location',
                detail: '5th & 7th Floor, New Academic Building\n9-10, Chittaranjan Avenue, Dhaka 1100',
              ),
              const SizedBox(height: 14),
              _OfficeInfoRow(
                isDark: isDark,
                icon: Icons.access_time_rounded,
                title: 'Official Working Hours',
                detail: 'Sunday to Thursday: 08:00 AM – 04:00 PM\n(Closed on Friday, Saturday & Public Holidays)',
              ),
              const SizedBox(height: 14),
              _OfficeInfoRow(
                isDark: isDark,
                icon: Icons.phone_in_talk_rounded,
                title: 'Office Direct Contact',
                detail: '+880 2226640038\nEmail: cse@jnu.ac.bd',
              ),
              const SizedBox(height: 14),
              _OfficeInfoRow(
                isDark: isDark,
                icon: Icons.support_agent_rounded,
                title: 'Student Advisory Helpdesk',
                detail: 'Department Office (5th Floor) · Assistance with course registration, semester promotions & portal credentials',
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

class _PublicServiceTile extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PublicServiceTile({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 22),
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
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String category;
  final String format;
  final String fileSize;
  final String publishedDate;
  final String description;

  const _RoutineCard({
    required this.isDark,
    required this.title,
    required this.category,
    required this.format,
    required this.fileSize,
    required this.publishedDate,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = format.toUpperCase() == 'PDF';
    final badgeBg = isPdf
        ? (isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
            : const Color(0xFFFEF2F2))
        : (isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
            : const Color(0xFFEFF6FF));
    final badgeColor = isPdf ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Format Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                      size: 13,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      format,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Category tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
              const Spacer(),
              // Published Date
              Text(
                publishedDate,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: isDark ? Colors.white60 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.attachment_rounded,
                    size: 13,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    fileSize,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: const Color(0xFF0F172A),
                      content: Row(
                        children: [
                          Icon(
                            isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.image_rounded,
                            color: isPdf
                                ? const Color(0xFFF87171)
                                : const Color(0xFF60A5FA),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Opening $title ($format)... Official published document.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2410C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFC2410C).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPdf ? Icons.download_rounded : Icons.visibility_rounded,
                        size: 13,
                        color: const Color(0xFFC2410C),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPdf ? 'Download PDF' : 'View Image',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC2410C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



class _OfficeInfoRow extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String detail;

  const _OfficeInfoRow({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7E22CE).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF7E22CE), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/role_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/states/app_empty_state_view.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../../../shared/widgets/states/app_loading_view.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/entities/signup_request.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../attendance/domain/entities/attendance_entities.dart';
import '../../../feedback/domain/entities/feedback_entities.dart';
import '../../../profile/domain/entities/semester_status.dart';
import '../../domain/entities/admin_stats.dart';
import '../../domain/entities/department_notice.dart';
import '../../domain/repositories/admin_repository.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 1. ADMIN USER DIRECTORY SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class AdminUserDirectoryScreen extends StatefulWidget {
  final AdminRepository? repository;
  final int? initialRoleIndex;

  const AdminUserDirectoryScreen({
    super.key,
    this.repository,
    this.initialRoleIndex,
  });

  @override
  State<AdminUserDirectoryScreen> createState() => _AdminUserDirectoryScreenState();
}

class _AdminUserDirectoryScreenState extends State<AdminUserDirectoryScreen> {
  late final AdminRepository _repository;
  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedRoleIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  final _roleTabs = ['All Roles', 'Faculty', 'Students', 'CRs', 'Admins'];

  @override
  void initState() {
    super.initState();
    _selectedRoleIndex = widget.initialRoleIndex ?? 0;
    _repository = widget.repository ?? (sl.isRegistered<AdminRepository>() ? sl<AdminRepository>() : _FallbackAdminRepo());
    _loadUsers();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _repository.getAllUsers();
      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        // Role match
        bool roleMatches = true;
        if (_selectedRoleIndex == 1) roleMatches = u.role == UserRole.teacher;
        if (_selectedRoleIndex == 2) roleMatches = u.role == UserRole.student;
        if (_selectedRoleIndex == 3) roleMatches = u.role == UserRole.cr;
        if (_selectedRoleIndex == 4) roleMatches = u.role == UserRole.admin;

        // Query match
        bool queryMatches = true;
        if (query.isNotEmpty) {
          queryMatches = u.fullName.toLowerCase().contains(query) ||
              u.email.toLowerCase().contains(query) ||
              (u.studentId != null && u.studentId!.toLowerCase().contains(query));
        }

        return roleMatches && queryMatches;
      }).toList();
    });
  }

  Future<void> _confirmDeleteUser(User user) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Delete User Account?',
      message: 'Are you sure you want to permanently delete ${user.fullName} (${user.email})? This action cannot be undone and unlinks their course assignments.',
      confirmText: 'Delete User',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteUser(userId: user.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} deleted successfully.'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
        _loadUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  void _showCreateUserModal() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    UserRole selectedRole = UserRole.student;
    int selectedYear = 1;
    int selectedSem = 1;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Create New Portal Account',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Role selector
                    const Text('Select Role:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<UserRole>(
                      value: selectedRole,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: UserRole.student, child: Text('Student')),
                        DropdownMenuItem(value: UserRole.teacher, child: Text('Professor / Faculty')),
                        DropdownMenuItem(value: UserRole.cr, child: Text('Class Representative (CR)')),
                        DropdownMenuItem(value: UserRole.admin, child: Text('Administrator')),
                      ],
                      onChanged: (val) => setModalState(() => selectedRole = val ?? UserRole.student),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Institutional Email *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password (min 6 chars) *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (selectedRole == UserRole.student || selectedRole == UserRole.cr) ...[
                      TextField(
                        controller: idCtrl,
                        decoration: InputDecoration(
                          labelText: 'Student Roll / ID * (e.g. 2023CSE012)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedYear,
                              decoration: InputDecoration(
                                labelText: 'Year',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: [1, 2, 3, 4]
                                  .map((y) => DropdownMenuItem(value: y, child: Text('Year $y')))
                                  .toList(),
                              onChanged: (val) => setModalState(() => selectedYear = val ?? 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedSem,
                              decoration: InputDecoration(
                                labelText: 'Semester',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: [1, 2]
                                  .map((s) => DropdownMenuItem(value: s, child: Text('Semester $s')))
                                  .toList(),
                              onChanged: (val) => setModalState(() => selectedSem = val ?? 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (selectedRole == UserRole.teacher) ...[
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Contact Phone Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E22CE),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final email = emailCtrl.text.trim();
                                final pass = passCtrl.text.trim();
                                final roll = idCtrl.text.trim();

                                if (name.isEmpty || email.isEmpty || pass.length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please fill all required fields correctly.')),
                                  );
                                  return;
                                }

                                if ((selectedRole == UserRole.student || selectedRole == UserRole.cr) && roll.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Student ID is required for Students/CRs.')),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);
                                try {
                                  await _repository.createUser(
                                    fullName: name,
                                    email: email,
                                    password: pass,
                                    role: selectedRole,
                                    studentId: roll.isNotEmpty ? roll : null,
                                    phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                                    year: selectedRole == UserRole.student || selectedRole == UserRole.cr ? selectedYear : null,
                                    semester: selectedRole == UserRole.student || selectedRole == UserRole.cr ? selectedSem : null,
                                  );
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('User $name provisioned successfully.'),
                                        backgroundColor: const Color(0xFF047857),
                                      ),
                                    );
                                    _loadUsers();
                                  }
                                } catch (err) {
                                  setModalState(() => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(err.toString()), backgroundColor: const Color(0xFFDC2626)),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Provision Account', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final isDark = context.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Department User Directory'),
        actions: [
          const ThemeToggleButton(showBackground: false),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadUsers,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7E22CE),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New User', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: _showCreateUserModal,
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, roll, or email...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_roleTabs.length, (index) {
                      final isSelected = _selectedRoleIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_roleTabs[index]),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedRoleIndex = index);
                            _applyFilters();
                          },
                          selectedColor: const Color(0xFF7E22CE),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Content body
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingView(message: 'Loading departmental records...'))
                : _errorMessage != null
                    ? Center(
                        child: AppErrorStateView(
                          title: 'Unable to Load Users',
                          message: _errorMessage!,
                          onRetry: _loadUsers,
                        ),
                      )
                    : _filteredUsers.isEmpty
                        ? const Center(
                            child: AppEmptyStateView(
                              title: 'No Matching Users Found',
                              message: 'Try adjusting your search query or role filter.',
                              icon: Icons.person_search_rounded,
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF7E22CE),
                            onRefresh: _loadUsers,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
                              itemCount: _filteredUsers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                final initials = user.fullName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

                                return AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: isDark
                                                ? RoleColors.forRole(user.role, isDark: true).background.withValues(alpha: 0.35)
                                                : RoleColors.forRole(user.role, isDark: false).background,
                                            child: Text(
                                              initials.isNotEmpty ? initials : 'U',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: isDark
                                                    ? RoleColors.forRole(user.role, isDark: true).text
                                                    : RoleColors.forRole(user.role, isDark: false).text,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user.fullName,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  user.email,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                            tooltip: 'Delete User',
                                            onPressed: () => _confirmDeleteUser(user),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          RoleBadgeChip(role: user.role, isCompact: true),
                                          if (user.studentId != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF064E3B).withOpacity(0.3) : const Color(0xFFECFDF5),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'ID: ${user.studentId} • Y${user.year ?? 1}S${user.semester ?? 1}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                                ),
                                              ),
                                            ),
                                          if (user.role == UserRole.teacher && user.assignedCourseIds.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.3) : const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${user.assignedCourseIds.length} Courses Assigned',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                                ),
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
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. ADMIN SIGNUP REQUESTS FULL SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class AdminSignupRequestsScreen extends StatefulWidget {
  final AdminRepository? repository;

  const AdminSignupRequestsScreen({super.key, this.repository});

  @override
  State<AdminSignupRequestsScreen> createState() => _AdminSignupRequestsScreenState();
}

class _AdminSignupRequestsScreenState extends State<AdminSignupRequestsScreen> {
  late final AdminRepository _repository;
  List<SignupRequest> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedFilter = 0;
  final _filters = ['PENDING', 'APPROVED', 'REJECTED', 'ALL'];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? (sl.isRegistered<AdminRepository>() ? sl<AdminRepository>() : _FallbackAdminRepo());
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getAllSignupRequests(statusFilter: _filters[_selectedFilter]);
      if (!mounted) return;
      setState(() {
        _requests = list;
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

  Future<void> _approve(SignupRequest req) async {
    int year = 1;
    int sem = 1;

    if (req.role == UserRole.student || req.role == UserRole.cr) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setSt) {
              return AlertDialog(
                title: Text('Approve ${req.fullName}'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Assign initial academic level:'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                      onChanged: (v) => setSt(() => year = v ?? 1),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: sem,
                      decoration: const InputDecoration(labelText: 'Semester'),
                      items: [1, 2].map((s) => DropdownMenuItem(value: s, child: Text('Semester $s'))).toList(),
                      onChanged: (v) => setSt(() => sem = v ?? 1),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
                ],
              );
            },
          );
        },
      );
      if (confirmed != true) return;
    }

    try {
      await _repository.approveSignup(
        requestId: req.id,
        assignedYear: req.role == UserRole.student || req.role == UserRole.cr ? year : null,
        assignedSemester: req.role == UserRole.student || req.role == UserRole.cr ? sem : null,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approved ${req.fullName}'), backgroundColor: const Color(0xFF047857)),
      );
      _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  Future<void> _reject(SignupRequest req) async {
    final ctrl = TextEditingController(text: 'Applicant does not meet departmental criteria.');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Petition'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Rejection Reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.rejectSignup(requestId: req.id, reason: ctrl.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejected ${req.fullName}'), backgroundColor: const Color(0xFFDC2626)),
        );
        _loadRequests();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signup Petitions Queue'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadRequests),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (i) {
                  final isSel = _selectedFilter == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filters[i]),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() => _selectedFilter = i);
                        _loadRequests();
                      },
                      selectedColor: const Color(0xFF7E22CE),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingView(message: 'Loading petitions...'))
                : _errorMessage != null
                    ? Center(child: AppErrorStateView(message: _errorMessage!, onRetry: _loadRequests))
                    : _requests.isEmpty
                        ? const Center(child: AppEmptyStateView(title: 'No Petitions Found', message: 'No registration petitions match this filter.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                            itemCount: _requests.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final req = _requests[i];
                              return AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                req.fullName,
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                req.email,
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        RoleBadgeChip(role: req.role, isCompact: true),
                                      ],
                                    ),
                                    if (req.studentId != null || req.phone != null) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (req.studentId != null)
                                            Text('Student ID: ${req.studentId}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          if (req.phone != null)
                                            Text('Phone: ${req.phone}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Status: ${req.status}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: req.status == 'PENDING' ? const Color(0xFFDC2626) : (req.status == 'APPROVED' ? const Color(0xFF047857) : Colors.grey))),
                                        if (req.status == 'PENDING')
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), foregroundColor: Colors.white),
                                                onPressed: () => _approve(req),
                                                child: const Text('Approve'),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                                                onPressed: () => _reject(req),
                                                child: const Text('Reject'),
                                              ),
                                            ],
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
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. ADMIN SEMESTER REQUESTS FULL SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class AdminSemesterRequestsScreen extends StatefulWidget {
  final AdminRepository? repository;

  const AdminSemesterRequestsScreen({super.key, this.repository});

  @override
  State<AdminSemesterRequestsScreen> createState() => _AdminSemesterRequestsScreenState();
}

class _AdminSemesterRequestsScreenState extends State<AdminSemesterRequestsScreen> {
  late final AdminRepository _repository;
  List<SemesterUpgradeRequest> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedFilter = 0;
  final _filters = ['PENDING', 'APPROVED', 'REJECTED', 'ALL'];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? (sl.isRegistered<AdminRepository>() ? sl<AdminRepository>() : _FallbackAdminRepo());
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getAllSemesterRequests(statusFilter: _filters[_selectedFilter]);
      if (!mounted) return;
      setState(() {
        _requests = list;
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

  Future<void> _approve(SemesterUpgradeRequest req) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Approve Semester Upgrade?',
      message: 'Promote ${req.studentName} (${req.studentRoll}) to Year ${req.requestedYear}, Semester ${req.requestedSemester}?',
      confirmText: 'Approve Promotion',
    );
    if (confirmed == true && mounted) {
      try {
        await _repository.approveSemesterUpgrade(requestId: req.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${req.studentName} promoted successfully.'), backgroundColor: const Color(0xFF047857)),
        );
        _loadRequests();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  Future<void> _reject(SemesterUpgradeRequest req) async {
    final ctrl = TextEditingController(text: 'Academic eligibility requirements not met.');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Semester Request'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Rejection Reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.rejectSemesterUpgrade(requestId: req.id, reason: ctrl.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejected request for ${req.studentName}'), backgroundColor: const Color(0xFFDC2626)),
        );
        _loadRequests();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Semester Promotion Petitions'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadRequests),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (i) {
                  final isSel = _selectedFilter == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filters[i]),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() => _selectedFilter = i);
                        _loadRequests();
                      },
                      selectedColor: const Color(0xFF7E22CE),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingView(message: 'Loading semester petitions...'))
                : _errorMessage != null
                    ? Center(child: AppErrorStateView(message: _errorMessage!, onRetry: _loadRequests))
                    : _requests.isEmpty
                        ? const Center(child: AppEmptyStateView(title: 'No Semester Petitions Found', message: 'No student requests match this filter.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                            itemCount: _requests.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final req = _requests[i];
                              return AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            req.studentName,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF581C87).withValues(alpha: 0.35) : const Color(0xFFFAF5FF),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Y${req.currentYear}S${req.currentSemester} ➔ Y${req.requestedYear}S${req.requestedSemester}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Roll: ${req.studentRoll} • Date: ${req.createdAt}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Status: ${req.status}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: req.status == 'PENDING' ? const Color(0xFFDC2626) : (req.status == 'APPROVED' ? const Color(0xFF047857) : Colors.grey))),
                                        if (req.status == 'PENDING')
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), foregroundColor: Colors.white),
                                                onPressed: () => _approve(req),
                                                child: const Text('Approve'),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                                                onPressed: () => _reject(req),
                                                child: const Text('Reject'),
                                              ),
                                            ],
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
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. ADMIN COURSE MANAGEMENT SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class AdminCourseManagementScreen extends StatefulWidget {
  final AdminRepository? repository;

  const AdminCourseManagementScreen({super.key, this.repository});

  @override
  State<AdminCourseManagementScreen> createState() => _AdminCourseManagementScreenState();
}

class _AdminCourseManagementScreenState extends State<AdminCourseManagementScreen> {
  late final AdminRepository _repository;
  List<Course> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? (sl.isRegistered<AdminRepository>() ? sl<AdminRepository>() : _FallbackAdminRepo());
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getAllCourses();
      if (!mounted) return;
      setState(() {
        _courses = list;
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

  void _showCourseDialog({Course? existing}) {
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final creditCtrl = TextEditingController(text: existing?.credit.toString() ?? '3.0');
    int year = existing?.year ?? 1;
    int sem = existing?.semester ?? 1;
    String type = existing?.courseType ?? 'THEORY';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(existing == null ? 'Add Department Course' : 'Edit Course ${existing.code}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      enabled: existing == null,
                      decoration: const InputDecoration(labelText: 'Course Code * (e.g. CSE-3101)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Course Title *'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: creditCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Credits (e.g. 3.0)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: type,
                            decoration: const InputDecoration(labelText: 'Type'),
                            items: const [
                              DropdownMenuItem(value: 'THEORY', child: Text('THEORY')),
                              DropdownMenuItem(value: 'LAB', child: Text('LAB')),
                            ],
                            onChanged: (v) => setSt(() => type = v ?? 'THEORY'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: year,
                            decoration: const InputDecoration(labelText: 'Year'),
                            items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                            onChanged: (v) => setSt(() => year = v ?? 1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: sem,
                            decoration: const InputDecoration(labelText: 'Semester'),
                            items: [1, 2].map((s) => DropdownMenuItem(value: s, child: Text('Semester $s'))).toList(),
                            onChanged: (v) => setSt(() => sem = v ?? 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description (Optional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), foregroundColor: Colors.white),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final code = codeCtrl.text.trim().toUpperCase();
                          final title = titleCtrl.text.trim();
                          final credit = double.tryParse(creditCtrl.text.trim()) ?? 3.0;

                          if (code.isEmpty || title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code and Title required.')));
                            return;
                          }

                          setSt(() => isSaving = true);
                          try {
                            final c = Course(
                              id: existing?.id ?? code,
                              code: code,
                              title: title,
                              credit: credit,
                              year: year,
                              semester: sem,
                              courseType: type,
                              description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                            );

                            if (existing == null) {
                              await _repository.createCourse(c);
                            } else {
                              await _repository.updateCourse(c);
                            }
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Course $code saved.'), backgroundColor: const Color(0xFF047857)),
                              );
                              _loadCourses();
                            }
                          } catch (e) {
                            setSt(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
                            );
                          }
                        },
                  child: const Text('Save Course'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCourse(Course course) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Delete Course ${course.code}?',
      message: 'Are you sure you want to delete ${course.title}? This unassigns this course from faculty members.',
      confirmText: 'Delete Course',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteCourse(course.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${course.code}'), backgroundColor: const Color(0xFF047857)),
        );
        _loadCourses();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Catalog Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadCourses),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF047857),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Course', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _showCourseDialog(),
      ),
      body: _isLoading
          ? const Center(child: AppLoadingView(message: 'Loading courses...'))
          : _errorMessage != null
              ? Center(child: AppErrorStateView(message: _errorMessage!, onRetry: _loadCourses))
              : _courses.isEmpty
                  ? const Center(child: AppEmptyStateView(title: 'No Courses Found', message: 'Tap "+ Add Course" to create the first curriculum unit.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      itemCount: _courses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final c = _courses[i];
                        return AppCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF312E81).withValues(alpha: 0.35) : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.menu_book_rounded, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5), size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(c.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${c.credit} Credits • ${c.courseType}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(c.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text('Year ${c.year}, Semester ${c.semester} • Teacher: ${c.teacherName ?? "Unassigned"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _showCourseDialog(existing: c),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                    onPressed: () => _deleteCourse(c),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 5. ADMIN TEACHER COURSE ASSIGNMENT SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class AdminTeacherAssignmentScreen extends StatefulWidget {
  final AdminRepository? repository;

  const AdminTeacherAssignmentScreen({super.key, this.repository});

  @override
  State<AdminTeacherAssignmentScreen> createState() => _AdminTeacherAssignmentScreenState();
}

class _AdminTeacherAssignmentScreenState extends State<AdminTeacherAssignmentScreen> {
  late final AdminRepository _repository;
  List<CourseAssignment> _assignments = [];
  List<User> _teachers = [];
  List<Course> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? (sl.isRegistered<AdminRepository>() ? sl<AdminRepository>() : _FallbackAdminRepo());
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repository.getAllCourseAssignments(),
        _repository.getAllUsers(roleFilter: UserRole.teacher),
        _repository.getAllCourses(),
      ]);

      if (!mounted) return;
      setState(() {
        _assignments = results[0] as List<CourseAssignment>;
        _teachers = results[1] as List<User>;
        _courses = results[2] as List<Course>;
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

  List<User> get _filteredTeachers {
    if (_searchQuery.trim().isEmpty) {
      return _teachers;
    }
    final q = _searchQuery.toLowerCase().trim();
    return _teachers.where((t) {
      final nameMatches = t.fullName.toLowerCase().contains(q);
      final emailMatches = t.email.toLowerCase().contains(q);
      final teacherAssignments = _assignments.where((a) => a.teacherId == t.id);
      final courseMatches = teacherAssignments.any(
        (a) => a.courseCode.toLowerCase().contains(q) || a.courseTitle.toLowerCase().contains(q),
      );
      return nameMatches || emailMatches || courseMatches;
    }).toList();
  }

  void _showAssignDialog({User? preselectedTeacher}) {
    if (_teachers.isEmpty || _courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both faculty members and courses must exist before assigning.')),
      );
      return;
    }

    String selectedTeacherId = preselectedTeacher?.id ?? _teachers.first.id;
    String selectedCourseId = _courses.first.id;
    bool isCoordinator = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Assign Course to Faculty'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Professor:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedTeacherId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _teachers
                          .map((t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(t.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSt(() => selectedTeacherId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Select Course:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedCourseId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _courses
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text('${c.code} - ${c.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setSt(() => selectedCourseId = v ?? selectedCourseId),
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      title: const Text('Course Coordinator', style: TextStyle(fontSize: 13)),
                      value: isCoordinator,
                      activeColor: const Color(0xFFD97706),
                      onChanged: (val) => setSt(() => isCoordinator = val ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    try {
                      await _repository.assignCourseToTeacher(
                        courseId: selectedCourseId,
                        teacherId: selectedTeacherId,
                        isCoordinator: isCoordinator,
                      );
                            if (mounted) {
                              Navigator.pop(ctx);
                              final teacherName = _teachers.firstWhere((t) => t.id == selectedTeacherId).fullName;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Course allocated to $teacherName successfully.'),
                                  backgroundColor: const Color(0xFF047857),
                                ),
                              );
                              _loadData();
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
                            );
                          }
                        },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeAssignment(CourseAssignment a, String teacherName) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Remove Assignment?',
      message: 'Remove ${a.teacherName} from course ${a.courseCode} (${a.courseTitle})?',
      confirmText: 'Remove',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.removeCourseAssignment(
          assignmentId: a.id,
          courseId: a.courseId,
          teacherId: a.teacherId,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${a.courseCode} from $teacherName'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  String _getInitials(String name) {
    final clean = name
        .replaceAll(RegExp(r'^(Dr\.|Prof\.|Mr\.|Mrs\.|Ms\.)\s*', caseSensitive: false), '')
        .trim();
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'T';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredTeachers;
    final totalAssignedCount = _assignments.length;
    final teachersWithCourses = _teachers.where((t) => _assignments.any((a) => a.teacherId == t.id)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Teacher Course Allocations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: AppLoadingView(message: 'Loading faculty allocations...'))
          : _errorMessage != null
              ? Center(child: AppErrorStateView(message: _errorMessage!, onRetry: _loadData))
              : _teachers.isEmpty
                  ? const Center(
                      child: AppEmptyStateView(
                        title: 'No Faculty Members Found',
                        message: 'Add faculty members to the departmental user directory first.',
                      ),
                    )
                  : Column(
                      children: [
                        // Search & Stats Bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search faculty by name, email, or course...',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF13263E) : const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: isDark ? BorderSide(color: Colors.white.withValues(alpha: 0.1)) : BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onChanged: (v) => setState(() => _searchQuery = v),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : const Color(0xFFBFDBFE)),
                                      ),
                                      child: Text(
                                        '${_teachers.length} Faculty Members',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isDark ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFA7F3D0)),
                                      ),
                                      child: Text(
                                        '$totalAssignedCount Allocations',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : const Color(0xFFFDE68A)),
                                      ),
                                      child: Text(
                                        '${_teachers.length - teachersWithCourses} Unallocated',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Teacher Cards List
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: AppEmptyStateView(
                                    title: 'No Matching Faculty',
                                    message: 'No faculty member matches "$_searchQuery".',
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                                  itemBuilder: (context, i) {
                                    final teacher = filtered[i];
                                    final teacherAssignments = _assignments
                                        .where((a) => a.teacherId == teacher.id)
                                        .toList();
                                    final hasCourses = teacherAssignments.isNotEmpty;

                                    return AppCard(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 1. Teacher Profile Header
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              CircleAvatar(
                                                radius: 24,
                                                backgroundColor: isDark
                                                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                                                    : const Color(0xFFEFF6FF),
                                                child: Text(
                                                  _getInitials(teacher.fullName),
                                                  style: TextStyle(
                                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      teacher.fullName,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 15,
                                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      teacher.email,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Add Course Action Button
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                                  side: BorderSide(color: isDark ? const Color(0xFFFBBF24).withValues(alpha: 0.5) : const Color(0xFFFBBF24)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  minimumSize: const Size(0, 34),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                                icon: const Icon(Icons.add_rounded, size: 16),
                                                label: const Text(
                                                  'Add',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                                onPressed: () => _showAssignDialog(preselectedTeacher: teacher),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 12),
                                          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9)),
                                          const SizedBox(height: 10),

                                          // 2. Allocated Courses Section
                                          if (!hasCourses)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.2) : const Color(0xFFFFFBEB),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFFFDE68A)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.info_outline_rounded,
                                                    size: 20,
                                                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      'No courses currently allocated',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFD97706),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      minimumSize: const Size(0, 32),
                                                      elevation: 0,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                    icon: const Icon(Icons.add_rounded, size: 14),
                                                    label: const Text(
                                                      'Allocate',
                                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                    onPressed: () => _showAssignDialog(preselectedTeacher: teacher),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 8),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Allocated Courses (${teacherAssignments.length})',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                ...teacherAssignments.map((a) {
                                                  return Container(
                                                    margin: const EdgeInsets.only(bottom: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? const Color(0xFF0B1C30) : const Color(0xFFF8FAFC),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: isDark ? const Color(0xFF2563EB) : const Color(0xFF1D4ED8),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            a.courseCode,
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                a.courseTitle,
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.w600,
                                                                  fontSize: 13,
                                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              if (a.isCoordinator) ...[
                                                                const SizedBox(height: 2),
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(
                                                                    horizontal: 6,
                                                                    vertical: 1,
                                                                  ),
                                                                  decoration: BoxDecoration(
                                                                    color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7),
                                                                    borderRadius: BorderRadius.circular(4),
                                                                  ),
                                                                  child: Text(
                                                                    'Coordinator',
                                                                    style: TextStyle(
                                                                      fontSize: 10,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.remove_circle_outline_rounded,
                                                            size: 20,
                                                            color: Color(0xFFDC2626),
                                                          ),
                                                          tooltip: 'Remove ${a.courseCode}',
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                          onPressed: () => _removeAssignment(a, teacher.fullName),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }),
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
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 6. ADMIN ATTENDANCE OVERVIEW SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class AdminAttendanceOverviewScreen extends StatefulWidget {
  final AdminRepository? repository;

  const AdminAttendanceOverviewScreen({super.key, this.repository});

  @override
  State<AdminAttendanceOverviewScreen> createState() => _AdminAttendanceOverviewScreenState();
}

class _AdminAttendanceOverviewScreenState extends State<AdminAttendanceOverviewScreen> {
  late final AdminRepository _repository;
  List<AttendanceSession> _sessions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? (sl.isRegistered<AdminRepository>() ? sl<AdminRepository>() : _FallbackAdminRepo());
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getAllAttendanceSessions();
      if (!mounted) return;
      setState(() {
        _sessions = list;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Administration'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadSessions),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: AppLoadingView(message: 'Loading attendance sessions...'))
          : _errorMessage != null
              ? Center(child: AppErrorStateView(message: _errorMessage!, onRetry: _loadSessions))
              : _sessions.isEmpty
                  ? const Center(child: AppEmptyStateView(title: 'No Sessions Recorded', message: 'Attendance sessions launched by teachers will appear here.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final s = _sessions[i];
                        final isActive = s.status == 'ACTIVE';

                        return AppCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5))
                                      : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  s.code,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w900,
                                    color: isActive
                                        ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                                        : (isDark ? Colors.white38 : Colors.grey),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(s.courseCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5))
                                                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            s.status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isActive
                                                  ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                                                  : (isDark ? Colors.white60 : Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(s.courseTitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text('Date: ${s.sessionDate} • Verified: ${s.totalPresentCount} Students', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 7. ADMIN FEEDBACK MODERATION SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class AdminFeedbackModerationScreen extends StatefulWidget {
  final AdminRepository? repository;

  const AdminFeedbackModerationScreen({super.key, this.repository});

  @override
  State<AdminFeedbackModerationScreen> createState() => _AdminFeedbackModerationScreenState();
}

class _AdminFeedbackModerationScreenState extends State<AdminFeedbackModerationScreen> {
  late final AdminRepository _repository;
  List<FeedbackItem> _feedback = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? (sl.isRegistered<AdminRepository>() ? sl<AdminRepository>() : _FallbackAdminRepo());
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repository.getAllFeedbackItems();
      if (!mounted) return;
      setState(() {
        _feedback = list;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Administration'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadFeedback),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: AppLoadingView(message: 'Loading feedback submissions...'))
          : _errorMessage != null
              ? Center(child: AppErrorStateView(message: _errorMessage!, onRetry: _loadFeedback))
              : _feedback.isEmpty
                  ? const Center(child: AppEmptyStateView(title: 'No Feedback Submitted', message: 'Student evaluations will appear here.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _feedback.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final item = _feedback[i];

                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${item.courseCode} - ${item.teacherName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Row(
                                    children: List.generate(5, (s) {
                                      return Icon(
                                        s < item.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                        size: 16,
                                        color: const Color(0xFFEAB308),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(item.comments, style: const TextStyle(fontSize: 13, height: 1.4)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      if (item.isAnonymous)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Anonymous Student',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white60 : Colors.grey,
                                            ),
                                          ),
                                        )
                                      else
                                        const Text('By: Department Student', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                  Text(item.createdAt.substring(0, 10), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 8. ADMIN SETTINGS SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        actions: const [ThemeToggleButton(showBackground: false), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Departmental Configurations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.account_balance_rounded, color: Color(0xFF7E22CE)),
              title: const Text('Department Name'),
              subtitle: const Text('Computer Science & Engineering, JnU'),
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.calendar_month_rounded, color: Color(0xFF047857)),
              title: const Text('Academic Calendar'),
              subtitle: const Text('Semester System • Year 1 - Year 4'),
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.security_rounded, color: Color(0xFF1D4ED8)),
              title: const Text('Security & RBAC Authority'),
              subtitle: const Text('Declarative Rules + Cloud Functions Gen 2'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FALLBACK REPOSITORY FOR TESTS OR UNWIRED CONTEXTS
// ═════════════════════════════════════════════════════════════════════════════

class _FallbackAdminRepo implements AdminRepository {
  @override
  Future<AdminOverviewStats> getOverviewStats() async => const AdminOverviewStats();
  @override
  Future<List<User>> getAllUsers({UserRole? roleFilter}) async => [];
  @override
  Future<User> createUser({required String fullName, required String email, required String password, required UserRole role, String? studentId, String? phone, int? year, int? semester}) async => User(id: 'u1', email: email, fullName: fullName, role: role);
  @override
  Future<void> deleteUser({required String userId}) async {}
  @override
  Future<void> toggleUserActiveStatus({required String userId, required bool isActive}) async {}
  @override
  Future<List<Course>> getAllCourses() async => [];
  @override
  Future<void> createCourse(Course course) async {}
  @override
  Future<void> updateCourse(Course course) async {}
  @override
  Future<void> deleteCourse(String courseId) async {}
  @override
  Future<List<CourseAssignment>> getAllCourseAssignments() async => [];
  @override
  Future<void> assignCourseToTeacher({required String courseId, required String teacherId, bool isCoordinator = false}) async {}
  @override
  Future<void> removeCourseAssignment({required String assignmentId, required String courseId, required String teacherId}) async {}
  @override
  Future<List<SignupRequest>> getPendingSignupRequests() async => [];
  @override
  Future<List<SignupRequest>> getAllSignupRequests({String? statusFilter}) async => [];
  @override
  Future<void> approveSignup({required String requestId, int? assignedYear, int? assignedSemester}) async {}
  @override
  Future<void> rejectSignup({required String requestId, required String reason}) async {}
  @override
  Future<List<SemesterUpgradeRequest>> getPendingSemesterRequests() async => [];
  @override
  Future<List<SemesterUpgradeRequest>> getAllSemesterRequests({String? statusFilter}) async => [];
  @override
  Future<void> approveSemesterUpgrade({required String requestId}) async {}
  @override
  Future<void> rejectSemesterUpgrade({required String requestId, String? reason}) async {}
  @override
  Future<List<AttendanceSession>> getAllAttendanceSessions() async => [];
  @override
  Future<List<FeedbackItem>> getAllFeedbackItems() async => [];
  @override
  Future<List<DepartmentNotice>> getAllNotices() async => [];
  @override
  Future<void> sendBroadcastNotice({
    required String title,
    required String message,
    required String noticeType,
    required String targetAudience,
    String? attachmentUrl,
    String? attachmentType,
    String priority = 'NORMAL',
    bool syncToPublicRoutines = false,
  }) async {}
  @override
  Future<void> deleteNotice(String noticeId) async {}
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/local_storage_service.dart';
import '../storage/cloud_storage_service.dart';
import '../communication/whatsapp_share_service.dart';
import '../notifications/push_notification_service.dart';
import '../../app/theme/theme_controller.dart';

// Auth Feature
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/signup_request_usecase.dart';
import '../../features/auth/domain/usecases/reset_password_usecase.dart';
import '../../features/auth/domain/repositories/user_repository.dart';
import '../../features/auth/data/repositories/user_repository_impl.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';

// Curriculum Feature
import '../../features/curriculum/data/repositories/curriculum_repository_impl.dart';
import '../../features/curriculum/domain/repositories/curriculum_repository.dart';
import '../../features/curriculum/presentation/controllers/schedule_controller.dart';

// Attendance Feature
import '../../features/attendance/data/repositories/attendance_repository_impl.dart';
import '../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../features/attendance/presentation/controllers/attendance_controller.dart';

// Counseling Feature
import '../../features/counseling/data/repositories/counseling_repository_impl.dart';
import '../../features/counseling/domain/repositories/counseling_repository.dart';
import '../../features/counseling/presentation/controllers/counseling_controller.dart';

// Feedback Feature
import '../../features/feedback/data/repositories/feedback_repository_impl.dart';
import '../../features/feedback/domain/repositories/feedback_repository.dart';
import '../../features/feedback/presentation/controllers/feedback_controller.dart';

// Profile / Semester Feature
import '../../features/profile/data/repositories/semester_repository_impl.dart';
import '../../features/profile/domain/repositories/semester_repository.dart';
import '../../features/profile/presentation/controllers/profile_controller.dart';

// Notifications Feature
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/presentation/controllers/notification_controller.dart';

// Admin Feature
import '../../features/admin/data/datasources/admin_remote_datasource.dart';
import '../../features/admin/data/repositories/admin_repository_impl.dart';
import '../../features/admin/domain/repositories/admin_repository.dart';
import '../../features/admin/domain/usecases/admin_usecases.dart';
import '../../features/admin/presentation/controllers/admin_dashboard_controller.dart';

// Teacher Feature
import '../../features/teacher/data/datasources/teacher_remote_datasource.dart';
import '../../features/teacher/data/repositories/teacher_repository_impl.dart';
import '../../features/teacher/domain/repositories/teacher_repository.dart';
import '../../features/teacher/domain/usecases/get_teacher_dashboard_data_usecase.dart';
import '../../features/teacher/presentation/controllers/teacher_dashboard_controller.dart';

// CR Feature
import '../../features/cr/data/datasources/cr_remote_datasource.dart';
import '../../features/cr/data/repositories/cr_repository_impl.dart';
import '../../features/cr/domain/repositories/cr_repository.dart';
import '../../features/cr/domain/usecases/add_tomorrow_slot_usecase.dart';
import '../../features/cr/domain/usecases/get_cr_dashboard_data_usecase.dart';
import '../../features/cr/presentation/controllers/cr_dashboard_controller.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // 1. External & Native Platform Services
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  // 2. Firebase SDK singletons
  sl.registerLazySingleton<fb.FirebaseAuth>(() => fb.FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  sl.registerLazySingleton<FirebaseMessaging>(() => FirebaseMessaging.instance);
  sl.registerLazySingleton<FirebaseFunctions>(() => FirebaseFunctions.instance);

  // 3. Core Storage Services
  sl.registerLazySingleton<LocalStorageService>(
    () => LocalStorageServiceImpl(prefs: sl()),
  );

  sl.registerLazySingleton<CloudStorageService>(
    () => CloudStorageServiceImpl(storage: sl()),
  );

  sl.registerLazySingleton<WhatsAppShareService>(
    () => WhatsAppShareService(),
  );

  sl.registerLazySingleton<ThemeController>(
    () => ThemeController(localStorageService: sl()),
  );

  sl.registerLazySingleton<ValueNotifier<ThemeMode>>(
    () => sl<ThemeController>(),
  );

  // 4. Auth Feature
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      auth: sl(),
      firestore: sl(),
    ),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localStorage: sl(),
    ),
  );

  sl.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(repository: sl()),
  );

  sl.registerLazySingleton<GetCurrentUserUseCase>(
    () => GetCurrentUserUseCase(repository: sl()),
  );

  sl.registerLazySingleton<LogoutUseCase>(
    () => LogoutUseCase(repository: sl()),
  );

  sl.registerLazySingleton<ResetPasswordUseCase>(
    () => ResetPasswordUseCase(repository: sl()),
  );

  sl.registerLazySingleton<SignupRequestUseCase>(
    () => SignupRequestUseCase(repository: sl()),
  );

  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(firestore: sl()),
  );

  sl.registerLazySingleton<AuthController>(
    () => AuthController(
      loginUseCase: sl(),
      getCurrentUserUseCase: sl(),
      logoutUseCase: sl(),
      resetPasswordUseCase: sl(),
      authRepository: sl(),
      pushNotificationService: sl(),
    )..startAuthListener(),
  );

  // 5. Curriculum Feature
  sl.registerLazySingleton<CurriculumRemoteDataSource>(
    () => CurriculumRemoteDataSourceImpl(
      firestore: sl(),
      auth: sl(),
      functions: sl(),
    ),
  );

  sl.registerLazySingleton<CurriculumRepository>(
    () => CurriculumRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<GetMyCoursesUseCase>(
    () => GetMyCoursesUseCase(sl()),
  );

  sl.registerLazySingleton<GetScheduleUseCase>(
    () => GetScheduleUseCase(sl()),
  );

  sl.registerLazySingleton<CreateScheduleSlotUseCase>(
    () => CreateScheduleSlotUseCase(sl()),
  );

  sl.registerLazySingleton<UpdateScheduleSlotUseCase>(
    () => UpdateScheduleSlotUseCase(sl()),
  );

  sl.registerLazySingleton<DeleteScheduleSlotUseCase>(
    () => DeleteScheduleSlotUseCase(sl()),
  );

  sl.registerLazySingleton<GetTeacherAvailabilityUseCase>(
    () => GetTeacherAvailabilityUseCase(sl()),
  );

  sl.registerLazySingleton<GetWhatsAppBroadcastUseCase>(
    () => GetWhatsAppBroadcastUseCase(sl()),
  );

  sl.registerLazySingleton<GetAllCoursesUseCase>(
    () => GetAllCoursesUseCase(sl()),
  );

  sl.registerLazySingleton<GetAllTeachersUseCase>(
    () => GetAllTeachersUseCase(sl()),
  );

  sl.registerLazySingleton<GetExamsUseCase>(
    () => GetExamsUseCase(sl()),
  );

  sl.registerLazySingleton<CreateExamUseCase>(
    () => CreateExamUseCase(sl()),
  );

  sl.registerLazySingleton<UpdateExamUseCase>(
    () => UpdateExamUseCase(sl()),
  );

  sl.registerLazySingleton<DeleteExamUseCase>(
    () => DeleteExamUseCase(sl()),
  );

  sl.registerFactory<ScheduleController>(
    () => ScheduleController(
      getScheduleUseCase: sl(),
      createScheduleSlotUseCase: sl(),
      updateScheduleSlotUseCase: sl(),
      deleteScheduleSlotUseCase: sl(),
      getTeacherAvailabilityUseCase: sl(),
      getWhatsAppBroadcastUseCase: sl(),
      getAllCoursesUseCase: sl(),
      getAllTeachersUseCase: sl(),
    ),
  );

  sl.registerFactory<ExamsController>(
    () => ExamsController(
      getExamsUseCase: sl(),
      createExamUseCase: sl(),
      updateExamUseCase: sl(),
      deleteExamUseCase: sl(),
      getAllCoursesUseCase: sl(),
    ),
  );

  // 6. Attendance Feature
  sl.registerLazySingleton<AttendanceRemoteDataSource>(
    () => AttendanceRemoteDataSourceImpl(
      firestore: sl(),
      auth: sl(),
      functions: sl(),
    ),
  );

  sl.registerLazySingleton<AttendanceRepository>(
    () => AttendanceRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<GetAttendanceSummaryUseCase>(
    () => GetAttendanceSummaryUseCase(sl()),
  );

  sl.registerLazySingleton<VerifyAttendanceCodeUseCase>(
    () => VerifyAttendanceCodeUseCase(sl()),
  );

  sl.registerLazySingleton<StartAttendanceSessionUseCase>(
    () => StartAttendanceSessionUseCase(sl()),
  );

  sl.registerLazySingleton<DeactivateAttendanceSessionUseCase>(
    () => DeactivateAttendanceSessionUseCase(sl()),
  );

  sl.registerLazySingleton<GetActiveAttendanceSessionUseCase>(
    () => GetActiveAttendanceSessionUseCase(sl()),
  );

  sl.registerLazySingleton<GetSessionRosterUseCase>(
    () => GetSessionRosterUseCase(sl()),
  );

  sl.registerLazySingleton<UpdateAttendanceRosterUseCase>(
    () => UpdateAttendanceRosterUseCase(sl()),
  );

  sl.registerFactory<AttendanceController>(
    () => AttendanceController(
      getAttendanceSummaryUseCase: sl(),
      verifyAttendanceCodeUseCase: sl(),
      startAttendanceSessionUseCase: sl(),
      deactivateAttendanceSessionUseCase: sl(),
      getActiveAttendanceSessionUseCase: sl(),
      getSessionRosterUseCase: sl(),
      updateAttendanceRosterUseCase: sl(),
    ),
  );

  // 7. Counseling Feature
  sl.registerLazySingleton<CounselingRemoteDataSource>(
    () => CounselingRemoteDataSourceImpl(
      firestore: sl(),
      auth: sl(),
      functions: sl.isRegistered<FirebaseFunctions>() ? sl<FirebaseFunctions>() : null,
    ),
  );

  sl.registerLazySingleton<CounselingRepository>(
    () => CounselingRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<GetAvailableSlotsUseCase>(
    () => GetAvailableSlotsUseCase(sl()),
  );

  sl.registerLazySingleton<RequestBookingUseCase>(
    () => RequestBookingUseCase(sl()),
  );

  sl.registerLazySingleton<GetMyBookingsUseCase>(
    () => GetMyBookingsUseCase(sl()),
  );

  sl.registerLazySingleton<CancelBookingUseCase>(
    () => CancelBookingUseCase(sl()),
  );

  sl.registerLazySingleton<CreateCounselingSlotUseCase>(
    () => CreateCounselingSlotUseCase(sl()),
  );

  sl.registerLazySingleton<GetTeacherSlotsUseCase>(
    () => GetTeacherSlotsUseCase(sl()),
  );

  sl.registerLazySingleton<GetTeacherRequestsUseCase>(
    () => GetTeacherRequestsUseCase(sl()),
  );

  sl.registerLazySingleton<ApproveBookingUseCase>(
    () => ApproveBookingUseCase(sl()),
  );

  sl.registerLazySingleton<RejectBookingUseCase>(
    () => RejectBookingUseCase(sl()),
  );

  sl.registerLazySingleton<DeleteCounselingSlotUseCase>(
    () => DeleteCounselingSlotUseCase(sl()),
  );

  sl.registerFactory<CounselingController>(
    () => CounselingController(
      getAvailableSlotsUseCase: sl(),
      requestBookingUseCase: sl(),
      getMyBookingsUseCase: sl(),
      cancelBookingUseCase: sl(),
      createCounselingSlotUseCase: sl(),
      getTeacherSlotsUseCase: sl(),
      getTeacherRequestsUseCase: sl(),
      approveBookingUseCase: sl(),
      rejectBookingUseCase: sl(),
      deleteCounselingSlotUseCase: sl(),
    ),
  );

  // 8. Feedback Feature
  sl.registerLazySingleton<FeedbackRemoteDataSource>(
    () => FeedbackRemoteDataSourceImpl(
      firestore: sl(),
      auth: sl(),
      functions: sl(),
    ),
  );

  sl.registerLazySingleton<FeedbackRepository>(
    () => FeedbackRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<SubmitFeedbackUseCase>(
    () => SubmitFeedbackUseCase(sl()),
  );

  sl.registerLazySingleton<EditFeedbackUseCase>(
    () => EditFeedbackUseCase(sl()),
  );

  sl.registerLazySingleton<GetMyFeedbackUseCase>(
    () => GetMyFeedbackUseCase(sl()),
  );

  sl.registerLazySingleton<GetTeacherFeedbackUseCase>(
    () => GetTeacherFeedbackUseCase(sl()),
  );

  sl.registerLazySingleton<ReplyToFeedbackUseCase>(
    () => ReplyToFeedbackUseCase(sl()),
  );

  sl.registerLazySingleton<EditFeedbackReplyUseCase>(
    () => EditFeedbackReplyUseCase(sl()),
  );

  sl.registerLazySingleton<GetAdminFeedbackUseCase>(
    () => GetAdminFeedbackUseCase(sl()),
  );

  sl.registerFactory<FeedbackController>(
    () => FeedbackController(
      submitFeedbackUseCase: sl(),
      editFeedbackUseCase: sl(),
      getMyFeedbackUseCase: sl(),
      getTeacherFeedbackUseCase: sl(),
      replyToFeedbackUseCase: sl(),
      editFeedbackReplyUseCase: sl(),
      getAdminFeedbackUseCase: sl(),
    ),
  );

  // 9. Profile & Semester Feature
  sl.registerLazySingleton<SemesterRemoteDataSource>(
    () => SemesterRemoteDataSourceImpl(
      firestore: sl(),
      auth: sl(),
    ),
  );

  sl.registerLazySingleton<SemesterRepository>(
    () => SemesterRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<GetSemesterStatusUseCase>(
    () => GetSemesterStatusUseCase(sl()),
  );

  sl.registerLazySingleton<RequestSemesterUpgradeUseCase>(
    () => RequestSemesterUpgradeUseCase(sl()),
  );

  sl.registerLazySingleton<ChangeSemesterUpgradeRequestUseCase>(
    () => ChangeSemesterUpgradeRequestUseCase(sl()),
  );

  sl.registerLazySingleton<DismissSemesterRejectionUseCase>(
    () => DismissSemesterRejectionUseCase(sl()),
  );

  sl.registerFactory<ProfileController>(
    () => ProfileController(
      getSemesterStatusUseCase: sl(),
      requestSemesterUpgradeUseCase: sl(),
      changeSemesterUpgradeRequestUseCase: sl(),
      dismissSemesterRejectionUseCase: sl(),
    ),
  );

  // 10. Notifications Feature
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(
      firestore: sl(),
      auth: sl(),
    ),
  );

  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<GetNotificationsUseCase>(
    () => GetNotificationsUseCase(sl()),
  );

  sl.registerLazySingleton<MarkNotificationReadUseCase>(
    () => MarkNotificationReadUseCase(sl()),
  );

  sl.registerLazySingleton<MarkAllNotificationsReadUseCase>(
    () => MarkAllNotificationsReadUseCase(sl()),
  );

  sl.registerLazySingleton<PushNotificationService>(
    () => PushNotificationServiceImpl(
      messaging: sl(),
      notificationRepository: sl(),
    ),
  );

  sl.registerFactory<NotificationController>(
    () => NotificationController(
      getNotificationsUseCase: sl(),
      markNotificationReadUseCase: sl(),
      markAllNotificationsReadUseCase: sl(),
    ),
  );

  // 11. Admin Feature
  sl.registerLazySingleton<AdminRemoteDataSource>(
    () => AdminRemoteDataSourceImpl(
      firestore: sl(),
      functions: sl(),
    ),
  );

  sl.registerLazySingleton<AdminRepository>(
    () => AdminRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<GetAdminDashboardDataUseCase>(
    () => GetAdminDashboardDataUseCase(sl()),
  );

  sl.registerLazySingleton<ApproveSignupRequestUseCase>(
    () => ApproveSignupRequestUseCase(sl()),
  );

  sl.registerLazySingleton<RejectSignupRequestUseCase>(
    () => RejectSignupRequestUseCase(sl()),
  );

  sl.registerLazySingleton<ApproveSemesterUpgradeUseCase>(
    () => ApproveSemesterUpgradeUseCase(sl()),
  );

  sl.registerLazySingleton<RejectSemesterUpgradeUseCase>(
    () => RejectSemesterUpgradeUseCase(sl()),
  );

  sl.registerFactory<AdminDashboardController>(
    () => AdminDashboardController(
      getDataUseCase: sl(),
      approveSignupUseCase: sl(),
      rejectSignupUseCase: sl(),
      approveSemesterUseCase: sl(),
      rejectSemesterUseCase: sl(),
    ),
  );

  // 12. Teacher Feature
  sl.registerLazySingleton<TeacherRemoteDataSource>(
    () => TeacherRemoteDataSourceImpl(firestore: sl()),
  );

  sl.registerLazySingleton<TeacherRepository>(
    () => TeacherRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<GetTeacherDashboardDataUseCase>(
    () => GetTeacherDashboardDataUseCase(sl()),
  );

  sl.registerFactory<TeacherDashboardController>(
    () => TeacherDashboardController(
      getTeacherDashboardDataUseCase: sl(),
      authController: sl(),
    ),
  );

  // 13. CR Feature
  sl.registerLazySingleton<CrRemoteDataSource>(
    () => CrRemoteDataSourceImpl(firestore: sl()),
  );

  sl.registerLazySingleton<CrRepository>(
    () => CrRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<GetCrDashboardDataUseCase>(
    () => GetCrDashboardDataUseCase(sl()),
  );

  sl.registerLazySingleton<AddTomorrowSlotUseCase>(
    () => AddTomorrowSlotUseCase(sl()),
  );

  sl.registerFactory<CrDashboardController>(
    () => CrDashboardController(
      getCrDashboardDataUseCase: sl(),
      addTomorrowSlotUseCase: sl(),
      authController: sl(),
    ),
  );
}

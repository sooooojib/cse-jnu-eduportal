import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/local_storage_service.dart';
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
    ),
  );

  // 5. Curriculum Feature
  sl.registerLazySingleton<CurriculumRemoteDataSource>(
    () => CurriculumRemoteDataSourceImpl(
      firestore: sl(),
      auth: sl(),
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

  sl.registerLazySingleton<GetExamsUseCase>(
    () => GetExamsUseCase(sl()),
  );

  sl.registerFactory<ScheduleController>(
    () => ScheduleController(getScheduleUseCase: sl()),
  );

  sl.registerFactory<ExamsController>(
    () => ExamsController(getExamsUseCase: sl()),
  );

  // 6. Attendance Feature
  sl.registerLazySingleton<AttendanceRemoteDataSource>(
    () => AttendanceRemoteDataSourceImpl(
      firestore: sl(),
      auth: sl(),
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

  sl.registerFactory<AttendanceController>(
    () => AttendanceController(
      getAttendanceSummaryUseCase: sl(),
      verifyAttendanceCodeUseCase: sl(),
    ),
  );

  // 7. Counseling Feature
  sl.registerLazySingleton<CounselingRemoteDataSource>(
    () => CounselingRemoteDataSourceImpl(
      firestore: sl(),
      auth: sl(),
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

  sl.registerFactory<CounselingController>(
    () => CounselingController(
      getAvailableSlotsUseCase: sl(),
      requestBookingUseCase: sl(),
      getMyBookingsUseCase: sl(),
      cancelBookingUseCase: sl(),
    ),
  );

  // 8. Feedback Feature
  sl.registerLazySingleton<FeedbackRemoteDataSource>(
    () => FeedbackRemoteDataSourceImpl(
      firestore: sl(),
      auth: sl(),
    ),
  );

  sl.registerLazySingleton<FeedbackRepository>(
    () => FeedbackRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<SubmitFeedbackUseCase>(
    () => SubmitFeedbackUseCase(sl()),
  );

  sl.registerLazySingleton<GetMyFeedbackUseCase>(
    () => GetMyFeedbackUseCase(sl()),
  );

  sl.registerFactory<FeedbackController>(
    () => FeedbackController(
      submitFeedbackUseCase: sl(),
      getMyFeedbackUseCase: sl(),
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

  sl.registerFactory<ProfileController>(
    () => ProfileController(
      getSemesterStatusUseCase: sl(),
      requestSemesterUpgradeUseCase: sl(),
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

  sl.registerFactory<NotificationController>(
    () => NotificationController(
      getNotificationsUseCase: sl(),
      markNotificationReadUseCase: sl(),
      markAllNotificationsReadUseCase: sl(),
    ),
  );
}

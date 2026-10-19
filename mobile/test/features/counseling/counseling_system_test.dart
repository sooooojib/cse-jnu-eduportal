import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart' as di;
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';
import 'package:cse_jnu_eduportal/features/counseling/domain/entities/counseling_entities.dart';
import 'package:cse_jnu_eduportal/features/counseling/domain/repositories/counseling_repository.dart';
import 'package:cse_jnu_eduportal/features/counseling/presentation/controllers/counseling_controller.dart';
import 'package:cse_jnu_eduportal/features/counseling/presentation/screens/student_counseling_screen.dart';
import 'package:cse_jnu_eduportal/features/counseling/presentation/screens/teacher_counseling_screen.dart';

class MockCounselingRepository extends Mock implements CounselingRepository {}
class MockAuthController extends Mock implements AuthController {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CounselingSlot(
        id: 'slot-1',
        teacherId: 'teacher-1',
        teacherName: 'Dr. Md. Abu Layek',
        teacherEmail: 'layek@cse.jnu.ac.bd',
        slotDate: '2026-11-20',
        startTime: '10:00',
        endTime: '11:00',
        status: 'AVAILABLE',
      ),
    );
  });

  late MockCounselingRepository mockRepository;
  late MockAuthController mockAuthController;

  // Use cases
  late GetAvailableSlotsUseCase getAvailableSlotsUseCase;
  late RequestBookingUseCase requestBookingUseCase;
  late GetMyBookingsUseCase getMyBookingsUseCase;
  late CancelBookingUseCase cancelBookingUseCase;
  late CreateCounselingSlotUseCase createCounselingSlotUseCase;
  late GetTeacherSlotsUseCase getTeacherSlotsUseCase;
  late GetTeacherRequestsUseCase getTeacherRequestsUseCase;
  late ApproveBookingUseCase approveBookingUseCase;
  late RejectBookingUseCase rejectBookingUseCase;
  late DeleteCounselingSlotUseCase deleteCounselingSlotUseCase;

  late CounselingController controller;

  final sampleTeacher = User(
    id: 'teacher-layek-uid',
    email: 'layek@cse.jnu.ac.bd',
    fullName: 'Dr. Md. Abu Layek',
    role: UserRole.teacher,
    phone: '+8801700000001',
    isActive: true,
  );

  final sampleSlots = [
    const CounselingSlot(
      id: 'slot-1',
      teacherId: 'teacher-layek-uid',
      teacherName: 'Dr. Md. Abu Layek',
      teacherEmail: 'layek@cse.jnu.ac.bd',
      slotDate: '2026-11-20',
      startTime: '10:00',
      endTime: '11:00',
      status: 'AVAILABLE',
      notes: 'Room 501, Department of CSE',
    ),
    const CounselingSlot(
      id: 'slot-2',
      teacherId: 'teacher-layek-uid',
      teacherName: 'Dr. Md. Abu Layek',
      teacherEmail: 'layek@cse.jnu.ac.bd',
      slotDate: '2026-11-21',
      startTime: '14:00',
      endTime: '15:00',
      status: 'BOOKED',
      bookedStudentId: 'student-1',
      bookedStudentName: 'Rahim Student',
      notes: 'Room 501',
    ),
  ];

  final sampleBookings = [
    const CounselingBooking(
      id: 'booking-1',
      slotId: 'slot-1',
      studentId: 'student-1',
      studentName: 'Rahim Student',
      teacherId: 'teacher-layek-uid',
      teacherName: 'Dr. Md. Abu Layek',
      slotDate: '2026-11-20',
      startTime: '10:00',
      endTime: '11:00',
      category: 'Academic Advising',
      notes: 'Discussion regarding final semester project thesis.',
      status: 'PENDING',
      createdAt: '2026-11-19T10:00:00Z',
    ),
  ];

  setUp(() {
    mockRepository = MockCounselingRepository();
    mockAuthController = MockAuthController();

    getAvailableSlotsUseCase = GetAvailableSlotsUseCase(mockRepository);
    requestBookingUseCase = RequestBookingUseCase(mockRepository);
    getMyBookingsUseCase = GetMyBookingsUseCase(mockRepository);
    cancelBookingUseCase = CancelBookingUseCase(mockRepository);
    createCounselingSlotUseCase = CreateCounselingSlotUseCase(mockRepository);
    getTeacherSlotsUseCase = GetTeacherSlotsUseCase(mockRepository);
    getTeacherRequestsUseCase = GetTeacherRequestsUseCase(mockRepository);
    approveBookingUseCase = ApproveBookingUseCase(mockRepository);
    rejectBookingUseCase = RejectBookingUseCase(mockRepository);
    deleteCounselingSlotUseCase = DeleteCounselingSlotUseCase(mockRepository);

    controller = CounselingController(
      getAvailableSlotsUseCase: getAvailableSlotsUseCase,
      requestBookingUseCase: requestBookingUseCase,
      getMyBookingsUseCase: getMyBookingsUseCase,
      cancelBookingUseCase: cancelBookingUseCase,
      createCounselingSlotUseCase: createCounselingSlotUseCase,
      getTeacherSlotsUseCase: getTeacherSlotsUseCase,
      getTeacherRequestsUseCase: getTeacherRequestsUseCase,
      approveBookingUseCase: approveBookingUseCase,
      rejectBookingUseCase: rejectBookingUseCase,
      deleteCounselingSlotUseCase: deleteCounselingSlotUseCase,
    );

    when(() => mockAuthController.currentUser).thenReturn(sampleTeacher);
    when(() => mockAuthController.state).thenReturn(Authenticated(user: sampleTeacher));

    // Register into get_it for screens that resolve sl()
    if (di.sl.isRegistered<CounselingController>()) {
      di.sl.unregister<CounselingController>();
    }
    di.sl.registerFactory<CounselingController>(() => controller);
  });

  group('STAGE 23: Counseling System Controller Unit Tests', () {
    test('1. Student fetchAll loads available slots and user bookings', () async {
      when(() => mockRepository.getAvailableSlots(teacherId: any(named: 'teacherId')))
          .thenAnswer((_) async => sampleSlots);
      when(() => mockRepository.getMyBookings()).thenAnswer((_) async => sampleBookings);

      await controller.fetchAll();

      expect(controller.state, isA<CounselingLoaded>());
      final loaded = controller.state as CounselingLoaded;
      expect(loaded.availableSlots.length, 2);
      expect(loaded.myBookings.length, 1);
      expect(loaded.myBookings.first.category, 'Academic Advising');
    });

    test('2. Student can book slot with each of the 6 approved purposes', () async {
      final purposes = [
        'Academic Advising',
        'Research Discussion',
        'Mental Pressure',
        'Class Issue',
        'Career Guidance',
        'Other',
      ];

      when(() => mockRepository.getAvailableSlots(teacherId: any(named: 'teacherId')))
          .thenAnswer((_) async => sampleSlots);
      when(() => mockRepository.getMyBookings()).thenAnswer((_) async => sampleBookings);

      for (final purpose in purposes) {
        when(() => mockRepository.requestBooking('slot-1', category: purpose, notes: 'Valid agenda'))
            .thenAnswer((_) async => CounselingBooking(
                  id: 'booking-new',
                  slotId: 'slot-1',
                  teacherId: 'teacher-layek-uid',
                  teacherName: 'Dr. Md. Abu Layek',
                  slotDate: '2026-11-20',
                  startTime: '10:00',
                  endTime: '11:00',
                  category: purpose,
                  notes: 'Valid agenda',
                  status: 'PENDING',
                  createdAt: '2026-11-19T10:00:00Z',
                ));

        final success = await controller.bookSlot('slot-1', category: purpose, notes: 'Valid agenda');
        expect(success, true);
        verify(() => mockRepository.requestBooking('slot-1', category: purpose, notes: 'Valid agenda')).called(1);
      }
    });

    test('3. Teacher fetchTeacherData loads office slots and requests', () async {
      when(() => mockRepository.getTeacherSlots('teacher-layek-uid'))
          .thenAnswer((_) async => sampleSlots);
      when(() => mockRepository.getTeacherRequests('teacher-layek-uid'))
          .thenAnswer((_) async => sampleBookings);

      await controller.fetchTeacherData('teacher-layek-uid');

      expect(controller.state, isA<CounselingLoaded>());
      final loaded = controller.state as CounselingLoaded;
      expect(loaded.teacherSlots.length, 2);
      expect(loaded.teacherRequests.length, 1);
      expect(loaded.teacherRequests.first.studentName, 'Rahim Student');
    });

    test('4. Teacher creates a counseling slot', () async {
      when(() => mockRepository.createSlot(
            slotDate: '2026-11-25',
            startTime: '11:00',
            endTime: '12:00',
            notes: 'Room 501',
          )).thenAnswer((_) async => const CounselingSlot(
            id: 'slot-3',
            teacherId: 'teacher-layek-uid',
            teacherName: 'Dr. Md. Abu Layek',
            teacherEmail: 'layek@cse.jnu.ac.bd',
            slotDate: '2026-11-25',
            startTime: '11:00',
            endTime: '12:00',
            status: 'AVAILABLE',
            notes: 'Room 501',
          ));
      when(() => mockRepository.getTeacherSlots('teacher-layek-uid'))
          .thenAnswer((_) async => sampleSlots);
      when(() => mockRepository.getTeacherRequests('teacher-layek-uid'))
          .thenAnswer((_) async => sampleBookings);

      final success = await controller.createSlot(
        slotDate: '2026-11-25',
        startTime: '11:00',
        endTime: '12:00',
        notes: 'Room 501',
        teacherId: 'teacher-layek-uid',
      );

      expect(success, true);
      verify(() => mockRepository.createSlot(
            slotDate: '2026-11-25',
            startTime: '11:00',
            endTime: '12:00',
            notes: 'Room 501',
          )).called(1);
    });

    test('5. Teacher approves booking (authoritative single-booking transaction)', () async {
      when(() => mockRepository.approveBooking('booking-1')).thenAnswer((_) async {});
      when(() => mockRepository.getTeacherSlots('teacher-layek-uid'))
          .thenAnswer((_) async => sampleSlots);
      when(() => mockRepository.getTeacherRequests('teacher-layek-uid'))
          .thenAnswer((_) async => sampleBookings);

      final success = await controller.approveRequest('booking-1', teacherId: 'teacher-layek-uid');
      expect(success, true);
      verify(() => mockRepository.approveBooking('booking-1')).called(1);
    });

    test('6. Teacher rejects booking with reason', () async {
      when(() => mockRepository.rejectBooking('booking-1', reason: 'Class conflict'))
          .thenAnswer((_) async {});
      when(() => mockRepository.getTeacherSlots('teacher-layek-uid'))
          .thenAnswer((_) async => sampleSlots);
      when(() => mockRepository.getTeacherRequests('teacher-layek-uid'))
          .thenAnswer((_) async => sampleBookings);

      final success = await controller.rejectRequest(
        'booking-1',
        reason: 'Class conflict',
        teacherId: 'teacher-layek-uid',
      );
      expect(success, true);
      verify(() => mockRepository.rejectBooking('booking-1', reason: 'Class conflict')).called(1);
    });

    test('7. Teacher deletes slot', () async {
      when(() => mockRepository.deleteSlot('slot-1')).thenAnswer((_) async {});
      when(() => mockRepository.getTeacherSlots('teacher-layek-uid'))
          .thenAnswer((_) async => []);
      when(() => mockRepository.getTeacherRequests('teacher-layek-uid'))
          .thenAnswer((_) async => []);

      final success = await controller.deleteSlot('slot-1', teacherId: 'teacher-layek-uid');
      expect(success, true);
      verify(() => mockRepository.deleteSlot('slot-1')).called(1);
    });
  });

  group('STAGE 23: Counseling Screen Widgets Tests', () {
    testWidgets('8. StudentCounselingScreen renders tabs, slot cards and opens booking dialog with 6 purposes', (tester) async {
      when(() => mockRepository.getAvailableSlots(teacherId: any(named: 'teacherId')))
          .thenAnswer((_) async => sampleSlots);
      when(() => mockRepository.getMyBookings()).thenAnswer((_) async => sampleBookings);

      await tester.pumpWidget(
        const MaterialApp(
          home: StudentCounselingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check Tabs
      expect(find.text('Available Slots'), findsOneWidget);
      expect(find.text('My Appointments'), findsOneWidget);

      // Check slot cards rendered
      expect(find.text('Dr. Md. Abu Layek'), findsWidgets);
      expect(find.text('Request Appointment'), findsWidgets);

      // Tap Request Appointment on slot card
      await tester.tap(find.text('Request Appointment').first);
      await tester.pumpAndSettle();

      // Modal BottomSheet opens with title and consultation category dropdown
      expect(find.text('Request Counseling Slot'), findsOneWidget);
      expect(find.text('Consultation Category'), findsOneWidget);
      expect(find.text('Academic Advising'), findsOneWidget);

      // Close sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });

    testWidgets('9. TeacherCounselingScreen renders requests, office slots and approve/decline actions', (tester) async {
      when(() => mockRepository.getTeacherSlots('teacher-layek-uid'))
          .thenAnswer((_) async => sampleSlots);
      when(() => mockRepository.getTeacherRequests('teacher-layek-uid'))
          .thenAnswer((_) async => sampleBookings);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherCounselingScreen(
            controller: controller,
            authController: mockAuthController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and tabs
      expect(find.text('Faculty Counseling'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('My Office Slots'), findsOneWidget);
      expect(find.text('Create Slot'), findsOneWidget);

      // Check request card
      expect(find.text('Rahim Student'), findsOneWidget);
      expect(find.text('Pending Review'), findsOneWidget);
      expect(find.text('Academic Advising'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      // Switch to My Office Slots tab
      await tester.tap(find.text('My Office Slots'));
      await tester.pumpAndSettle();

      // Check office slots
      expect(find.text('2026-11-20'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('2026-11-21'), findsOneWidget);
      expect(find.text('Booked'), findsOneWidget);
      expect(find.text('Booked with: Rahim Student'), findsOneWidget);
    });

    testWidgets('10. TeacherCounselingScreen renders empty states appropriately', (tester) async {
      when(() => mockRepository.getTeacherSlots('teacher-layek-uid'))
          .thenAnswer((_) async => []);
      when(() => mockRepository.getTeacherRequests('teacher-layek-uid'))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          home: TeacherCounselingScreen(
            controller: controller,
            authController: mockAuthController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Requests empty state
      expect(find.text('No Appointment Requests'), findsOneWidget);

      // Switch to slots tab
      await tester.tap(find.text('My Office Slots'));
      await tester.pumpAndSettle();

      // Slots empty state
      expect(find.text('No Counseling Slots Created'), findsOneWidget);
      expect(find.text('Create First Slot'), findsOneWidget);
    });
  });
}

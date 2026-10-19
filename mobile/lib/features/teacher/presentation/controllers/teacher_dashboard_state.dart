import 'package:equatable/equatable.dart';
import '../../domain/entities/teacher_dashboard_data.dart';

abstract class TeacherDashboardState extends Equatable {
  const TeacherDashboardState();

  @override
  List<Object?> get props => [];
}

class TeacherDashboardInitial extends TeacherDashboardState {
  const TeacherDashboardInitial();
}

class TeacherDashboardLoading extends TeacherDashboardState {
  const TeacherDashboardLoading();
}

class TeacherDashboardLoaded extends TeacherDashboardState {
  final TeacherDashboardData data;

  const TeacherDashboardLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class TeacherDashboardError extends TeacherDashboardState {
  final String message;

  const TeacherDashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

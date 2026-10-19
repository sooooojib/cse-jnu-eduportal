import 'package:equatable/equatable.dart';
import '../../domain/entities/cr_dashboard_data.dart';

abstract class CrDashboardState extends Equatable {
  const CrDashboardState();

  @override
  List<Object?> get props => [];
}

class CrDashboardInitial extends CrDashboardState {
  const CrDashboardInitial();
}

class CrDashboardLoading extends CrDashboardState {
  final String message;
  const CrDashboardLoading({this.message = 'Loading CR Dashboard...'});

  @override
  List<Object?> get props => [message];
}

class CrDashboardLoaded extends CrDashboardState {
  final CrDashboardData data;
  const CrDashboardLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class CrDashboardError extends CrDashboardState {
  final String message;
  const CrDashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

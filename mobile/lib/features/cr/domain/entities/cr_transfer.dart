import 'package:equatable/equatable.dart';

/// Status of a CR role hand-over request.
enum CrTransferStatus {
  pending('PENDING'),
  accepted('ACCEPTED'),
  declined('DECLINED'),
  cancelled('CANCELLED');

  final String value;
  const CrTransferStatus(this.value);

  static CrTransferStatus fromString(String? v) {
    return CrTransferStatus.values.firstWhere(
      (s) => s.value == (v ?? '').toUpperCase(),
      orElse: () => CrTransferStatus.cancelled,
    );
  }
}

/// A request from the current CR to hand the CR role to a classmate in the
/// same semester and session. Stored at `crTransfers/{fromUid}`, so each CR has
/// at most one transfer at a time. It only takes effect when the classmate
/// accepts.
class CrTransfer extends Equatable {
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final int year;
  final int semester;
  final String session;
  final CrTransferStatus status;
  final DateTime? createdAt;

  const CrTransfer({
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.year,
    required this.semester,
    required this.session,
    required this.status,
    this.createdAt,
  });

  bool get isPending => status == CrTransferStatus.pending;

  @override
  List<Object?> get props => [fromUid, fromName, toUid, toName, year, semester, session, status, createdAt];
}

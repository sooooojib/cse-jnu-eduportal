import 'package:equatable/equatable.dart';

/// Metadata describing the caching status and freshness of loaded data.
class CacheMetadata extends Equatable {
  final bool isFromCache;
  final DateTime? cachedAt;
  final bool isStale;
  final String? message;

  const CacheMetadata({
    this.isFromCache = false,
    this.cachedAt,
    this.isStale = false,
    this.message,
  });

  static const fresh = CacheMetadata(isFromCache: false, isStale: false);

  static CacheMetadata cached({
    DateTime? cachedAt,
    bool isStale = false,
    String? message,
  }) {
    return CacheMetadata(
      isFromCache: true,
      cachedAt: cachedAt ?? DateTime.now(),
      isStale: isStale,
      message: message ?? 'Showing cached data',
    );
  }

  static CacheMetadata stale({
    DateTime? cachedAt,
    String? message,
  }) {
    return CacheMetadata(
      isFromCache: true,
      cachedAt: cachedAt,
      isStale: true,
      message: message ?? 'Data may be out of date. Connect to sync.',
    );
  }

  @override
  List<Object?> get props => [isFromCache, cachedAt, isStale, message];
}

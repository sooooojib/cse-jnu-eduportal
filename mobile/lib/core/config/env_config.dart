enum Environment { development, staging, production }

class EnvConfig {
  final Environment environment;
  final String apiBaseUrl;
  final bool enableLogging;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final bool enableCloudFunctions;

  const EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.enableLogging = true,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.enableCloudFunctions = false,
  });

  static EnvConfig _current = development;

  static EnvConfig get current => _current;

  static void setEnvironment(EnvConfig config) {
    _current = config;
  }

  static bool? _cloudFunctionsOverride;

  /// Global switch: returns true only if Cloud Functions backend is deployed & enabled.
  /// Defaults to false so client uses direct atomic Firestore logic with 0 latency
  /// and prevents browser CORS preflight errors in environments without deployed functions.
  /// Can be activated at compile time via `--dart-define=ENABLE_CLOUD_FUNCTIONS=true`
  /// or dynamically at runtime via [setCloudFunctionsEnabled].
  static bool get isCloudFunctionsEnabled =>
      _cloudFunctionsOverride ??
      (const bool.fromEnvironment('ENABLE_CLOUD_FUNCTIONS', defaultValue: false) ||
          _current.enableCloudFunctions);

  static void setCloudFunctionsEnabled(bool enabled) {
    _cloudFunctionsOverride = enabled;
  }

  static const EnvConfig development = EnvConfig(
    environment: Environment.development,
    apiBaseUrl: 'http://localhost:5050/api/v1',
    enableLogging: true,
    enableCloudFunctions: false,
  );

  static const EnvConfig staging = EnvConfig(
    environment: Environment.staging,
    apiBaseUrl: 'https://staging-api.cse.jnu.ac.bd/api/v1',
    enableLogging: true,
    enableCloudFunctions: false,
  );

  static const EnvConfig production = EnvConfig(
    environment: Environment.production,
    apiBaseUrl: 'https://api.cse.jnu.ac.bd/api/v1',
    enableLogging: false,
    enableCloudFunctions: false,
  );
}


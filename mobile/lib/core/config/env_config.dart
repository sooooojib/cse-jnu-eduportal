enum Environment { development, staging, production }

class EnvConfig {
  final Environment environment;
  final String apiBaseUrl;
  final bool enableLogging;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  const EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.enableLogging = true,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
  });

  static EnvConfig _current = development;

  static EnvConfig get current => _current;

  static void setEnvironment(EnvConfig config) {
    _current = config;
  }

  static const EnvConfig development = EnvConfig(
    environment: Environment.development,
    apiBaseUrl: 'http://localhost:5050/api/v1',
    enableLogging: true,
  );

  static const EnvConfig staging = EnvConfig(
    environment: Environment.staging,
    apiBaseUrl: 'https://staging-api.cse.jnu.ac.bd/api/v1',
    enableLogging: true,
  );

  static const EnvConfig production = EnvConfig(
    environment: Environment.production,
    apiBaseUrl: 'https://api.cse.jnu.ac.bd/api/v1',
    enableLogging: false,
  );
}

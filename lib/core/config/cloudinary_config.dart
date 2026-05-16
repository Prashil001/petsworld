class CloudinaryConfig {
  static const String cloudName = 'dezot0sua';
  static const String unsignedUploadPreset = 'pet-shop';
  static const String uploadFolder = 'petsworld/products';

  static bool get isConfigured =>
      cloudName.isNotEmpty && unsignedUploadPreset.isNotEmpty;

  // Image deletion requires a signed API call which needs the API secret.
  // Embedding secrets in client code is a critical security risk — anyone
  // who decompiles the APK/IPA can extract them and access your account.
  // Move deletion to a Firebase Cloud Function and flip this to true once done.
  static bool get canDeleteRemotely => false;
}

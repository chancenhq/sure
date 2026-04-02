/// User-friendly error message constants.
/// Use these instead of passing raw exception strings to the UI.
class AppErrors {
  AppErrors._();

  // Network
  static const String noInternet = 'No internet connection. Please check your network and try again.';
  static const String requestTimeout = 'This is taking longer than expected. Please check your connection and try again.';
  static const String serverError = 'Something went wrong on our end. Please try again later.';
  static const String secureConnectionFailed = 'Secure connection failed. Please check your network and try again.';
  static const String unexpected = 'Something unexpected happened. Please try again.';

  // Auth
  static const String connectionFailed = 'Unable to connect. Please check your network and try again.';
  static const String sessionExpired = 'Your session has expired. Please log in again.';

  // Chat / AI
  static const String chatLoadFailed = 'We couldn\'t load this conversation. Please try again.';
  static const String chatListLoadFailed = 'We couldn\'t load your conversations. Please try again.';
  static const String messageSendFailed = 'Your message couldn\'t be sent. Please try again.';
  static const String aiResponseTimeout = 'The AI didn\'t respond in time. You can retry or start a new chat.';
  static const String aiFeatureDisabled = 'AI chat isn\'t enabled on your account yet. Contact support to get access.';
  static const String chatDeleteFailed = 'We couldn\'t delete this conversation. Please try again.';
  static const String chatUpdateFailed = 'We couldn\'t update this conversation. Please try again.';

  // Transactions
  static const String transactionSaveFailed = 'We couldn\'t save your transaction. Please try again.';
}

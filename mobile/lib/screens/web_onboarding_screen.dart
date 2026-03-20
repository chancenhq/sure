import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_config.dart';
import '../services/preferences_service.dart';

/// Loads the web-based onboarding welcome page in a WebView so both
/// the web and mobile apps share one implementation.
///
/// Flow:
///   1. WebView opens  {baseUrl}/onboarding/welcome
///   2. User taps "Let's Get Started" → web navigates to /sessions/new
///   3. This screen intercepts that navigation, marks welcome as seen,
///      and calls [onComplete] so the app moves to native sign-in.
class WebOnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const WebOnboardingScreen({super.key, required this.onComplete});

  @override
  State<WebOnboardingScreen> createState() => _WebOnboardingScreenState();
}

class _WebOnboardingScreenState extends State<WebOnboardingScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    final welcomeUrl = '${ApiConfig.baseUrl}/onboarding/welcome';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: _handleNavigation,
          onWebResourceError: (error) {
            // On load failure fall back to native onboarding completion
            if (error.isForMainFrame == true) {
              _completeOnboarding();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(welcomeUrl));
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    // "Let's Get Started" leads to /sessions/new — intercept and hand off
    // to native auth instead of continuing inside the WebView.
    if (uri.path == '/sessions/new' || uri.path.startsWith('/users/sign_in')) {
      _completeOnboarding();
      return NavigationDecision.prevent;
    }

    // Allow all other navigation within the onboarding flow
    return NavigationDecision.navigate;
  }

  Future<void> _completeOnboarding() async {
    await PreferencesService.instance.setOnboardingComplete(true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

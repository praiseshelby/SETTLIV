import 'package:web/web.dart' as web;

void clearOAuthCodeFromUrl() {
  final uri = Uri.tryParse(web.window.location.href);
  if (uri == null || !uri.queryParameters.containsKey('code')) return;
  final nextParams = Map<String, String>.from(uri.queryParameters)
    ..remove('code')
    ..remove('state');
  final cleaned = uri.replace(
    queryParameters: nextParams.isEmpty ? null : nextParams,
  );
  var nextUrl = cleaned.toString();
  if (nextUrl.endsWith('?')) {
    nextUrl = nextUrl.substring(0, nextUrl.length - 1);
  }
  web.window.history.replaceState(null, '', nextUrl);
}

void replaceUrlToWelcome() {
  final origin = web.window.location.origin;
  web.window.history.replaceState(null, '', '$origin/#/welcome');
}

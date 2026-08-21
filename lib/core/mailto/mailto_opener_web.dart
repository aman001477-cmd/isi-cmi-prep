// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void openMailtoImpl(String email, {String subject = ''}) {
  final uri = Uri(
    scheme: 'mailto',
    path: email,
    queryParameters: subject.isEmpty ? null : {'subject': subject},
  );
  html.window.open(uri.toString(), '_self');
}

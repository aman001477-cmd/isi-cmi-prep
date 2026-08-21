import 'mailto_opener_stub.dart'
    if (dart.library.html) 'mailto_opener_web.dart' as impl;

/// Opens the user's mail app with a pre-filled recipient (mailto link).
/// On web this navigates to a mailto: URL; on VM/desktop builds it is
/// a no-op stub.
void openMailto(String email, {String subject = ''}) =>
    impl.openMailtoImpl(email, subject: subject);

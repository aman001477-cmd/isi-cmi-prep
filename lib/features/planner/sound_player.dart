import 'dart:typed_data';

import 'sound_player_android.dart'
    if (dart.library.html) 'sound_player_web.dart' as impl;

/// Plays one of the bundled alarm sounds (assets/sounds/<id>.wav) once.
/// On desktop/VM builds this is a no-op stub; on web it uses
/// [HtmlAudioElement] so the sound works without any package.
void playSound(String id) => impl.playSoundImpl(id);

/// Starts the sound looping until [stopSound] is called — used while a
/// task alarm is ringing (the "ring until dismissed" behaviour).
void playLoop(String id) => impl.playLoopImpl(id);

/// Stops any looping alarm sound immediately.
void stopSound() => impl.stopSoundImpl();

/// Plays [id] looping for [seconds], then stops on its own — used for
/// the timer's completion ring. Always audible, even in focus mode.
void playBounded(String id, int seconds) =>
    impl.playBoundedImpl(id, seconds);

/// Focus-mode lock: while ON, looping alarm rings (planner alarms)
/// stay silent — the app acts like Do-Not-Disturb. Single preview
/// sounds still play so the timer's "time's up" chime is always heard.
void setFocusLock(bool on) => impl.setFocusLockImpl(on);

/// Installs a user-picked alarm sound. Passing null reverts to the
/// bundled chime. The special sound id "custom" then plays these bytes.
void setCustomAudio(Uint8List? bytes, String ext) =>
    impl.setCustomAudioImpl(bytes, ext);
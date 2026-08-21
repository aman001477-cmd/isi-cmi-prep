/// Desktop/VM default: no audio output available without a plugin,
/// so these are intentionally no-ops (test runs and local builds stay quiet).
void playSoundImpl(String id) {}

void playLoopImpl(String id) {}

void stopSoundImpl() {}

void playBoundedImpl(String id, int seconds) {
  // no-op — no audio on desktop/VM
}

void setFocusLockImpl(bool on) {
  // no-op — focus lock is a web-only behaviour
}
/// Which experience the shell locked onto for this install.
///
/// - [webContent] → returning user was previously routed to the WebView.
/// - [nativeGame] → returning user was previously routed to the game.
/// - [undecided]  → first launch, gate has not answered yet.
enum PitchMode {
  webContent,
  nativeGame,
  undecided;

  static PitchMode fromToken(String? raw) {
    switch (raw) {
      case 'web':
        return PitchMode.webContent;
      case 'native':
        return PitchMode.nativeGame;
      default:
        return PitchMode.undecided;
    }
  }

  String toToken() {
    switch (this) {
      case PitchMode.webContent:
        return 'web';
      case PitchMode.nativeGame:
        return 'native';
      case PitchMode.undecided:
        return 'unset';
    }
  }
}

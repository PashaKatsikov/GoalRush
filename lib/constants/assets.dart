/// Central place for every asset path used across the app so that a typo
/// only ever has to be fixed in one spot.
class AppAssets {
  AppAssets._();

  static const String _additional = 'assets/Goal_Rush_additional_assets';
  static const String _gameplay = 'assets/Goal_Rush_gameplay_assets';

  static const String logo = '$_additional/Game_Name.webp';
  static const String icon = '$_additional/Icon.png';
  static const String verticalLoading = '$_additional/Vertical_Loading_Screen.webp';
  static const String horizontalLoading = '$_additional/Horizontal_Loading_Screen.webp';
  static const String verticalNoWifi = '$_additional/Vertical_Nowifi_Screen.webp';
  static const String horizontalNoWifi = '$_additional/Horizontal_Nowifi_Screen.webp';

  static const String goldenQuestionMark = '$_gameplay/golden_question_mark_asset.webp';
  static const String goldenTrophy = '$_gameplay/golden_football_trophy_asset.webp';

  static const List<String> verticalFields = [
    '$_gameplay/vertic_bg1_asset.webp',
    '$_gameplay/vertic_bg2_asset.webp',
    '$_gameplay/vertic_bg3_asset.webp',
    '$_gameplay/vertic_bg4_asset.webp',
    '$_gameplay/vertic_bg5_asset.webp',
  ];

  static const List<String> fieldNames = [
    'Sunset Stadium',
    'Tropical Beach',
    'Campus Park',
    'Street Court',
    'Night Arena',
  ];

  static const List<String> goalkeepers = [
    '$_gameplay/base_goalkeeper_asset.webp',
    '$_gameplay/blue_goalkeeper_asset.webp',
    '$_gameplay/green_goalkeeper_asset.webp',
    '$_gameplay/orange_goalkeeper_asset.webp',
    '$_gameplay/white_goalkeeper_asset.webp',
  ];

  static const List<String> goalkeeperNames = [
    'Classic Keeper',
    'Blue Keeper',
    'Green Keeper',
    'Orange Keeper',
    'White Keeper',
  ];

  static const List<String> goalposts = [
    '$_gameplay/white_football_goalposts_asset.webp',
    '$_gameplay/blue_football_goalposts_asset.webp',
    '$_gameplay/green_football_goalposts_asset.webp',
    '$_gameplay/red_football_goalposts_asset.webp',
    '$_gameplay/yellow_football_goalposts_asset.webp',
  ];

  static const List<String> goalpostNames = [
    'White Goal',
    'Blue Goal',
    'Green Goal',
    'Red Goal',
    'Yellow Goal',
  ];

  static const List<String> balls = [
    '$_gameplay/soccer_ball_asset.webp',
    '$_gameplay/golden_soccer_ball_asset.webp',
    '$_gameplay/futuristic_soccer_ball_asset.webp',
    '$_gameplay/championship_soccer_asset.webp',
    '$_gameplay/training_soccer_ball_asset.webp',
  ];

  static const List<String> ballNames = [
    'Classic Ball',
    'Golden Ball',
    'Futuristic Ball',
    'Championship Ball',
    'Training Ball',
  ];
}

/// Создаёт icon2_foreground.png — версию icon2.png,
/// вписанную в центральные 66.7% холста 1024×1024.
/// Это соответствует safe-zone адаптивной Android-иконки (72/108 dp),
/// то есть содержимое гарантированно не будет обрезано лончером.
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const String srcPath = 'assets/gr_stadium_backdrops_v2/icon2.png';
  const String dstPath = 'assets/gr_stadium_backdrops_v2/icon2_foreground.png';

  // Читаем источник
  final srcBytes = File(srcPath).readAsBytesSync();
  final src = img.decodePng(srcBytes);
  if (src == null) {
    stderr.writeln('Не удалось декодировать $srcPath');
    exit(1);
  }

  // Safe-zone: центральные 66.67% холста (72/108 dp).
  // Используем 66% чтобы иметь крошечный запас.
  const int canvasSize = 1024;
  const double safeFraction = 0.667;
  final int iconSize = (canvasSize * safeFraction).round(); // 683 px
  final int offset = ((canvasSize - iconSize) / 2).round(); // 170 px с каждой стороны

  // Масштабируем иконку до iconSize×iconSize
  final resized = img.copyResize(
    src,
    width: iconSize,
    height: iconSize,
    interpolation: img.Interpolation.cubic,
  );

  // Прозрачный холст 1024×1024
  final canvas = img.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  // Вставляем иконку по центру
  img.compositeImage(canvas, resized, dstX: offset, dstY: offset);

  // Сохраняем
  File(dstPath).writeAsBytesSync(img.encodePng(canvas));
  print('✓ Создан $dstPath');
  print('  Холст: ${canvasSize}×${canvasSize} px');
  print('  Иконка: ${iconSize}×${iconSize} px (offset: $offset px)');
  print('  Safe-zone: ${(safeFraction * 100).toStringAsFixed(1)}% — обрезки нет.');
}

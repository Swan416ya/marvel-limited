import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 设备端 OCR（ML Kit，拉丁字母）。
///
/// 只认文字、不上传图片；识别结果按阅读顺序（上到下）拼成一段文本，
/// 交给 [TranslateService] 翻译。Web / 测试环境没有 ML Kit，
/// 会抛一个带说明的异常（调用方 SnackBar 提示）。
abstract final class OcrService {
  static TextRecognizer? _recognizer;

  static Future<String> recognize(File image) async {
    if (kIsWeb) {
      throw UnsupportedError('Web 预览不支持 OCR，请使用 Android 版');
    }
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    final input = InputImage.fromFilePath(image.path);
    final result = await _recognizer!.processImage(input);
    // 按 block → line 的顺序拼；块之间空一行（大致对应分镜）
    final blocks = <String>[];
    for (final block in result.blocks) {
      final lines = block.lines
          .map((l) => l.text.trim())
          .where((t) => t.isNotEmpty);
      if (lines.isEmpty) continue;
      blocks.add(lines.join('\n'));
    }
    return blocks.join('\n\n');
  }
}

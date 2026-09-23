import 'dart:convert';

import 'package:http/http.dart' as http;

/// 漫画页翻译：设备端 OCR（ML Kit）→ 大语言模型翻译（OpenAI 兼容接口）。
///
/// 配置由用户在阅读器里长按「翻译」填入（接口地址 / API Key / 模型名），
/// 存在 PreferencesRepository。接口走 OpenAI 兼容的
/// `POST {baseUrl}/chat/completions`——OpenAI、DeepSeek、Gemini 的
/// OpenAI 兼容层、各种中转都能接。
class TranslateService {
  TranslateService({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       // 自己创建的客户端用完要关；外部注入的不关（调用方负责）
       _createdClient = client == null;

  /// 接口基地址，如 `https://api.openai.com/v1`。
  final String baseUrl;

  final String apiKey;

  /// 模型名，如 `gpt-4o-mini` / `deepseek-chat`。
  final String model;

  final http.Client _client;

  final bool _createdClient;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  /// 翻译一页的 OCR 文本。
  ///
  /// [context] 是前几页的文本，让模型带着上下文翻（人称、伏笔、
  /// 称呼都能对上）；[seriesTitle] 用于把这一期的背景塞进提示词。
  Future<String> translate(
    String ocrText, {
    String? context,
    String? seriesTitle,
  }) async {
    if (!isConfigured) {
      throw StateError('还没有配置翻译模型：长按「翻译」按钮填写接口信息');
    }
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions',
    );
    // 阅读器里点一次翻译 new 一个 service：自己创建的连接用完就关，
    // 不关的话每次翻译漏一条 keep-alive 连接。
    try {
      return await _postAndParse(
        uri,
        ocrText: ocrText,
        context: context,
        seriesTitle: seriesTitle,
      );
    } finally {
      if (_createdClient) _client.close();
    }
  }

  Future<String> _postAndParse(
    Uri uri, {
    required String ocrText,
    String? context,
    String? seriesTitle,
  }) async {
    final resp = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'temperature': 0.3,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {
            'role': 'user',
            'content': _buildUserPrompt(
              ocrText,
              context: context,
              seriesTitle: seriesTitle,
            ),
          },
        ],
      }),
    );
    if (resp.statusCode != 200) {
      final detail = utf8.decode(resp.bodyBytes);
      throw Exception(
        '翻译接口返回 ${resp.statusCode}：'
        '${detail.substring(0, detail.length.clamp(0, 200))}',
      );
    }
    final body = json.decode(utf8.decode(resp.bodyBytes)) as Map;
    final choices = body['choices'] as List?;
    final first = (choices == null || choices.isEmpty)
        ? null
        : choices.first as Map?;
    final content = (first?['message'] as Map?)?['content'];
    if (content == null || content.toString().isEmpty) {
      throw Exception('翻译接口没有返回内容');
    }
    return content.toString();
  }

  // ── 提示词 ────────────────────────────────────────────────────
  //
  // 设计要点（对着常见翻车点写的）：
  // 1. 角色名/代号/地名必须用大陆通行译名，且前后一致（这一页叫
  //    「毁灭博士」下一页不能变「末日博士」）；
  // 2. 大事件名按固定译名表（下面的小词表覆盖最高频的），
  //    词表外的按通行译名并在第一次出现时括注原文；
  // 3. 保留分镜/气泡的顺序和分段——读者要对着画面找台词；
  // 4. 拟声词翻译成中文拟声（轰！咔嚓！），别删掉；
  // 5. 有上下文时参考上下文理解指代（他/它/那个东西指谁）。

  static const _systemPrompt = '''
你是专业的美漫汉化译者，把漫画页 OCR 出来的英文台词翻译成简体中文。

规则：
1. 只输出译文，不要解释、不要加注音。按 OCR 给出的行序逐行翻译，每行译文单独一行，行与行不要合并。
2. 人名、代号、团队、地名用大陆通行译名，全篇保持一致。参考译名表：
   Spider-Man=蜘蛛侠，Peter Parker=彼得·帕克，Iron Man=钢铁侠，Tony Stark=托尼·斯塔克，
   Captain America=美国队长，Steve Rogers=史蒂夫·罗杰斯，Thor=雷神，Loki=洛基，
   Hulk=浩克，Bruce Banner=布鲁斯·班纳，Black Widow=黑寡妇，Hawkeye=鹰眼，
   Doctor Strange=奇异博士，Doctor Doom=毁灭博士，Reed Richards=里德·理查兹，
   Mister Fantastic=神奇先生，Invisible Woman=隐形女，Human Torch=霹雳火，The Thing=石头人，
   Wolverine=金刚狼，Cyclops=镭射眼，Jean Grey=琴·格雷，Storm=暴风女，Professor X=X教授，
   Magneto=万磁王，Deadpool=死侍，Venom=毒液，Daredevil=夜魔侠，Punisher=惩罚者，
   Avengers=复仇者，X-Men=X战警，Fantastic Four=神奇四侠，Guardians of the Galaxy=银河护卫队，
   SHIELD=神盾局，Asgard=阿斯加德，Latveria=拉托维尼亚，Wakanda=瓦坎达。
   表外角色按通行译名；拿不准时保留英文原名。
3. 大事件名固定译名：Secret Wars=秘密战争，Civil War=内战，Infinity Gauntlet=无限手套，
   Age of Apocalypse=天启时代，House of M=M氏家族，Secret Invasion=秘密入侵，
   Avengers vs. X-Men=复仇者大战X战警，Secret Empire=秘密帝国，War of the Realms=诸界之战，
   King in Black=黑衣之王，Blood Hunt=血猎，One World Under Doom=毁灭统治世界。
4. 拟声词翻成中文拟声并保留（KRAKOOM=轰隆！，SNIKT=铿！，THWIP=嗖！）。
5. 语气要像漫画台词：短促、口语化，符合说话者身份（老者古板、少年轻佻、反派狂妄）。
6. OCR 文本可能有识别错误：明显乱码忽略；能根据漫画语境推断的正确拼写直接按正确的翻。
''';

  String _buildUserPrompt(
    String ocrText, {
    String? context,
    String? seriesTitle,
  }) {
    final buf = StringBuffer();
    if (seriesTitle != null && seriesTitle.isNotEmpty) {
      buf.writeln('本漫画系列：$seriesTitle。');
    }
    if (context != null && context.trim().isNotEmpty) {
      buf.writeln('——前文（供理解指代，不要翻译它）——');
      buf.writeln(context.trim());
      buf.writeln('——前文结束——');
    }
    buf.writeln('翻译下面这一页的台词：');
    buf.writeln(ocrText.trim());
    return buf.toString();
  }
}

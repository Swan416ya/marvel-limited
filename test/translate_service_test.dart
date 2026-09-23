import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:marvel_limited/data/translate_service.dart';

void main() {
  test('未配置时直接抛错，不发请求', () async {
    final service = TranslateService(baseUrl: '', apiKey: '', model: '');
    expect(service.isConfigured, isFalse);
    expect(
      () => service.translate('hello'),
      throwsStateError,
    );
  });

  test('请求打到 {baseUrl}/chat/completions，带系统提示词与上下文', () async {
    Map<String, dynamic>? capturedBody;
    Uri? capturedUri;
    final client = MockClient((req) async {
      capturedUri = req.url;
      capturedBody = json.decode(utf8.decode(req.bodyBytes));
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': '第一行\n第二行',
              }
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = TranslateService(
      baseUrl: 'https://api.example.com/v1/',
      apiKey: 'sk-test',
      model: 'gpt-4o-mini',
      client: client,
    );

    final out = await service.translate(
      'PETER: With great power...',
      context: 'previous page text',
      seriesTitle: 'Amazing Spider-Man',
    );

    expect(out, '第一行\n第二行');
    expect(capturedUri.toString(), 'https://api.example.com/v1/chat/completions');
    final body = capturedBody!;
    expect(body['model'], 'gpt-4o-mini');
    final messages = body['messages'] as List;
    expect(messages, hasLength(2));
    expect((messages[0] as Map)['role'], 'system');
    // 译名表必须在系统提示词里（角色名 + 大事件名）
    final system = (messages[0] as Map)['content'].toString();
    expect(system, contains('蜘蛛侠'));
    expect(system, contains('毁灭博士'));
    expect(system, contains('秘密战争'));
    expect(system, contains('拟声词'));
    // 用户消息里带上了上下文与系列名
    final user = (messages[1] as Map)['content'].toString();
    expect(user, contains('previous page text'));
    expect(user, contains('Amazing Spider-Man'));
    expect(user, contains('PETER: With great power...'));
    // 上下文明确标注「不要翻译」
    expect(user, contains('不要翻译'));
  });

  test('接口报错时抛出带状态码的异常', () async {
    final client = MockClient((req) async => http.Response('{"error":"bad"}', 401));
    final service = TranslateService(
      baseUrl: 'https://api.example.com/v1',
      apiKey: 'k',
      model: 'm',
      client: client,
    );
    expect(
      () => service.translate('hi'),
      throwsA(isA<Exception>().having(
        (e) => e.toString(),
        'message',
        contains('401'),
      )),
    );
  });

  test('返回空内容时抛错', () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode({'choices': []}), 200,
        headers: {'content-type': 'application/json'}));
    final service = TranslateService(
      baseUrl: 'https://api.example.com/v1',
      apiKey: 'k',
      model: 'm',
      client: client,
    );
    expect(() => service.translate('hi'), throwsException);
  });
}

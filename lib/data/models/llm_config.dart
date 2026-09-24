/// 翻译模型配置（阅读器里长按「翻译」进入填写）。
///
/// 接口地址 / API Key / 模型名总是成组出现、成组持久化，
/// 打成一个类型，省得各处三个字段一起传。
class LlmConfig {
  const LlmConfig({this.baseUrl = '', this.apiKey = '', this.model = ''});

  /// 接口基地址，如 `https://api.openai.com/v1`。
  final String baseUrl;

  final String apiKey;

  /// 模型名，如 `gpt-4o-mini` / `deepseek-chat`。
  final String model;

  /// 三项都填了才算配置完成（保存时已 trim 过）。
  bool get isConfigured =>
      baseUrl.isNotEmpty && apiKey.isNotEmpty && model.isNotEmpty;
}

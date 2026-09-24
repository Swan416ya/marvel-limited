import 'package:shared_preferences/shared_preferences.dart';

import '../../models/llm_config.dart';
import 'prefs_storage.dart';

/// 翻译模型配置域（阅读器里长按「翻译」进入填写）。
/// 仅 `PreferencesRepository.load()` 负责调用 `loadLlmConfig`。
mixin LlmPrefs {
  PrefsStorage get storage;

  static const _keyLlmBaseUrl = 'llm_base_url_v1';
  static const _keyLlmApiKey = 'llm_api_key_v1';
  static const _keyLlmModel = 'llm_model_v1';

  LlmConfig _llmConfig = const LlmConfig();

  void loadLlmConfig(SharedPreferences prefs) {
    _llmConfig = LlmConfig(
      baseUrl: prefs.getString(_keyLlmBaseUrl) ?? '',
      apiKey: prefs.getString(_keyLlmApiKey) ?? '',
      model: prefs.getString(_keyLlmModel) ?? '',
    );
  }

  LlmConfig get llmConfig => _llmConfig;

  Future<void> saveLlmConfig(LlmConfig config) async {
    _llmConfig = LlmConfig(
      baseUrl: config.baseUrl.trim(),
      apiKey: config.apiKey.trim(),
      model: config.model.trim(),
    );
    await storage.instance?.setString(_keyLlmBaseUrl, _llmConfig.baseUrl);
    await storage.instance?.setString(_keyLlmApiKey, _llmConfig.apiKey);
    await storage.instance?.setString(_keyLlmModel, _llmConfig.model);
  }
}

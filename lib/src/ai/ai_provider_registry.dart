import '../models.dart';
import 'ai_provider.dart';
import 'claude_provider.dart';
import 'gemini_provider.dart';
import 'openai_provider.dart';

class AiProviderRegistry {
  AiProviderRegistry._();

  static final List<AiProvider> _all = <AiProvider>[
    OpenAiProvider(),
    GeminiProvider(),
    ClaudeProvider(),
  ];

  static List<AiProvider> get all => List<AiProvider>.unmodifiable(_all);

  static AiProvider? byId(String id) {
    for (final AiProvider provider in _all) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  static List<AiProvider> configured(ConnectorConfig config) {
    return _all.where((AiProvider p) => p.isConfigured(config)).toList();
  }
}

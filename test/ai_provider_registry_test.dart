import 'package:flutter_test/flutter_test.dart';

import 'package:engitrack/src/ai/ai_provider_registry.dart';
import 'package:engitrack/src/models.dart';

void main() {
  group('AiProviderRegistry', () {
    test('all returns all four providers', () {
      final all = AiProviderRegistry.all;
      expect(all, hasLength(4));
      final ids = all.map((p) => p.id).toSet();
      expect(ids, containsAll(['openai', 'gemini', 'claude', 'grok']));
    });

    test('all list is unmodifiable', () {
      final all = AiProviderRegistry.all;
      expect(() => all.add(AiProviderRegistry.all.first), throwsA(anything));
    });

    test('byId returns correct provider', () {
      expect(AiProviderRegistry.byId('openai')?.id, 'openai');
      expect(AiProviderRegistry.byId('gemini')?.id, 'gemini');
      expect(AiProviderRegistry.byId('claude')?.id, 'claude');
      expect(AiProviderRegistry.byId('grok')?.id, 'grok');
    });

    test('byId returns null for unknown id', () {
      expect(AiProviderRegistry.byId('nonexistent'), isNull);
      expect(AiProviderRegistry.byId(''), isNull);
    });

    test('configured returns only configured providers', () {
      const config = ConnectorConfig(
        openAiEnabled: true,
        openAiApiKey: 'sk-key',
        geminiEnabled: false,
        claudeEnabled: true,
        claudeApiKey: 'cl-key',
        grokEnabled: false,
      );

      final configured = AiProviderRegistry.configured(config);
      final ids = configured.map((p) => p.id).toSet();
      expect(ids, contains('openai'));
      expect(ids, contains('claude'));
      expect(ids, isNot(contains('gemini')));
      expect(ids, isNot(contains('grok')));
    });

    test('configured returns empty when nothing configured', () {
      const config = ConnectorConfig();
      final configured = AiProviderRegistry.configured(config);
      expect(configured, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_jules/services/prompt_template_provider.dart';

void main() {
  group('PromptTemplateProvider', () {
    late PromptTemplateProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = PromptTemplateProvider();
    });

    test('Initializes with built-in templates', () async {
      await provider.init();
      expect(provider.availableBuiltInTemplates, isNotEmpty);
      expect(provider.customTemplates, isEmpty);
      expect(provider.recentPrompts, isEmpty);
    });

    test('Adds and deletes custom template', () async {
      await provider.init();
      await provider.addCustomTemplate('My Template', 'Content');

      expect(provider.customTemplates.length, 1);
      expect(provider.customTemplates.first.name, 'My Template');

      final id = provider.customTemplates.first.id;
      await provider.deleteCustomTemplate(id);

      expect(provider.customTemplates, isEmpty);
    });

    test('Updates custom template', () async {
      await provider.init();
      await provider.addCustomTemplate('Original', 'Content');
      final id = provider.customTemplates.first.id;

      await provider.updateCustomTemplate(id, 'Updated', 'New Content');

      expect(provider.customTemplates.first.name, 'Updated');
      expect(provider.customTemplates.first.content, 'New Content');
    });

    test('Manages recent prompts limit', () async {
      await provider.init();

      for (int i = 0; i < 15; i++) {
        await provider.addRecentPrompt('Prompt $i');
      }

      expect(provider.recentPrompts.length, 10);
      expect(provider.recentPrompts.first.content, 'Prompt 14'); // Most recent
    });

    test('Deduplicates recent prompts', () async {
      await provider.init();
      await provider.addRecentPrompt('Hello');
      await provider.addRecentPrompt('World');
      await provider.addRecentPrompt('Hello');

      expect(provider.recentPrompts.length, 2);
      expect(provider.recentPrompts.first.content, 'Hello');
    });

    test('Toggles built-in templates', () async {
      await provider.init();
      final template = provider.availableBuiltInTemplates.first;

      await provider.toggleBuiltIn(template.id, false);
      expect(provider.isBuiltInDisabled(template.id), true);
      expect(provider.availableBuiltInTemplates.contains(template), false);

      await provider.toggleBuiltIn(template.id, true);
      expect(provider.isBuiltInDisabled(template.id), false);
      expect(provider.availableBuiltInTemplates.any((t) => t.id == template.id), true);
    });
  });
}

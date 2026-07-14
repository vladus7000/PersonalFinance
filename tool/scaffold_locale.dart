// Scaffolds a new locale file for a translator, ready to hand off.
//
// Usage: dart run tool/scaffold_locale.dart <locale_code>
// Example: dart run tool/scaffold_locale.dart pt
//
// Copies every translatable key from the template (app_en.arb) into
// lib/core/l10n/app_<locale>.arb, with English text as a starting point.
// This keeps the file always valid JSON with every required key present —
// a translator only needs to overwrite string values, never touch keys or
// add/remove entries. See lib/core/l10n/TRANSLATING.md for what to send them.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/scaffold_locale.dart <locale_code>');
    exit(1);
  }

  final locale = args.first;
  final templateFile = File('lib/core/l10n/app_en.arb');
  final targetFile = File('lib/core/l10n/app_$locale.arb');

  if (!templateFile.existsSync()) {
    stderr.writeln('Template not found: ${templateFile.path}');
    exit(1);
  }
  if (targetFile.existsSync()) {
    stderr.writeln('${targetFile.path} already exists — aborting, not overwriting.');
    exit(1);
  }

  final template = jsonDecode(templateFile.readAsStringSync()) as Map<String, dynamic>;

  // Only translatable keys survive: drop the template's own @@locale and
  // every @key metadata block (descriptions are for the template only —
  // gen-l10n reads them from app_en.arb regardless of which locale file a
  // translator is working from).
  final output = <String, dynamic>{'@@locale': locale};
  for (final entry in template.entries) {
    if (entry.key == '@@locale' || entry.key.startsWith('@')) continue;
    output[entry.key] = entry.value;
  }

  const encoder = JsonEncoder.withIndent('  ');
  targetFile.writeAsStringSync('${encoder.convert(output)}\n');

  stdout.writeln('Created ${targetFile.path} with ${output.length - 1} keys.');
  stdout.writeln('Every value is still English — send this file, plus');
  stdout.writeln('lib/core/l10n/TRANSLATING.md, to the translator.');
}

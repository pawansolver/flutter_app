import 'dart:io';

void main() {
  final dir = Directory('lib/modules');
  if (!dir.existsSync()) return;
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    bool changed = false;

    // Scaffold Backgrounds
    final scaffoldMatch = RegExp(r'backgroundColor:\s*(const Color\(0xFFF9FAFB\)|Colors\.white),');
    if (scaffoldMatch.hasMatch(content) && content.contains('Scaffold(')) {
      content = content.replaceAll('backgroundColor: const Color(0xFFF9FAFB),', 'backgroundColor: const Color(0xFFE1EAE4),');
      // Careful with replacing all Colors.white, let's just do it manually for scaffold if we can.
      // But it's simpler to just do:
      changed = true;
    }
    
    // AppBar Backgrounds
    if (content.contains('AppBar(')) {
      content = content.replaceAll('backgroundColor: Colors.white,', 'backgroundColor: Colors.transparent,');
      changed = true;
    }
    
    // Default Icon colors inside app bars (black/grey to dark grey)
    if (content.contains('IconThemeData(color: Color(0xFF111827))')) {
      // already good
    }

    if (changed) {
      file.writeAsStringSync(content);
      print('Updated: ${file.path}');
    }
  }
}

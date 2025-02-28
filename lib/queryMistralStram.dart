import 'dart:convert';
import 'package:http/http.dart' as http;

final client = http.Client();

Future<void> queryMistralStream({
  required String prompt,
  required Function(String) onTextUpdate,
  required Function() onComplete,
}) async {
  final url = Uri.parse('your Mistral API URL');

  final request = http.Request("POST", url)
    ..headers['Content-Type'] = 'application/json'
    ..body = jsonEncode({
      'model': 'mistral',
      'messages': [{'role': 'user', 'content': prompt}],
    });

  try {
    final response = await client.send(request);

    response.stream.transform(utf8.decoder).listen((chunk) {
      final lines = chunk.trim().split("\n");
      for (var line in lines) {
        if (line.isNotEmpty) {
          try {
            final jsonData = jsonDecode(line);

            final newText = jsonData['message']?['content'] ?? jsonData['response'] ?? '';
            onTextUpdate(newText);
          } catch (e) {
            print('Error parsing chunk: $e');
          }
        }
      }
    }, onDone: onComplete);
  } catch (e) {
    print('Error sending request: $e');
  }
}

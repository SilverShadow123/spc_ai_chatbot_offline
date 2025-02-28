import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:process_run/process_run.dart';
import 'package:ollama_chatbot/queryMistralStram.dart';

void main() {
  runApp(MyApp());
  startOllamaServe();
}

Future<void> startOllamaServe() async {
  try {
    final result = await runExecutableArguments(
      'ollama',
      ['serve'],
    );

    print('Ollama server started: ${result.stdout}');
  } catch (e) {
    print('Error starting Ollama server: $e');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  List<Map<String, String>> messages = [];
  bool isLoading = false;
  String currentStreamingResponse = '';
  String userName = '';
  String aiName = 'AI';

  @override
  void initState() {
    super.initState();
    loadMemory();
  }

  Future<void> loadMemory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? '';
      aiName = prefs.getString('aiName') ?? 'AI';
    });
  }

  Future<void> saveMemory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', userName);
    await prefs.setString('aiName', aiName);
  }

  void handleStreamingUpdate(String text) {
    setState(() {
      currentStreamingResponse += text;
    });
  }

  void handleStreamingComplete() {
    setState(() {
      messages.add({'role': 'ai', 'text': currentStreamingResponse});
      currentStreamingResponse = '';
      isLoading = false;
    });
    saveMemory();
  }

  Future<void> sendMessage() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'text': prompt});
      isLoading = true;
      currentStreamingResponse = '';
    });

    _controller.clear();

    String fullPrompt = 'User name: $userName. AI name: $aiName. $prompt';

    await queryMistralStream(
      prompt: fullPrompt,
      onTextUpdate: handleStreamingUpdate,
      onComplete: handleStreamingComplete,
    );
  }

  void handleRememberCommand(String command) {
    if (command.contains('my name is')) {
      final name = command.split('my name is ')[1];
      setState(() {
        userName = name;
      });
      saveMemory();
      sendMessage();
    } else if (command.contains('your name is')) {
      final aiNewName = command.split('your name is ')[1];
      setState(() {
        aiName = aiNewName;
      });
      saveMemory();
      sendMessage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[800],
      appBar: AppBar(
        title: Text(
          'SPC (Seaum Personal ChatBot)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.grey[800],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: messages.length +
                  (currentStreamingResponse.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                bool isStreaming = index == messages.length;
                final msg = isStreaming
                    ? {'role': 'ai', 'text': currentStreamingResponse}
                    : messages[index];

                bool isUser = msg['role'] == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.grey[500] : Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      msg['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isLoading) CircularProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(10),
                      filled: true,
                      fillColor: Colors.grey[600],
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey,
                        ),
                      ),
                      hintText: 'Enter your message...',
                      hintStyle: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    onSubmitted: (value) {
                      handleRememberCommand(value);
                      if (value.isNotEmpty) {
                        sendMessage();
                      }
                    },
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: Colors.white,
                  ),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

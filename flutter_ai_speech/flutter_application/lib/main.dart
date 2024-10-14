import 'package:RAILCOMS.AI/splash.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const MyApp());
}

dynamic initialMessage = "";
final dio = Dio();

void getHttp() async {
  final response = await dio.get(
      'https://p2k.stekom.ac.id/ensiklopedia/Persinyalan_dan_semboyan_kereta_api_di_Indonesia');
  initialMessage = response;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Railcoms.AI',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Splash());
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  late FlutterTts _flutterTts;
  bool _isSending = false;
  late GenerativeModel _model;
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage('id-ID');
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('api_key') ?? '';
    });

    if (_apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );
    }
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    _loadKeys();
  }

  void _listen() async {
    if (!_isListening) {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _controller.text = val.recognizedWords;
          });
        });
      } else {
        setState(() {
          _controller.text = 'Speech recognition not available';
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _speak(String message) async {
    await _flutterTts.setLanguage('id-ID');
    await _flutterTts.speak(message);
  }

  Future<void> _sendToGeminiAPI(String message) async {
    if (_apiKey.isEmpty) {
      setState(() {
        _messages.add(Message(
            text: 'Error: API Key is missing. Please set it in settings.',
            isUser: false));
      });
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      getHttp();
      String infoMessage = initialMessage.toString();
      String systemMessage =
          'Anda adalah asisten pribadi yang bernama Railcoms.AI yang bisa membantu, menjelaskan serta menjawab seputar semboyan kereta api.\nInfo: $infoMessage . noted : jangan kembalikan dalam format markdown';

      final String fullMessage = '$systemMessage\n\nPengguna: $message';

      final response =
          await _model.generateContent([Content.text(fullMessage)]);
      final responseText =
          response?.text?.replaceAll("*", "") ?? 'Tidak ada respon';

      setState(() {
        _messages.add(Message(text: responseText, isUser: false));
      });

      await _speak(responseText);
    } catch (error) {
      setState(() {
        _messages.add(Message(
            text: 'Error: Gagal terhubung ke Google Gemini API: $error',
            isUser: false));
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _sendMessage() {
    if (_controller.text.isEmpty || _isSending) return;
    setState(() {
      _messages.add(Message(text: _controller.text, isUser: true));
    });

    _sendToGeminiAPI(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  SizedBox(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                Image.asset("assets/train.png",width: 40,),
                SizedBox(width: 10,),
                Text(
                  'RAILCOMS.AI',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8.0),
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  onPressed: _listen,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration:
                        const InputDecoration(hintText: "Type a message"),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Message {
  final String text;
  final bool isUser;

  Message({required this.text, required this.isUser});
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKeyController.text = prefs.getString('api_key') ?? '';
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', _apiKeyController.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(labelText: 'API Key'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

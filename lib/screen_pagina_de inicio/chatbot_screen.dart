// lib/chatbot_screen/chatbot_screen.dart
import 'package:flutter/material.dart';
import 'package:dialog_flowtter/dialog_flowtter.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  late DialogFlowtter dialogFlowtter;

  @override
  void initState() {
    super.initState();
    // Inicializa Dialogflow
    DialogFlowtter.fromFile(path: 'assets/newagent-jdqb-4ffe669af65e.json')
        .then((instance) => dialogFlowtter = instance);
  }

  void _sendMessage() async {
    final text = _messageController.text;
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'message': text, 'isUser': true});
    });
    _messageController.clear();

    try {
      // Enviar mensaje a Dialogflow
      DetectIntentResponse response = await dialogFlowtter.detectIntent(
        queryInput: QueryInput(text: TextInput(text: text)),
      );

      // Imprimir la respuesta para depuración
      print(response.toJson());

      // Verificar si hay mensajes de cumplimiento
      if (response.queryResult?.fulfillmentMessages?.isNotEmpty ?? false) {
        final fulfillmentMessage = response.queryResult!.fulfillmentMessages!.first;
        if (fulfillmentMessage.text?.text?.isNotEmpty ?? false) {
          setState(() {
            _messages.add({
              'message': fulfillmentMessage.text!.text!.first,
              'isUser': false,
            });
          });
        } else {
          setState(() {
            _messages.add({
              'message': 'No se recibió una respuesta de texto válida.',
              'isUser': false,
            });
          });
        }
      } else {
        setState(() {
          _messages.add({
            'message': 'No se recibió ninguna respuesta de Dialogflow.',
            'isUser': false,
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'message': 'Error al comunicarse con Dialogflow: $e',
          'isUser': false,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ecobot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.blue.shade700,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[_messages.length - 1 - index];
                  return Align(
                    alignment: message['isUser'] ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message['isUser'] ? Colors.blue.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        message['message'],
                        style: TextStyle(
                          color: message['isUser'] ? Colors.blue.shade900 : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Escribe tu mensaje...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FloatingActionButton(
                    onPressed: _sendMessage,
                    backgroundColor: Colors.blue.shade600,
                    mini: true,
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    dialogFlowtter.dispose();
    super.dispose();
  }
}
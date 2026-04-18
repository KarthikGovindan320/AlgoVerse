import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Roles for AI Tutor chat messages.
enum ChatRole { user, model }

/// A single chat message (local model — not a Firestore doc).
class ChatMessage {
  final ChatRole role;
  final String text;
  final MessageType type;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.text,
    this.type = MessageType.standard,
    required this.timestamp,
  });

  ChatMessage copyWith({String? text}) => ChatMessage(
        role: role,
        text: text ?? this.text,
        type: type,
        timestamp: timestamp,
      );
}

enum MessageType {
  standard,
  socratic,   // guiding question from AI
  hint,        // hint ladder message
  eli5,        // simple explanation
  evaluate,    // approach evaluation
  system,      // LeetCode sync event (centered, no bubble)
  codeReview,  // code review response
}

class GeminiService {
  static const _model = 'gemini-1.5-flash';

  GenerativeModel? _generativeModel;
  ChatSession? _chat;

  String _buildSystemPrompt({
    required String problemTitle,
    required String? problemStatement,
    required List<String> conceptTags,
    required List<String> learntConcepts,
    required int hintsUsed,
    required int totalHints,
  }) {
    return '''You are an expert DSA tutor using Socratic method. Your job is to guide the user to understand the problem and discover the solution themselves — NEVER give away the answer directly.

Problem: $problemTitle
Tags: ${conceptTags.join(', ')}
User's learnt concepts: ${learntConcepts.join(', ')}
Hints used: $hintsUsed / $totalHints

Rules:
1. Never give the direct solution or the algorithm code.
2. Ask clarifying questions that lead the user to think.
3. Celebrate partial insights. Build on them.
4. Use analogies tailored to the user's known concepts.
5. When the user seems stuck, guide — don't lecture.
6. Keep responses concise (under 200 words unless code review).
7. Use markdown for formatting: **bold**, `inline code`, numbered lists.

${problemStatement != null ? 'Problem statement:\n${problemStatement.substring(0, problemStatement.length.clamp(0, 1500))}' : ''}''';
  }

  void initialize({
    required String problemTitle,
    required String? problemStatement,
    required List<String> conceptTags,
    required List<String> learntConcepts,
    required List<ChatMessage> history,
    int hintsUsed = 0,
    int totalHints = 3,
  }) {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _generativeModel = GenerativeModel(
      model: _model,
      apiKey: apiKey,
      systemInstruction: Content.system(_buildSystemPrompt(
        problemTitle: problemTitle,
        problemStatement: problemStatement,
        conceptTags: conceptTags,
        learntConcepts: learntConcepts,
        hintsUsed: hintsUsed,
        totalHints: totalHints,
      )),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 600,
      ),
    );

    // Convert history to Gemini Content objects
    final geminiHistory = history
        .where((m) => m.type != MessageType.system)
        .map((m) => Content(
              m.role == ChatRole.user ? 'user' : 'model',
              [TextPart(m.text)],
            ))
        .toList();

    _chat = _generativeModel!.startChat(history: geminiHistory);
  }

  /// Send a message and stream the response back token by token.
  Stream<String> sendMessage(String userMessage) async* {
    if (_chat == null) {
      yield 'Error: tutor not initialized.';
      return;
    }

    try {
      final stream = _chat!.sendMessageStream(Content.text(userMessage));
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } catch (e) {
      yield '\n\n_Error: ${e.toString().split('\n').first}_';
    }
  }

  /// Request a hint (passes explicit hint prompt).
  Stream<String> requestHint(int hintNumber) async* {
    yield* sendMessage(
      'Give me hint #$hintNumber. Keep it minimal — just enough to unblock me without spoiling the approach.',
    );
  }

  /// Request an ELI5 explanation.
  Stream<String> requestEli5() async* {
    yield* sendMessage(
      'Explain the core concept behind this problem to me like I\'m a complete beginner. Use a simple real-world analogy.',
    );
  }

  /// Evaluate the user's described approach.
  Stream<String> evaluateApproach(String approach) async* {
    yield* sendMessage(
      'Evaluate my approach: $approach\n\nTell me: (1) what\'s good about it, (2) what\'s wrong or missing, (3) one guiding question to push me further.',
    );
  }

  /// Request a code review.
  Stream<String> reviewCode(String code, String language) async* {
    yield* sendMessage(
      'Please review my $language solution:\n\n```$language\n$code\n```\n\n'
      'Analyse: time complexity, space complexity, edge cases, code style, and improvements.',
    );
  }

  void dispose() {
    _chat = null;
    _generativeModel = null;
  }
}

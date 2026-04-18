import 'dart:convert';
import 'package:http/http.dart' as http;

class LeetCodeVerificationResult {
  final bool valid;
  final int? solvedCount;
  final String? error; // 'network' | null

  const LeetCodeVerificationResult({
    required this.valid,
    this.solvedCount,
    this.error,
  });
}

class LeetCodeService {
  static const _endpoint = 'https://leetcode.com/graphql';

  Future<LeetCodeVerificationResult> verifyUsername(String username) async {
    const query = r'''
      query getUserProfile($username: String!) {
        matchedUser(username: $username) {
          username
          submitStats {
            acSubmissionNum {
              difficulty
              count
            }
          }
        }
      }
    ''';

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Referer': 'https://leetcode.com',
            },
            body: jsonEncode({
              'query': query,
              'variables': {'username': username},
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return const LeetCodeVerificationResult(valid: false, error: 'network');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final matchedUser = data['data']?['matchedUser'];

      if (matchedUser == null) {
        return const LeetCodeVerificationResult(valid: false);
      }

      final stats = matchedUser['submitStats']?['acSubmissionNum'] as List?;
      int totalSolved = 0;
      if (stats != null) {
        for (final s in stats) {
          if (s['difficulty'] == 'All') {
            totalSolved = s['count'] as int? ?? 0;
            break;
          }
        }
        // Fallback: sum Easy + Medium + Hard if 'All' not present
        if (totalSolved == 0) {
          for (final s in stats) {
            totalSolved += (s['count'] as int? ?? 0);
          }
        }
      }

      return LeetCodeVerificationResult(valid: true, solvedCount: totalSolved);
    } catch (_) {
      return const LeetCodeVerificationResult(valid: false, error: 'network');
    }
  }
}

/// Intent types for reminder creation
enum IntentType {
  timeBased,
  locationBased,
  activityBased,
  recurring,
  weatherBased,
  ambiguous,
}

/// Local parse result
class LocalParseResult {
  final Map<String, dynamic> extracted;
  final double confidence; // 0.0 to 1.0
  final bool needsGpt;
  final List<String> missingFields;
  final IntentType? intent;

  LocalParseResult({
    required this.extracted,
    required this.confidence,
    required this.needsGpt,
    required this.missingFields,
    this.intent,
  });
}

/// GPT response
class GptResponse {
  final String question;
  final String? field;
  final Map<String, dynamic>? extractedData;

  GptResponse({
    required this.question,
    this.field,
    this.extractedData,
  });
}

/// Response for session-based conversation
class ConversationResponse {
  final String responseText;
  final bool isAction;
  final Map<String, dynamic>? actionData;

  ConversationResponse({
    required this.responseText,
    required this.isAction,
    this.actionData,
  });
}

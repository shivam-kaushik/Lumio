enum BlockType {
  heading,
  text,
  task,
}

class PlanBlock {
  String id;
  BlockType type;
  String content;
  bool isChecked;
  int indentationLevel; // New field for nesting (0 = root, 1 = subtask, etc.)
  Map<String, dynamic>? metadata;

  PlanBlock({
    required this.id,
    required this.type,
    required this.content,
    this.isChecked = false,
    this.indentationLevel = 0,
    this.metadata,
  });

  factory PlanBlock.heading(String text) {
    return PlanBlock(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: BlockType.heading,
      content: text,
    );
  }

  factory PlanBlock.text(String text) {
    return PlanBlock(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: BlockType.text,
      content: text,
    );
  }

  factory PlanBlock.task(String text, {Map<String, dynamic>? metadata, int indentationLevel = 0, bool isChecked = false}) {
    return PlanBlock(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: BlockType.task,
      content: text,
      indentationLevel: indentationLevel,
      isChecked: isChecked,
      metadata: metadata,
    );
  }
}

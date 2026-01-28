class PromptTemplate {
  final String id;
  final String name;
  final String content;
  final bool isBuiltIn;

  const PromptTemplate({
    required this.id,
    required this.name,
    required this.content,
    this.isBuiltIn = false,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'content': content, 'isBuiltIn': isBuiltIn};
  }

  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    return PromptTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      content: json['content'] as String,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  PromptTemplate copyWith({
    String? id,
    String? name,
    String? content,
    bool? isBuiltIn,
  }) {
    return PromptTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }
}

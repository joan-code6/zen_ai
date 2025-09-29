class Note {
	final String id;
	final String uid;
	final String title;
	final String content;
	final List<String> keywords;
	final List<String> triggerWords;
	final DateTime createdAt;
	final DateTime updatedAt;

	const Note({
		required this.id,
		required this.uid,
		required this.title,
		required this.content,
		required this.keywords,
		required this.triggerWords,
		required this.createdAt,
		required this.updatedAt,
	});

	String get excerpt => content;

	bool get isEmpty => content.trim().isEmpty && title.trim().isEmpty;

	Note copyWith({
		String? title,
		String? content,
		List<String>? keywords,
		List<String>? triggerWords,
		DateTime? createdAt,
		DateTime? updatedAt,
	}) {
		return Note(
			id: id,
			uid: uid,
			title: title ?? this.title,
			content: content ?? this.content,
			keywords: keywords ?? List<String>.from(this.keywords),
			triggerWords: triggerWords ?? List<String>.from(this.triggerWords),
			createdAt: createdAt ?? this.createdAt,
			updatedAt: updatedAt ?? this.updatedAt,
		);
	}

	factory Note.fromJson(Map<String, dynamic> json) {
		final content = json['content']?.toString();
		final excerpt = json['excerpt']?.toString();
			final triggerWords = _parseStringList(json['triggerWords']);
			final triggerwordsLower = _parseStringList(json['triggerwords']);
			return Note(
			id: json['id']?.toString() ?? '',
			uid: json['uid']?.toString() ?? '',
			title: json['title']?.toString() ?? 'New note',
			content: content?.isNotEmpty == true
					? content!
					: (excerpt?.isNotEmpty == true ? excerpt! : ''),
			keywords: _parseStringList(json['keywords']),
				triggerWords:
						triggerWords.isNotEmpty ? triggerWords : triggerwordsLower,
			createdAt: _parseDate(json['createdAt']),
			updatedAt: _parseDate(json['updatedAt']),
		);
	}

	Map<String, dynamic> toJson() => {
				'id': id,
				'uid': uid,
				'title': title,
				'content': content,
				'excerpt': content,
				'keywords': keywords,
				'triggerWords': triggerWords,
				'triggerwords': triggerWords,
				'createdAt': createdAt.toUtc().toIso8601String(),
				'updatedAt': updatedAt.toUtc().toIso8601String(),
			};
}

List<String> _parseStringList(dynamic value) {
	if (value is List) {
		return value
				.where((element) => element != null)
				.map((element) => element.toString())
				.toList();
	}
	if (value == null) return const [];
	return [value.toString()];
}

DateTime _parseDate(dynamic value) {
	if (value == null) return DateTime.now();
	if (value is DateTime) return value;
	if (value is int) {
		return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
	}
	if (value is String && value.isNotEmpty) {
		try {
			return DateTime.parse(value).toLocal();
		} catch (_) {
			// ignore parse errors
		}
	}
	return DateTime.now();
}
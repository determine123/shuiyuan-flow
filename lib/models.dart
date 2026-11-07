class ForumCategory {
  final int id;
  final String name;
  final String color;
  const ForumCategory(this.id, this.name, this.color);
  factory ForumCategory.fromJson(Map<String, dynamic> json) => ForumCategory(
    json['id'] as int,
    json['name'] as String? ?? '未分类',
    json['color'] as String? ?? '607D8B',
  );
}

class Topic {
  final int id;
  final String title;
  final int categoryId;
  final int replies;
  final int views;
  final List<String> tags;
  const Topic({
    required this.id,
    required this.title,
    required this.categoryId,
    this.replies = 0,
    this.views = 0,
    this.tags = const [],
  });
  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    categoryId: json['category_id'] as int? ?? 0,
    replies: ((json['posts_count'] as int? ?? 1) - 1).clamp(0, 1000000),
    views: json['views'] as int? ?? 0,
    tags: (json['tags'] as List? ?? [])
        .map((e) => e is Map ? e['name'].toString() : e.toString())
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category_id': categoryId,
    'posts_count': replies + 1,
    'views': views,
    'tags': tags,
  };
}

class ForumPost {
  final int id;
  final int number;
  final String username;
  final String cooked;
  final int likes;
  const ForumPost({
    required this.id,
    required this.number,
    required this.username,
    required this.cooked,
    this.likes = 0,
  });
  factory ForumPost.fromJson(Map<String, dynamic> json) => ForumPost(
    id: json['id'] as int,
    number: json['post_number'] as int? ?? 1,
    username: json['username'] as String? ?? '匿名',
    cooked: json['cooked'] as String? ?? '',
    likes: ((json['actions_summary'] as List? ?? [])
        .whereType<Map>()
        .where((e) => e['id'] == 2)
        .map((e) => e['count'] as int? ?? 0)
        .fold<int>(0, (a, b) => a + b)),
  );
}

class TopicThread {
  final List<ForumPost> posts;
  final List<int> stream;
  const TopicThread(this.posts, this.stream);
}

class Draft {
  final String id;
  final String title;
  final String body;
  final int categoryId;
  final int? topicId;
  const Draft({
    required this.id,
    required this.title,
    required this.body,
    required this.categoryId,
    this.topicId,
  });
  factory Draft.fromJson(Map<String, dynamic> j) => Draft(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    categoryId: j['categoryId'] as int,
    topicId: j['topicId'] as int?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'categoryId': categoryId,
    'topicId': topicId,
  };
}

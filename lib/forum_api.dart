import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// 正式联调由构建配置启用；默认只使用本地演示数据。
const communityAccessEnabled = bool.fromEnvironment('COMMUNITY_ACCESS_ENABLED');
const communityOrigin = 'https://shuiyuan.sjtu.edu.cn';

class ForumException implements Exception {
  final String message;
  const ForumException(this.message);
  @override
  String toString() => message;
}

abstract class ForumRepository {
  bool get isDemo;
  Future<List<ForumCategory>> categories();
  Future<List<Topic>> topics({
    int page = 0,
    int? categoryId,
    String query = '',
  });
  Future<TopicThread> thread(int topicId);
  Future<List<ForumPost>> morePosts(int topicId, List<int> ids);
  Future<int> publish(Draft draft);
  Future<void> like(int postId);
  Future<String> currentUser();
  void close();
}

class DiscourseRepository implements ForumRepository {
  final http.Client client;
  final String apiKey;
  final String clientId;
  final Uri origin;
  DiscourseRepository({
    required this.apiKey,
    required this.clientId,
    http.Client? client,
    Uri? origin,
  }) : client = client ?? http.Client(),
       origin = origin ?? Uri.parse(communityOrigin);
  @override
  bool get isDemo => false;

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, String>? query,
    Map<String, String>? body,
  }) async {
    final uri = origin.resolve(path).replace(queryParameters: query);
    final headers = {
      'Accept': 'application/json',
      'User-Api-Key': apiKey,
      'User-Api-Client-Id': clientId,
      'User-Agent': 'ShuiyuanFlow/0.2.0',
    };
    try {
      final request = http.Request(body == null ? 'GET' : 'POST', uri)
        ..headers.addAll(headers)
        ..followRedirects = false;
      if (body != null) request.bodyFields = body;
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(const Duration(seconds: 20));
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw const ForumException('接口要求跳转，请在浏览器检查账号或重新授权。');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ForumException('授权失效或权限不足，请检查站方配置和访问密钥。');
      }
      if (response.statusCode == 429)
        throw const ForumException('请求过于频繁，请稍后重试。');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ForumException('请求失败（HTTP ${response.statusCode}），请稍后重试。');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>)
        throw const ForumException('接口返回了不支持的数据格式。');
      if (data['errors'] is List)
        throw ForumException((data['errors'] as List).join('\n'));
      return data;
    } on TimeoutException {
      throw const ForumException('连接超时，请检查校园网或网络连接。');
    } on FormatException {
      throw const ForumException('接口未返回 JSON，可能需要重新授权。');
    } on http.ClientException {
      throw const ForumException('网络不可用，请检查连接后重试。');
    }
  }

  @override
  Future<List<ForumCategory>> categories() async {
    final j = await _request('/categories.json');
    return ((j['category_list'] as Map)['categories'] as List)
        .map((e) => ForumCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<Topic>> topics({
    int page = 0,
    int? categoryId,
    String query = '',
  }) async {
    final searching = query.trim().isNotEmpty;
    final j = await _request(
      searching
          ? '/search.json'
          : categoryId == null
          ? '/latest.json'
          : '/c/$categoryId/l/latest.json',
      query: searching
          ? {
              'q':
                  '${query.trim()}${categoryId == null ? '' : ' category:$categoryId'}',
              'page': '${page + 1}',
            }
          : {'page': '$page'},
    );
    final items = searching
        ? j['topics'] as List? ?? []
        : (j['topic_list'] as Map)['topics'] as List;
    return items
        .map((e) => Topic.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<TopicThread> thread(int topicId) async {
    final j = await _request('/t/$topicId.json');
    final stream = j['post_stream'] as Map;
    return TopicThread(
      (stream['posts'] as List)
          .map((e) => ForumPost.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      (stream['stream'] as List).cast<int>(),
    );
  }

  @override
  Future<List<ForumPost>> morePosts(int topicId, List<int> ids) async {
    final j = await _request(
      '/t/$topicId/posts.json',
      query: {for (var i = 0; i < ids.length; i++) 'post_ids[$i]': '${ids[i]}'},
    );
    return ((j['post_stream'] as Map)['posts'] as List)
        .map((e) => ForumPost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<int> publish(Draft draft) async {
    final j = await _request(
      '/posts.json',
      body: {
        'raw': draft.body,
        if (draft.topicId != null) 'topic_id': '${draft.topicId}',
        if (draft.topicId == null) ...{
          'title': draft.title,
          'category': '${draft.categoryId}',
        },
      },
    );
    return j['topic_id'] as int;
  }

  @override
  Future<void> like(int postId) async {
    await _request(
      '/post_actions.json',
      body: {'id': '$postId', 'post_action_type_id': '2'},
    );
  }

  @override
  Future<String> currentUser() async =>
      ((await _request('/session/current.json'))['current_user']
              as Map)['username']
          as String;
  @override
  void close() => client.close();
}

/// 演示内容均为虚构，不访问、缓存或镜像真实社区帖子。
class DemoRepository implements ForumRepository {
  @override
  bool get isDemo => true;
  static const demoCategories = [
    ForumCategory(1, '校园生活', '00897B'),
    ForumCategory(2, '学习交流', '3F51B5'),
    ForumCategory(3, '技术分享', '9C27B0'),
    ForumCategory(4, '站务与反馈', 'EF6C00'),
  ];
  static const demoTopics = [
    Topic(
      id: 1,
      title: '欢迎来到源流 · 让交流自然发生',
      categoryId: 4,
      replies: 2,
      views: 128,
      tags: ['使用指南'],
    ),
    Topic(
      id: 2,
      title: '秋日校园散步，你最喜欢哪条路线？',
      categoryId: 1,
      replies: 12,
      views: 368,
      tags: ['校园漫步'],
    ),
    Topic(
      id: 3,
      title: '分享我的课程笔记整理方法',
      categoryId: 2,
      replies: 8,
      views: 246,
      tags: ['学习方法'],
    ),
    Topic(
      id: 4,
      title: '用 Flutter 构建五端一致的阅读体验',
      categoryId: 3,
      replies: 6,
      views: 192,
      tags: ['Flutter', '开源'],
    ),
    Topic(
      id: 5,
      title: '一人食灵感：今天吃点什么',
      categoryId: 1,
      replies: 23,
      views: 512,
      tags: ['美食'],
    ),
    Topic(id: 6, title: '图书馆自习的专注小技巧', categoryId: 2, replies: 4, views: 168),
  ];
  @override
  Future<List<ForumCategory>> categories() async => demoCategories;
  @override
  Future<List<Topic>> topics({
    int page = 0,
    int? categoryId,
    String query = '',
  }) async => page > 0
      ? []
      : demoTopics
            .where(
              (t) =>
                  (categoryId == null || t.categoryId == categoryId) &&
                  (query.isEmpty ||
                      t.title.toLowerCase().contains(query.toLowerCase()) ||
                      t.tags.any(
                        (tag) =>
                            tag.toLowerCase().contains(query.toLowerCase()),
                      )),
            )
            .toList();
  @override
  Future<TopicThread> thread(int topicId) async => TopicThread(
    [
      ForumPost(
        id: topicId * 10,
        number: 1,
        username: '源流体验官',
        likes: 5,
        cooked:
            '<h2>${demoTopics.firstWhere((t) => t.id == topicId).title}</h2>'
            '<p>这是一篇用于测试客户端的<strong>虚构演示帖子</strong>，并非水源社区真实内容。</p>'
            '<p>在这里，你可以体验阅读、搜索、分类筛选和本地收藏。手机与桌面采用自适应布局。</p>'
            '<blockquote>让信息有序流动，让交流自然发生。</blockquote>'
            '<p>发帖和回复可以先存为本地草稿，重启应用后仍可继续编辑。</p>'
            '<p>取得社区许可并完成站方接口配置后，可在设置中连接真实社区。</p>',
      ),
      ForumPost(
        id: topicId * 10 + 1,
        number: 2,
        username: '校园漫游者',
        cooked: '<p>欢迎体验！试试收藏这篇帖子，再去收藏页找到它。</p>',
      ),
      ForumPost(
        id: topicId * 10 + 2,
        number: 3,
        username: '代码与咖啡',
        cooked: '<p>也欢迎测试横屏、系统深色模式和键盘弹出的布局。</p>',
      ),
    ],
    [topicId * 10, topicId * 10 + 1, topicId * 10 + 2],
  );
  @override
  Future<List<ForumPost>> morePosts(int topicId, List<int> ids) async => [];
  @override
  Future<int> publish(Draft draft) =>
      throw const ForumException('演示模式不发布帖子，请保存为本地草稿。');
  @override
  Future<void> like(int postId) =>
      throw const ForumException('演示模式不向真实社区发送点赞。');
  @override
  Future<String> currentUser() async => '离线体验';
  @override
  void close() {}
}

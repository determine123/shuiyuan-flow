import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shuiyuan_flow/forum_api.dart';
import 'package:shuiyuan_flow/models.dart';

void main() {
  DiscourseRepository repo(
    Future<http.Response> Function(http.Request) callback,
  ) => DiscourseRepository(
    apiKey: 'test-key',
    clientId: 'test-client',
    client: MockClient(callback),
  );
  test('请求仅使用 User API 授权并正确解析列表', () async {
    final r = repo((request) async {
      expect(request.url.host, 'shuiyuan.sjtu.edu.cn');
      expect(request.url.path, '/latest.json');
      expect(request.headers['User-Api-Key'], 'test-key');
      expect(request.headers.containsKey('Api-Key'), false);
      expect(request.followRedirects, false);
      return http.Response(
        jsonEncode({
          'topic_list': {
            'topics': [
              {
                'id': 1,
                'title': '测试',
                'category_id': 2,
                'posts_count': 3,
                'tags': [
                  {'name': '校园'},
                ],
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final result = await r.topics();
    expect(result.single.replies, 2);
    expect(result.single.tags, ['校园']);
    r.close();
  });
  test('搜索正确编码查询与分页', () async {
    final r = repo((request) async {
      expect(request.url.queryParameters['q'], '食堂 & 校园 category:1');
      expect(request.url.queryParameters['page'], '2');
      return http.Response('{"topics":[]}', 200);
    });
    await r.topics(query: '食堂 & 校园', categoryId: 1, page: 1);
    r.close();
  });
  test('分类使用 Discourse 分类路由', () async {
    final r = repo((request) async {
      expect(request.url.path, '/c/3/l/latest.json');
      return http.Response('{"topic_list":{"topics":[]}}', 200);
    });
    await r.topics(categoryId: 3);
    r.close();
  });
  for (final status in [302, 401, 403, 429, 500]) {
    test('HTTP $status 转换为可理解错误', () async {
      final r = repo((_) async => http.Response('{}', status));
      await expectLater(r.topics(), throwsA(isA<ForumException>()));
      r.close();
    });
  }
  test('HTML 登录页不被当作 JSON', () async {
    final r = repo((_) async => http.Response('<html>login</html>', 200));
    await expectLater(r.topics(), throwsA(isA<ForumException>()));
    r.close();
  });
  test('服务端业务错误不会误报发布成功', () async {
    final r = repo((_) async => http.Response('{"errors":["denied"]}', 200));
    await expectLater(
      r.publish(const Draft(id: 'a', title: 't', body: 'b', categoryId: 1)),
      throwsA(isA<ForumException>()),
    );
    r.close();
  });
  test('回复只发送 topic_id 不新建主题', () async {
    final r = repo((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/posts.json');
      final fields = Uri.splitQueryString(request.body);
      expect(fields['topic_id'], '42');
      expect(fields.containsKey('title'), false);
      expect(fields['raw'], '回复内容');
      return http.Response('{"topic_id":42}', 200);
    });
    expect(
      await r.publish(
        const Draft(
          id: 'a',
          title: '回复',
          body: '回复内容',
          categoryId: 1,
          topicId: 42,
        ),
      ),
      42,
    );
    r.close();
  });
  test('分批加载长话题后续帖子', () async {
    final r = repo((request) async {
      expect(request.url.queryParameters['post_ids[0]'], '21');
      return http.Response(
        '{"post_stream":{"posts":[{"id":21,"username":"alice","cooked":"<p>hello</p>","post_number":21}]}}',
        200,
      );
    });
    expect((await r.morePosts(1, [21])).single.number, 21);
    r.close();
  });
}

import 'package:shuiyuan_flow/forum_api.dart';
import 'package:shuiyuan_flow/models.dart';

/// 合成数据仅用于体验测试，不访问真实水源社区。
class BrowsingFixture extends DemoRepository {
  final int count;
  bool fail = false;
  BrowsingFixture({this.count = 500});
  @override
  Future<List<Topic>> topics({
    int page = 0,
    int? categoryId,
    String query = '',
  }) async {
    if (fail) throw const ForumException('合成网络错误，请重试');
    if (page > 0) return [];
    return List.generate(
          count,
          (i) => Topic(
            id: 10000 + i,
            title: '合成测试话题 ${i.toString().padLeft(4, '0')} · 校园阅读体验',
            categoryId: 1 + i % 4,
            replies: i % 50,
            views: i * 11,
            tags: ['测试数据'],
          ),
        )
        .where(
          (t) =>
              (categoryId == null || t.categoryId == categoryId) &&
              (query.isEmpty || t.title.contains(query)),
        )
        .toList();
  }

  @override
  Future<TopicThread> thread(int topicId) async => TopicThread(
    List.generate(
      40,
      (i) => ForumPost(
        id: topicId * 100 + i,
        number: i + 1,
        username: '测试用户$i',
        cooked:
            '<h3>合成长帖第 ${i + 1} 楼</h3>'
            '<p>${List.filled(8, '这是合成阅读内容，用于验证长话题和滚动。').join()}</p>'
            '<pre><code>final message = "hello Shuiyuan";</code></pre>'
            '<table><tr><th>项目</th><th>说明</th></tr><tr><td>阅读</td><td>合成数据</td></tr></table>',
      ),
    ),
    List.generate(40, (i) => topicId * 100 + i),
  );
}

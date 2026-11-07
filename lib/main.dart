import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'forum_api.dart';
import 'models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(await SharedPreferences.getInstance());
  String? startupError;
  try {
    await state.restoreSession();
  } catch (e) {
    startupError = '$e';
  }
  runApp(ShuiyuanApp(state: state, startupError: startupError));
}

class ShuiyuanApp extends StatelessWidget {
  final AppState state;
  final String? startupError;
  const ShuiyuanApp({super.key, required this.state, this.startupError});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => MaterialApp(
      title: '源流 · Shuiyuan Flow',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      themeMode: state.themeMode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomePage(state: state, startupError: startupError),
    ),
  );
  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF087F83),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF5F8F8)
          : const Color(0xFF111919),
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

void showMessage(BuildContext context, Object text) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$text')));

Future<void> openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !['https', 'http'].contains(uri.scheme)) {
    showMessage(context, '不支持的链接类型');
    return;
  }
  final allowed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('打开外部链接'),
      content: SelectableText(uri.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('在浏览器打开'),
        ),
      ],
    ),
  );
  if (allowed != true) return;
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted)
      showMessage(context, '无法打开浏览器');
  } catch (_) {
    if (context.mounted) showMessage(context, '无法打开浏览器');
  }
}

class HomePage extends StatefulWidget {
  final AppState state;
  final String? startupError;
  const HomePage({super.key, required this.state, this.startupError});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  int? categoryId;
  String query = '';
  final search = TextEditingController();
  Timer? debounce;
  List<ForumCategory> categories = [];
  List<Topic> topics = [];
  bool loading = true, loadingMore = false, hasMore = true;
  String? error;
  int page = 0, generation = 0;
  late ForumRepository repository;
  @override
  void initState() {
    super.initState();
    repository = widget.state.repository;
    widget.state.addListener(_stateChanged);
    _load();
    if (widget.startupError != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showMessage(context, widget.startupError!);
      });
  }

  void _stateChanged() {
    if (!identical(repository, widget.state.repository)) {
      repository = widget.state.repository;
      categoryId = null;
      query = '';
      search.clear();
      _load();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more && (loading || loadingMore || !hasMore)) return;
    final token = more ? generation : ++generation;
    final source = repository;
    setState(() {
      error = null;
      if (more) {
        loadingMore = true;
      } else {
        loading = true;
        loadingMore = false;
        page = 0;
      }
    });
    try {
      final nextPage = more ? page + 1 : 0;
      final result = await source.topics(
        page: nextPage,
        categoryId: categoryId,
        query: query,
      );
      final cats = more ? categories : await source.categories();
      if (!mounted || token != generation) return;
      setState(() {
        categories = cats;
        page = nextPage;
        hasMore = result.isNotEmpty;
        topics = more
            ? [
                ...topics,
                ...result.where((e) => !topics.any((t) => t.id == e.id)),
              ]
            : result;
        loading = false;
        loadingMore = false;
      });
    } catch (e) {
      if (!mounted || token != generation) return;
      setState(() {
        error = '$e';
        loading = false;
        loadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    widget.state.removeListener(_stateChanged);
    super.dispose();
  }

  ForumCategory category(int id) => categories.firstWhere(
    (e) => e.id == id,
    orElse: () => const ForumCategory(0, '未分类', '607D8B'),
  );
  Future<void> compose([Draft? draft]) async => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ComposerPage(
        state: widget.state,
        categories: categories,
        draft: draft,
      ),
    ),
  );
  void openTopic(Topic topic) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ThreadPage(
        state: widget.state,
        topic: topic,
        category: category(topic.categoryId),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final labels = ['发现', '收藏', '草稿', '设置'];
    final icons = [
      Icons.explore_outlined,
      Icons.bookmarks_outlined,
      Icons.edit_note,
      Icons.tune,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.water, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '源流',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'SHUIYUAN FLOW',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(
                repository.isDemo
                    ? Icons.science_outlined
                    : Icons.verified_user_outlined,
                size: 16,
              ),
              label: Text(
                repository.isDemo ? '离线体验' : widget.state.username ?? '已连接',
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1100,
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: List.generate(
                4,
                (i) => NavigationRailDestination(
                  icon: Icon(icons[i]),
                  label: Text(labels[i]),
                ),
              ),
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: switch (tab) {
                  0 => _feed(),
                  1 => _bookmarks(),
                  2 => _drafts(),
                  _ => SettingsPage(state: widget.state),
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: List.generate(
                4,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: labels[i],
                ),
              ),
            ),
      floatingActionButton: tab == 0 || tab == 2
          ? FloatingActionButton.extended(
              key: const Key('compose'),
              onPressed: () => compose(),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('写点什么'),
            )
          : null,
    );
  }

  Widget _feed() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: TextField(
          key: const Key('search'),
          controller: search,
          decoration: InputDecoration(
            hintText: '搜索话题、灵感与答案',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      debounce?.cancel();
                      search.clear();
                      query = '';
                      _load();
                    },
                  ),
          ),
          onChanged: (v) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 350), () {
              query = v.trim();
              _load();
            });
          },
          onSubmitted: (v) {
            debounce?.cancel();
            query = v.trim();
            _load();
          },
        ),
      ),
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('全部话题'),
                selected: categoryId == null,
                onSelected: (_) {
                  categoryId = null;
                  _load();
                },
              ),
            ),
            ...categories.map(
              (c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c.name),
                  selected: categoryId == c.id,
                  onSelected: (_) {
                    categoryId = c.id;
                    _load();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null && topics.isEmpty
            ? EmptyState(
                icon: Icons.wifi_off,
                title: '暂时无法加载',
                message: error!,
                action: () => _load(),
                actionLabel: '重试',
              )
            : RefreshIndicator(
                onRefresh: () => _load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (repository.isDemo &&
                        query.isEmpty &&
                        categoryId == null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '让交流，自然发生。',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '一处连接校园日常与奇思妙想的空间。\n以下内容为虚构演示，收藏与草稿保存在本机。',
                            ),
                          ],
                        ),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(error!),
                      ),
                    if (topics.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('没有找到相关话题，试试其他关键词。'),
                      ),
                    ...topics.map(_topicCard),
                    if (hasMore && topics.isNotEmpty)
                      Center(
                        child: TextButton(
                          onPressed: loadingMore
                              ? null
                              : () => _load(more: true),
                          child: Text(loadingMore ? '正在加载…' : '加载更多'),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    ],
  );
  Widget _topicCard(Topic t) {
    final cat = category(t.categoryId);
    final color = Color(
      int.tryParse('FF${cat.color}', radix: 16) ?? 0xFF607D8B,
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openTopic(t),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat.name,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          '${t.replies} 回复',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${t.views} 浏览',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        ...t.tags
                            .take(3)
                            .map(
                              (tag) => Text(
                                '# $tag',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: widget.state.isBookmarked(t) ? '取消收藏' : '收藏话题',
                onPressed: () async {
                  try {
                    await widget.state.toggleBookmark(t);
                  } catch (e) {
                    if (mounted) showMessage(context, e);
                  }
                },
                icon: Icon(
                  widget.state.isBookmarked(t)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookmarks() => widget.state.bookmarks.isEmpty
      ? const EmptyState(
          icon: Icons.bookmarks_outlined,
          title: '把值得重读的内容留在这里',
          message: '点击话题右侧的书签，即可本地收藏。',
        )
      : ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '我的收藏',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...widget.state.bookmarks.map(_topicCard),
          ],
        );
  Widget _drafts() => widget.state.drafts.isEmpty
      ? const EmptyState(
          icon: Icons.edit_note,
          title: '每个想法都值得留下',
          message: '写点什么，再保存为草稿，随时回来继续。',
        )
      : ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            const Text(
              '本地草稿',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...widget.state.drafts.map(
              (d) => Card(
                child: ListTile(
                  title: Text(d.title.isEmpty ? '未命名草稿' : d.title),
                  subtitle: Text(
                    d.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => compose(d),
                  trailing: IconButton(
                    tooltip: '删除草稿',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('删除这篇草稿？'),
                          content: const Text('删除后无法恢复。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true) {
                        try {
                          await widget.state.deleteDraft(d.id);
                        } catch (e) {
                          if (mounted) showMessage(context, e);
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final VoidCallback? action;
  final String actionLabel;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.actionLabel = '重试',
  });
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton(onPressed: action, child: Text(actionLabel)),
            ),
        ],
      ),
    ),
  );
}

class ThreadPage extends StatefulWidget {
  final AppState state;
  final Topic topic;
  final ForumCategory category;
  const ThreadPage({
    super.key,
    required this.state,
    required this.topic,
    required this.category,
  });
  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  List<ForumPost> posts = [];
  List<int> stream = [];
  final liked = <int>{};
  bool loading = true, busy = false;
  String? error;
  late final source = widget.state.repository;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    if (more && busy) return;
    setState(() {
      error = null;
      if (more) {
        busy = true;
      } else {
        loading = true;
      }
    });
    try {
      if (more) {
        final ids = stream
            .where((id) => !posts.any((p) => p.id == id))
            .take(20)
            .toList();
        final next = await source.morePosts(widget.topic.id, ids);
        if (!mounted) return;
        posts = [...posts, ...next];
      } else {
        final result = await source.thread(widget.topic.id);
        if (!mounted) return;
        posts = result.posts;
        stream = result.stream;
      }
      setState(() {
        loading = false;
        busy = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          loading = false;
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.category.name),
      actions: [
        ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) => IconButton(
            tooltip: widget.state.isBookmarked(widget.topic) ? '取消收藏' : '收藏话题',
            icon: Icon(
              widget.state.isBookmarked(widget.topic)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            onPressed: () async {
              try {
                await widget.state.toggleBookmark(widget.topic);
              } catch (e) {
                if (context.mounted) showMessage(context, e);
              }
            },
          ),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null && posts.isEmpty
        ? EmptyState(
            icon: Icons.error_outline,
            title: '加载失败',
            message: error!,
            action: () => load(),
          )
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: RefreshIndicator(
                onRefresh: () => load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    Text(
                      widget.topic.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),
                    ...posts.map(
                      (p) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Text(p.username.characters.first),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      p.username,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text('#${p.number}'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              HtmlWidget(
                                p.cooked,
                                onTapUrl: (url) async {
                                  await openExternal(
                                    context,
                                    Uri.parse(communityOrigin)
                                        .resolve(url)
                                        .toString(),
                                  );
                                  return true;
                                },
                                customWidgetBuilder: (element) =>
                                    source.isDemo &&
                                        [
                                          'img',
                                          'iframe',
                                          'video',
                                          'audio',
                                        ].contains(element.localName)
                                    ? const Text('离线体验不加载外部媒体')
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                icon: Icon(
                                  liked.contains(p.id)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 18,
                                ),
                                label: Text(
                                  '${p.likes + (liked.contains(p.id) ? 1 : 0)}',
                                ),
                                onPressed: liked.contains(p.id)
                                    ? null
                                    : () async {
                                        try {
                                          await source.like(p.id);
                                          if (mounted)
                                            setState(() => liked.add(p.id));
                                        } catch (e) {
                                          if (context.mounted)
                                            showMessage(context, e);
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (error != null) Text(error!),
                    if (posts.length < stream.length)
                      TextButton(
                        onPressed: busy ? null : () => load(more: true),
                        child: Text(busy ? '正在加载…' : '加载更多回复'),
                      ),
                  ],
                ),
              ),
            ),
          ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComposerPage(
            state: widget.state,
            categories: [widget.category],
            draft: Draft(
              id: 'reply-${DateTime.now().microsecondsSinceEpoch}',
              title: '回复：${widget.topic.title}',
              body: '',
              categoryId: widget.category.id,
              topicId: widget.topic.id,
            ),
          ),
        ),
      ),
      icon: const Icon(Icons.reply),
      label: const Text('回复'),
    ),
  );
}

class ComposerPage extends StatefulWidget {
  final AppState state;
  final List<ForumCategory> categories;
  final Draft? draft;
  const ComposerPage({
    super.key,
    required this.state,
    required this.categories,
    this.draft,
  });
  @override
  State<ComposerPage> createState() => _ComposerPageState();
}

class _ComposerPageState extends State<ComposerPage> {
  late final title = TextEditingController(text: widget.draft?.title ?? '');
  late final body = TextEditingController(text: widget.draft?.body ?? '');
  late final id =
      widget.draft?.id ?? 'draft-${DateTime.now().microsecondsSinceEpoch}';
  late int categoryId =
      widget.draft?.categoryId ?? (widget.categories.firstOrNull?.id ?? 0);
  bool saving = false, leaving = false;
  late String savedTitle = widget.draft?.title ?? '';
  late String savedBody = widget.draft?.body ?? '';
  late int savedCategory = categoryId;
  bool get dirty =>
      title.text != savedTitle ||
      body.text != savedBody ||
      categoryId != savedCategory;
  Draft get draft => Draft(
    id: id,
    title: title.text.trim(),
    body: body.text,
    categoryId: categoryId,
    topicId: widget.draft?.topicId,
  );
  Future<bool> save() async {
    if (title.text.trim().isEmpty && body.text.trim().isEmpty) {
      showMessage(context, '先写下一点内容吧');
      return false;
    }
    setState(() => saving = true);
    final snapshot = draft;
    try {
      await widget.state.saveDraft(snapshot);
      savedTitle = snapshot.title;
      savedBody = snapshot.body;
      savedCategory = snapshot.categoryId;
      return true;
    } catch (e) {
      if (mounted) showMessage(context, e);
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> back() async {
    if (saving || leaving) return;
    if (dirty) {
      final decision = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('保留这次编辑？'),
          content: const Text('保存草稿后，可以随时继续。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, 'cancel'),
              child: const Text('继续编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, 'discard'),
              child: const Text('放弃修改'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, 'save'),
              child: const Text('保存草稿'),
            ),
          ],
        ),
      );
      if (decision == null ||
          decision == 'cancel' ||
          (decision == 'save' && !await save()))
        return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> publish() async {
    if (body.text.trim().isEmpty ||
        (widget.draft?.topicId == null && title.text.trim().isEmpty)) {
      showMessage(context, '请填写标题和正文');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('发布到水源社区？'),
        content: const Text('发布后，其他社区用户将能够看到内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确认发布'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!await save() || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.state.repository.publish(draft);
      await widget.state.deleteDraft(id);
      if (!mounted) return;
      showMessage(context, '发布成功');
      setState(() {
        saving = false;
        leaving = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        showMessage(context, '$e\n内容已保留在本地草稿中。');
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || !dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) back();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.draft?.topicId == null ? '写点什么' : '回复话题'),
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
          onPressed: back,
        ),
        actions: [
          TextButton(
            onPressed: saving
                ? null
                : () async {
                    if (await save() && context.mounted)
                      showMessage(context, '草稿已保存');
                  },
            child: const Text('保存'),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.state.repository.isDemo)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Text('离线体验：内容只保存为本地草稿，不会发送到社区。'),
                ),
              if (widget.draft?.topicId == null) ...[
                TextField(
                  key: const Key('draft-title'),
                  controller: title,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: '标题'),
                  maxLength: 255,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: widget.categories.any((c) => c.id == categoryId)
                      ? categoryId
                      : null,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: widget.categories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (v) => setState(() => categoryId = v ?? categoryId),
                ),
                const SizedBox(height: 18),
              ],
              TextField(
                key: const Key('draft-body'),
                controller: body,
                enabled: !saving,
                minLines: 8,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: '正文',
                  hintText: '记录你的想法，支持 Markdown…',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : widget.state.repository.isDemo
                    ? () async {
                        if (await save() && context.mounted)
                          showMessage(context, '草稿已保存');
                      }
                    : publish,
                icon: Icon(
                  widget.state.repository.isDemo
                      ? Icons.save_outlined
                      : Icons.send_outlined,
                ),
                label: Text(
                  saving
                      ? '正在保存…'
                      : widget.state.repository.isDemo
                      ? '保存为本地草稿'
                      : '发布',
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        '让源流更适合你',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '外观',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ThemeMode.values
                    .map(
                      (mode) => ChoiceChip(
                        label: Text(switch (mode) {
                          ThemeMode.system => '跟随系统',
                          ThemeMode.light => '浅色',
                          ThemeMode.dark => '深色',
                        }),
                        selected: state.themeMode == mode,
                        onSelected: (_) async {
                          try {
                            await state.setTheme(mode);
                          } catch (e) {
                            if (context.mounted) showMessage(context, e);
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '社区连接',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                state.repository.isDemo
                    ? '当前为离线体验，未连接真实社区。'
                    : '已连接水源社区：${state.username}',
              ),
              const SizedBox(height: 10),
              const Text('真实访问需要社区书面许可、站方接口配置和用户授权。客户端不会收集 jAccount 密码。'),
              const SizedBox(height: 12),
              if (!communityAccessEnabled) const Text('此构建未启用真实社区接入。'),
              if (communityAccessEnabled && state.repository.isDemo)
                FilledButton.tonal(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConnectPage(state: state),
                    ),
                  ),
                  child: const Text('配置访问密钥'),
                ),
              if (!state.repository.isDemo)
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await state.disconnect();
                    } catch (e) {
                      if (context.mounted) showMessage(context, e);
                    }
                  },
                  child: const Text('退出并清除本机凭据'),
                ),
              TextButton(
                onPressed: () => openExternal(context, '$communityOrigin/tos'),
                child: const Text('查看水源社区协议'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '源流 · Shuiyuan Flow',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                '版本 0.2.0 · 非官方客户端\nAndroid / iOS / Windows / macOS / Linux',
              ),
              const SizedBox(height: 10),
              const Text(
                '借鉴 fluxdo 的 Flutter 自适应布局与 Discourse 客户端架构；本工程独立实现，保留来源说明。',
              ),
              const SizedBox(height: 10),
              const Text('隐私：收藏、草稿和设置保存在本机；访问密钥保存到系统安全存储。无广告、无分析上报、无上游自动更新。'),
              TextButton(
                onPressed: () => openExternal(
                  context,
                  'https://github.com/Lingyan000/fluxdo',
                ),
                child: const Text('参考项目 fluxdo'),
              ),
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: '源流 · Shuiyuan Flow',
                  applicationVersion: '0.2.0',
                ),
                child: const Text('开源许可证'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 40),
    ],
  );
}

class ConnectPage extends StatefulWidget {
  final AppState state;
  const ConnectPage({super.key, required this.state});
  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final keyInput = TextEditingController(), clientId = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    keyInput.dispose();
    clientId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('社区授权配置')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          '使用站方认可的 Discourse User API Key 和对应 Client ID。密钥需要相应的 read/write 权限。请勿输入 jAccount 密码或管理员 API Key。',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: clientId,
          decoration: const InputDecoration(labelText: 'Client ID'),
          autocorrect: false,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: keyInput,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'User API Key'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (keyInput.text.trim().isEmpty ||
                      clientId.text.trim().isEmpty) {
                    showMessage(context, '请填写密钥和 Client ID');
                    return;
                  }
                  setState(() => busy = true);
                  try {
                    await widget.state.connect(keyInput.text, clientId.text);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      setState(() => busy = false);
                      showMessage(context, e);
                    }
                  }
                },
          child: Text(busy ? '正在验证授权…' : '验证并连接'),
        ),
      ],
    ),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/tag_pill.dart';
import '../../state/search_state.dart';
import 'widgets/search_hit_tile.dart';

/// 搜索页：从各页右上角唤起，底部滑上来的全屏层。
///
/// 三块内容：
/// - 输入联想：本地已有的标题 + 历史，防抖 220ms，不发请求；
/// - 历史记录：空态时给可点标签，可一键清空；
/// - 结果：本地索引 + wiki 合并去重，失败能重试。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery});

  /// 打开时就带上的查询词（比如从事件阅读顺序点进来）。
  final String? initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<String> _suggestions = const [];
  bool _bootstrapped = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 首帧后如果带着初始查询，直接搜。
  void _bootstrap() {
    if (_bootstrapped) return;
    _bootstrapped = true;
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isEmpty) return;
    _controller.text = q;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    context.read<SearchState>().search(q);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _suggestions = context.read<SearchState>().suggestionsFor(value);
      });
    });
  }

  void _submit(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    _debounce?.cancel();
    _focusNode.unfocus();
    setState(() {
      _suggestions = const [];
      _controller.text = q;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    });
    context.read<SearchState>().search(q);
  }

  void _openHit(SearchHit hit) {
    switch (hit.kind) {
      case SearchHitKind.issue:
        final issue = hit.issue;
        if (issue != null) AppRouter.openIssue(context, issue);
      case SearchHitKind.guide:
        final guide = hit.guide;
        if (guide != null) AppRouter.openGuide(context, guide);
      case SearchHitKind.series:
        final id = hit.seriesId;
        if (id != null) AppRouter.openSeries(context, id, hit.title);
      case SearchHitKind.wikiSeries:
        final name = hit.wikiPageName;
        if (name != null) AppRouter.openWikiSeries(context, name);
      case SearchHitKind.event:
        final event = hit.event;
        if (event != null) AppRouter.openEvent(context, event);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SearchState>();
    if (!_bootstrapped) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bootstrap();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.initialQuery == null,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _submit,
          style: TextStyle(color: context.p.textPrimary, fontSize: 16),
          decoration: const InputDecoration(
            hintText: '搜索系列，如 Amazing Spider-Man',
            filled: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: Column(
        children: [
          LoadingBar(visible: state.loading),
          Expanded(child: _body(state)),
        ],
      ),
    );
  }

  Widget _body(SearchState state) {
    // 有联想词时优先显示联想
    if (_suggestions.isNotEmpty && !state.loading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        itemCount: _suggestions.length,
        itemBuilder: (context, i) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.north_west, size: 18, color: context.p.textGhost),
          title: Text(_suggestions[i],
              maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _submit(_suggestions[i]),
        ),
      );
    }

    if (!state.searched) return _idle();

    if (state.loading && state.results.isEmpty) {
      return const LoadingView(label: '正在搜索');
    }

    if (state.results.isEmpty) {
      return EmptyView(
        icon: Icons.search_off,
        title: '没搜到「${state.query}」',
        subtitle: '换个关键词，或试试英文系列名',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      itemCount: state.results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => SearchHitTile(
        hit: state.results[i],
        onTap: () => _openHit(state.results[i]),
      ),
    );
  }

  Widget _idle() {
    final history = context.watch<SearchState>().history;
    if (history.isEmpty) {
      return const EmptyView(
        icon: Icons.manage_search,
        title: '搜索漫威系列',
        subtitle: '已收藏和已导入的内容也会一起搜',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '搜索历史',
                style: TextStyle(
                  color: context.p.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.read<SearchState>().clearHistory(),
                style: TextButton.styleFrom(
                  foregroundColor: context.p.textGhost,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final h in history)
                TagPill(
                  label: h,
                  height: 30,
                  onTap: () => _submit(h),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
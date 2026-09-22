import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models/marvel_models.dart';
import '../../state/library_state.dart';
import '../issue/issue_resolver.dart';
import 'reader_page.dart';

/// `/reader/:id` 的落点：找回 issue → 取本地页面 → 交给阅读器。
///
/// 阅读器要的是「磁盘上的图片列表」，路由只带 id，所以这里负责把两件事
/// 串起来，并且把「还没导入 / 文件被移走」这类情况说清楚。
class ReaderRoutePage extends StatefulWidget {
  const ReaderRoutePage({super.key, required this.issueId, this.initial});

  final String issueId;
  final ComicIssue? initial;

  @override
  State<ReaderRoutePage> createState() => _ReaderRoutePageState();
}

class _ReaderRoutePageState extends State<ReaderRoutePage> {
  ComicIssue? _issue;
  List<String>? _pages;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final issue = await resolveIssue(context, widget.issueId, widget.initial);
      if (!mounted) return;
      if (issue == null) {
        setState(() {
          _loading = false;
          _error = '找不到这一期，请从指南或系列列表进入';
        });
        return;
      }
      final pages = await context.read<LibraryState>().pagesFor(issue);
      if (!mounted) return;
      setState(() {
        _issue = issue;
        _pages = pages;
        _loading = false;
        if (pages.isEmpty) _error = '找不到页面文件，可能还没导入或文件已被移动';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = _issue;
    final pages = _pages;
    if (issue != null && pages != null && pages.isNotEmpty) {
      return ReaderPage(issue: issue, pages: pages);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(issue?.title ?? '阅读'),
        actions: [
          if (issue != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: '回到详情页',
              onPressed: () => AppRouter.openIssue(context, issue),
            ),
        ],
      ),
      body: AsyncView(
        isLoading: _loading,
        error: _error,
        isEmpty: false,
        onRetry: _load,
        errorMessage: '无法打开',
        builder: (context) => const SizedBox.shrink(),
      ),
    );
  }
}
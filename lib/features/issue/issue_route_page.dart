import 'package:flutter/material.dart';

import '../../core/widgets/async_view.dart';
import '../../data/models/marvel_models.dart';
import 'issue_detail_page.dart';
import 'issue_resolver.dart';

/// `/issue/:id` 的落点：先按 id 把 issue 找回来，再交给详情页。
///
/// 深链冷启动时缓存是空的，找不到就明确提示从列表进入，
/// 而不是给一个空白页。
class IssueRoutePage extends StatefulWidget {
  const IssueRoutePage({super.key, required this.issueId, this.initial});

  final String issueId;
  final ComicIssue? initial;

  @override
  State<IssueRoutePage> createState() => _IssueRoutePageState();
}

class _IssueRoutePageState extends State<IssueRoutePage> {
  ComicIssue? _issue;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final issue = await resolveIssue(context, widget.issueId, widget.initial);
      if (!mounted) return;
      setState(() {
        _issue = issue;
        _loading = false;
        if (issue == null) _error = '找不到这一期，请从指南或系列列表进入';
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
    if (issue != null) return IssueDetailPage(issue: issue);

    return Scaffold(
      appBar: AppBar(),
      body: AsyncView(
        isLoading: _loading,
        error: _error,
        isEmpty: false,
        onRetry: _resolve,
        errorMessage: '打不开这一期',
        builder: (context) => const SizedBox.shrink(),
      ),
    );
  }
}
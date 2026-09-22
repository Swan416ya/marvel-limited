import 'package:flutter/material.dart';

import '../../data/models/marvel_models.dart';

/// Web 占位阅读器（浏览器无法读取本地漫画文件）。
class ReaderPage extends StatelessWidget {
  final ComicIssue issue;
  final List<String> pages;

  const ReaderPage({super.key, required this.issue, required this.pages});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(issue.title)),
      body: const Center(
        child: Text('Web 预览不支持阅读本地漫画，请使用 Android 版'),
      ),
    );
  }
}
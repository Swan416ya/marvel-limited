import 'package:flutter_test/flutter_test.dart';
import 'package:marvel_limited/data/series_naming.dart';

void main() {
  group('SeriesNaming.seriesFromTitle', () {
    test('从 "系列 #期号" 里切出系列名', () {
      expect(
        SeriesNaming.seriesFromTitle('Amazing Spider-Man #300'),
        'Amazing Spider-Man',
      );
    });

    test('没有期号时原样返回', () {
      expect(SeriesNaming.seriesFromTitle('Amazing Spider-Man'), 'Amazing Spider-Man');
    });

    test('标题里出现多个 # 时按最后一个切', () {
      expect(
        SeriesNaming.seriesFromTitle('Ultimate X #1 #2'),
        'Ultimate X #1',
      );
    });
  });

  group('SeriesNaming.issueFromTitle', () {
    test('取出期号', () {
      expect(SeriesNaming.issueFromTitle('Amazing Spider-Man #300'), '300');
    });

    test('没有期号时返回空串', () {
      expect(SeriesNaming.issueFromTitle('Amazing Spider-Man'), '');
    });
  });

  group('SeriesNaming.issueSortKey', () {
    test('纯数字按期号大小排', () {
      expect(SeriesNaming.issueSortKey('2'), 2);
      expect(SeriesNaming.issueSortKey('10'), 10);
      expect(
        SeriesNaming.issueSortKey('2') < SeriesNaming.issueSortKey('10'),
        isTrue,
      );
    });

    test('带小数点的期号按数值处理', () {
      expect(SeriesNaming.issueSortKey('300.1'), 300.1);
    });

    test('非数字的期号排在数字之后', () {
      expect(
        SeriesNaming.issueSortKey('Annual') > SeriesNaming.issueSortKey('9999'),
        isTrue,
      );
      expect(SeriesNaming.issueSortKey('Annual'), 99999.75);
    });
  });

  group('SeriesNaming.wikiPageName', () {
    test('年份换算成 Vol 号（边界含在上一档）', () {
      expect(
        SeriesNaming.wikiPageName('Amazing Spider-Man (1963)'),
        'Amazing Spider-Man Vol 1',
      );
      expect(
        SeriesNaming.wikiPageName('Amazing Spider-Man (1999)'),
        'Amazing Spider-Man Vol 3',
      );
      // 2018 落在 <=2018 这一档，2019 才进 Vol 5
      expect(
        SeriesNaming.wikiPageName('Amazing Spider-Man (2018)'),
        'Amazing Spider-Man Vol 4',
      );
      expect(
        SeriesNaming.wikiPageName('Amazing Spider-Man (2019)'),
        'Amazing Spider-Man Vol 5',
      );
    });

    test('没有年份括号时原样返回，交给调用方兜底', () {
      expect(
        SeriesNaming.wikiPageName('Amazing Spider-Man Vol 2'),
        'Amazing Spider-Man Vol 2',
      );
    });
  });
}
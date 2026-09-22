/// 系列页的英雄分类清单。
///
/// 角色 id 来自官网角色索引（与 developer.marvel.com 一致，长期稳定），
/// 直接写死而不是运行时按名字解析——前缀解析会抓到 "Spider-Man (1602)"
/// 这类平行宇宙条目（字母序在前），不可靠。
///
/// intro 是本项目自己写的一句话介绍（事实性概述）。
class HeroEntry {
  const HeroEntry(this.id, this.nameZh, this.nameEn, this.intro);

  /// 官网角色 id。
  final String id;
  final String nameZh;
  final String nameEn;
  final String intro;
}

const heroes = [
  HeroEntry('1009610', '蜘蛛侠', 'Spider-Man',
      '纽约皇后区的邻家英雄，被放射性蜘蛛咬伤后获得超能力，以「能力越大责任越大」著称。'),
  HeroEntry('1009368', '钢铁侠', 'Iron Man',
      '天才发明家托尼·斯塔克用心电弧反应炉打造战甲，复仇者的创始成员。'),
  HeroEntry('1009165', '复仇者', 'Avengers',
      '地球上最强大的英雄们组成的战队，为守护世界而战。'),
  HeroEntry('1009726', 'X战警', 'X-Men',
      '变种人族群为生存与共存而战，泽维尔天才少年学校走出的团队。'),
  HeroEntry('1009664', '雷神', 'Thor',
      '阿斯加德的雷霆之神，奥丁之子，复仇者创始成员。'),
  HeroEntry('1009351', '绿巨人', 'Hulk',
      '物理学家布鲁斯·班纳在伽马射线事故后变身的绿色巨人，越愤怒越强大。'),
  HeroEntry('1009282', '奇异博士', 'Doctor Strange',
      '前外科医生斯蒂芬·斯特兰奇在车祸后转向魔法，成为至尊法师。'),
  HeroEntry('1009718', '金刚狼', 'Wolverine',
      '拥有自愈因子与艾德曼合金骨架的爪战士，X战警最著名的成员。'),
  HeroEntry('1011299', '银河护卫队', 'Guardians of the Galaxy',
      '一伙星际边缘人组成的宇宙守护小队，嘴上互相嫌弃、关键时刻两肋插刀。'),
  HeroEntry('1009268', '死侍', 'Deadpool',
      '嘴炮满级的雇佣兵韦德·威尔逊，以打破第四面墙闻名。'),
  HeroEntry('1009220', '美国队长', 'Captain America',
      '二战超级士兵史蒂夫·罗杰斯，复仇者的精神领袖，振金盾牌的主人。'),
  HeroEntry('1009299', '神奇四侠', 'Fantastic Four',
      '被宇宙射线改变的四人组合，漫威的开山「第一家庭」。'),
];

HeroEntry? heroById(String id) {
  for (final h in heroes) {
    if (h.id == id) return h;
  }
  return null;
}
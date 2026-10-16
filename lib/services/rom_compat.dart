import 'package:flutter/foundation.dart';

import 'platform_bridge.dart';

/// 国产 ROM 适配。
///
/// ## 为什么需要这一层
///
/// Android 官方只保证「前台服务 + AlarmManager」这一套契约。但国产 ROM
/// 在其之上又加了三道自己的闸，且**没有标准 API 可查、没有标准 API 可开**：
///
///   1. **自启动**（开机/被清理后能否自行拉起）—— 各家一个私有 Activity
///   2. **后台运行 / 耗电管理**（允许完全后台行为 vs 智能省电）
///   3. **最近任务加锁**（防一键清理）—— 这个连跳转都没有，只能口述
///
/// 这三道闸默认**全部关闭**。任何一道没开，计时期间排好的闹钟都可能被系统
/// 连同进程一起清掉 —— 这正是「模拟器能弹、真机不弹」的根源。
///
/// 所以这里做两件事：把厂商认出来，给出**只针对该厂商**的引导文字；
/// 再提供能直达对应设置页的按钮，把用户从「翻五层菜单」降到「点一次」。
enum RomVendor {
  colorOs,
  realmeUi,
  oxygenOs,
  miui,
  emui,
  magicOs,
  funtouchOs,
  oneUi,
  flyme,
  stock,
  unknown;

  /// 给用户看的名字
  String get displayName => switch (this) {
        RomVendor.colorOs => 'ColorOS',
        RomVendor.realmeUi => 'realme UI',
        RomVendor.oxygenOs => 'OxygenOS / ColorOS',
        RomVendor.miui => 'MIUI / HyperOS',
        RomVendor.emui => 'EMUI',
        RomVendor.magicOs => 'MagicOS',
        RomVendor.funtouchOs => 'OriginOS / FuntouchOS',
        RomVendor.oneUi => 'One UI',
        RomVendor.flyme => 'Flyme',
        RomVendor.stock => '原生 Android',
        RomVendor.unknown => '未知 ROM',
      };

  /// 该 ROM 上「后台保活」必须手动开的东西。空列表表示原生 Android，
  /// 没有这些额外闸门 —— 不要给原生用户展示一堆用不上的步骤。
  List<String> get keepAliveSteps => switch (this) {
        RomVendor.colorOs || RomVendor.realmeUi || RomVendor.oxygenOs =>
          <String>[
            '自启动：应用管理 → 本应用 → 自启动 → 允许',
            '耗电管理：应用管理 → 本应用 → 耗电管理 → 允许完全后台行为',
            '最近任务 → 本应用卡片 → 加锁（防一键清理）',
          ],
        RomVendor.miui => <String>[
          '自启动：应用管理 → 本应用 → 自启动 → 打开',
          '省电策略：应用管理 → 本应用 → 省电策略 → 无限制',
          '最近任务 → 下拉本应用卡片 → 加锁',
        ],
        RomVendor.emui || RomVendor.magicOs => <String>[
          '启动管理：应用启动管理 → 本应用 → 手动管理 → 三项全开',
          '电池优化：不允许优化本应用',
          '最近任务 → 下拉本应用卡片 → 加锁',
        ],
        RomVendor.funtouchOs => <String>[
          '自启动：权限管理 → 自启动 → 允许',
          '后台高耗电：电池 → 后台高耗电 → 允许',
          '最近任务 → 下拉本应用卡片 → 加锁',
        ],
        RomVendor.oneUi => <String>[
          '电池：设置 → 电池 → 后台使用限制 → 从「休眠应用」里移除本应用',
          '关闭「自动禁用未使用的应用」对本应用的影响',
        ],
        RomVendor.flyme => <String>[
          '自启动：手机管家 → 权限管理 → 自启动 → 允许',
          '后台管理：允许后台运行',
        ],
        RomVendor.stock || RomVendor.unknown => <String>[],
      };

  /// 该 ROM 是否有「自启动管理」这类独立页面可跳
  bool get hasAutoStartPage => switch (this) {
        RomVendor.stock || RomVendor.unknown => false,
        _ => true,
      };
}

/// ROM 探测与引导。所有结论都是「尽力而为」——拿不到就退化成中性文案，
/// 绝不因为识别失败而给用户一个错误的操作指引。
class RomCompat {
  RomCompat._();

  static RomVendor? _cached;

  /// 已探测到的 ROM（未探测时为 null）
  static RomVendor? get detected => _cached;

  /// 探测当前 ROM。结果缓存，重复调用不重复打平台通道。
  static Future<RomVendor> detect() async {
    final RomVendor? cached = _cached;
    if (cached != null) return cached;
    if (kIsWeb) return _cached = RomVendor.unknown;

    String manufacturer = '';
    String brand = '';
    try {
      manufacturer = await PlatformBridge.getManufacturer();
      brand = await PlatformBridge.getBrand();
    } catch (_) {
      // 平台未实现：按未知处理
    }
    return _cached = classify(manufacturer, brand);
  }

  /// 纯函数形式的分类逻辑，便于单测。
  ///
  /// 注意 realme / iQOO / POCO 这类子品牌：`MANUFACTURER` 仍上报母公司
  /// （oppo / vivo / xiaomi），品牌差异只在 `BRAND` 上。所以两个字段都要看。
  @visibleForTesting
  static RomVendor classify(String manufacturer, String brand) {
    final String m = manufacturer.toLowerCase();
    final String b = brand.toLowerCase();
    final String s = '$m $b';

    if (s.trim().isEmpty) return RomVendor.unknown;

    // 子品牌必须先行判定：realme 的 MANUFACTURER 是 oppo，iQOO 的是 vivo，
    // 品牌差异只写在 BRAND 上。先按 MANUFACTURER 判会把它们吞掉。
    if (b.contains('realme')) return RomVendor.realmeUi;
    if (b.contains('iqoo')) return RomVendor.funtouchOs;

    if (m.contains('oneplus')) return RomVendor.oxygenOs;
    if (m.contains('oppo')) return RomVendor.colorOs;

    if (m.contains('xiaomi') || b.contains('redmi') || b.contains('poco')) {
      return RomVendor.miui;
    }
    if (m.contains('huawei')) return RomVendor.emui;
    if (m.contains('honor') || b.contains('honor')) return RomVendor.magicOs;

    if (m.contains('vivo')) return RomVendor.funtouchOs;

    if (m.contains('samsung')) return RomVendor.oneUi;
    if (m.contains('meizu')) return RomVendor.flyme;

    // Google / AOSP 系：没有必要保活的额外闸门
    if (m.contains('google') ||
        m.contains('sony') ||
        m.contains('motorola') ||
        m.contains('nothing') ||
        m.contains('asus') ||
        m.contains('nokia')) {
      return RomVendor.stock;
    }

    return RomVendor.unknown;
  }

  /// 跳转到自启动管理页。返回 false 表示连兜底的应用详情页都没起来。
  static Future<bool> openAutoStart() => PlatformBridge.openAutoStartSettings();

  /// 跳转到耗电管理 / 省电策略页。
  static Future<bool> openPowerManager() =>
      PlatformBridge.openPowerManagerSettings();
}

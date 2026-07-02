# 工作计划
> 最后更新: 2026-07-01 23:30

## 🔴 P0 - 紧急

## 🟡 P1 - 重要

## 🟢 P2 - 一般

## ✅ 已完成
- [x] 为 _persist() 添加 try-catch 错误处理 — 避免存储操作失败导致崩溃 — 2026-07-01 完成 (_persist() 方法包装在 try-catch 中，静默忽略存储异常防止崩溃)
- [x] 添加 DockPanel.copyWith() 方法 — 方便修改面板属性而不重建 — 2026-07-01 完成 (新增 copyWith({id, title, builder, icon, closable, clearIcon}) 方法)
- [x] 版本号 0.1.0 → 0.0.2 并更新 CHANGELOG.md — pubspec.yaml + CHANGELOG.md — 2026-07-01 完成 (pubspec.yaml 版本更新为 0.0.2，CHANGELOG.md 新增 0.0.2 条目，原 0.1.0 更名为 0.0.1)
- [x] 将 demo 从 lib/main.dart 迁移到 example/ 目录（库包不应含 main.dart） — 创建 example/lib/main.dart + example/pubspec.yaml，从 lib/ 中移除 main.dart — 2026-07-01 完成 (创建 example/pubspec.yaml + example/lib/main.dart，从 lib/ 中删除 main.dart，demo 引用改为 package:dock_panel/dock_panel.dart)

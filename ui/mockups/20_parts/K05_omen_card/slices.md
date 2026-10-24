# 20_parts/K05_omen_card

由 `ui/src/build_goals.py` 生成；格式同 style_guide §5。切片按 @1x 标注，@2x 为同一 SVG 的 2 倍导出。

| 名称 | 源尺寸 @1x | 导出 @1x / @2x | 切片 L,T,R,B | 内容边距 L,T,R,B | 画中心 | 主题变体 | 动效 | 说明 |
|---|---|---|---|---|---|---|---|---|
| `omen_card_normal` | 64×56 | 64×56 / 128×112 | 12,10,10,10 | 14,6,10,6 | 是 | OmenCardNormal | — | K05 前兆卡 normal（剩 ≥ 2 回合）：dai1 底 + 左 3px 橙条 |
| `omen_card_hover` | 64×56 | 64×56 / 128×112 | 12,10,10,10 | 14,6,10,6 | 是 | OmenCardHover | — | K05 hover：dai2 底，“查看 ›”变 gold_l |
| `omen_card_urgent` | 64×56 | 64×56 / 128×112 | 12,10,10,10 | 14,6,10,6 | 是 | OmenCardUrgent | — | K05 urgent（剩 1 回合）：朱红竖条 + 朱边（程序做 α0.6↔1 / 1.2s 呼吸） |

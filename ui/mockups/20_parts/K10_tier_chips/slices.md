# 20_parts/K10_tier_chips

由 `ui/src/build_goals.py` 生成；格式同 style_guide §5。切片按 @1x 标注，@2x 为同一 SVG 的 2 倍导出。

| 名称 | 源尺寸 @1x | 导出 @1x / @2x | 切片 L,T,R,B | 内容边距 L,T,R,B | 画中心 | 主题变体 | 动效 | 说明 |
|---|---|---|---|---|---|---|---|---|
| `tier_cell_empty` | 24×32 | 24×32 / 48×64 | —（固定尺寸） | — | 是 | — | — | K10 档位格（未压下）：绢黄底 + 墨线 |
| `tier_cell_cut` | 24×32 | 24×32 / 48×64 | —（固定尺寸） | — | 是 | — | — | K10 档位格（已压下）：绿底 + 白勾 |
| `tier_cell_preview` | 24×32 | 24×32 / 48×64 | —（固定尺寸） | — | 是 | — | — | K10 档位格（选中筹码后的预览）：虚线绿边 + 虚线勾，程序做 α0.5↔1 / 0.6s 闪烁 |
| `chip_card_normal` | 64×64 | 64×64 / 128×128 | 14,22,14,14 | 8,6,8,6 | 是 | ChipCardNormal | — | K10 筹码卡 normal（104×88）：panel_paper_plain 质感 |
| `chip_card_hover` | 64×64 | 64×64 / 128×128 | 14,22,14,14 | 8,6,8,6 | 是 | ChipCardHover | — | K10 hover：鎏金描边（档位条预览闪烁） |
| `chip_card_selected` | 64×64 | 64×64 / 128×128 | 14,22,14,14 | 8,6,8,6 | 是 | ChipCardSelected | — | K10 selected：朱红书签角 + 鎏金描边 |
| `chip_card_unavailable` | 64×64 | 64×64 / 128×128 | 14,22,14,14 | 8,6,8,6 | 是 | ChipCardUnavailable | — | K10 unavailable：灰米底 + 虚线边，下方朱红小字写缺什么 |
| `chip_card_risk` | 64×64 | 64×64 / 128×128 | 14,22,14,14 | 8,6,8,6 | 是 | ChipCardRisk | — | K10 风险卡（强硬拒绝）：朱红描边 |

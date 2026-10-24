# 20_parts/K01_goalbar

由 `ui/src/build_goals.py` 生成；格式同 style_guide §5。切片按 @1x 标注，@2x 为同一 SVG 的 2 倍导出。

| 名称 | 源尺寸 @1x | 导出 @1x / @2x | 切片 L,T,R,B | 内容边距 L,T,R,B | 画中心 | 主题变体 | 动效 | 说明 |
|---|---|---|---|---|---|---|---|---|
| `panel_goalbar` | 64×64 | 64×64 / 128×128 | 16,16,16,18 | 12,8,12,10 | 是 | GoalBarPanel | — | K01 目标栏底板：panel_ink 变体，外沿 1px 鎏金，仅左上角回纹 |
| `panel_goalbar_hover` | 64×64 | 64×64 / 128×128 | 16,16,16,18 | 12,8,12,10 | 是 | GoalBarPanel | — | K01 折叠态 hover：底色提亮到 dai2/dai3 |
| `panel_goalbar_urgent` | 64×64 | 64×64 / 128×128 | 16,16,16,18 | 12,8,12,10 | 是 | GoalBarPanel | — | K01 折叠态有紧急前兆：左侧 3px 朱红竖条（程序做 1.2s 呼吸） |

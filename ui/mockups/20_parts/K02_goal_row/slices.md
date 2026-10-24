# 20_parts/K02_goal_row

由 `ui/src/build_goals.py` 生成；格式同 style_guide §5。切片按 @1x 标注，@2x 为同一 SVG 的 2 倍导出。

| 名称 | 源尺寸 @1x | 导出 @1x / @2x | 切片 L,T,R,B | 内容边距 L,T,R,B | 画中心 | 主题变体 | 动效 | 说明 |
|---|---|---|---|---|---|---|---|---|
| `goal_row_normal` | 64×64 | 64×64 / 128×128 | 8,8,8,8 | 8,6,8,6 | 是 | GoalRowNormal | — | K02 本月令 normal：dai1 底 + 1px dai3 |
| `goal_row_hover` | 64×64 | 64×64 / 128×128 | 8,8,8,8 | 8,6,8,6 | 是 | GoalRowHover | — | K02 hover：dai2 底（右侧“前往 ›”由程序显示） |
| `goal_row_pressed` | 64×64 | 64×64 / 128×128 | 8,8,8,8 | 8,6,8,6 | 是 | GoalRowPressed | — | K02 pressed：dai0 + 内阴影 |
| `goal_row_main` | 64×64 | 64×64 / 128×128 | 8,8,8,8 | 8,6,8,6 | 是 | GoalRowMain | — | K02 主令：1.5px 鎏金描边（左上角叠 seal_main_s） |
| `goal_row_overdue` | 64×64 | 64×64 / 128×128 | 8,8,8,8 | 8,6,8,6 | 是 | GoalRowOverdue | — | K02 逾期：去色底（叠 seal_overdue） |
| `goal_row_shelved` | 64×32 | 64×32 / 128×64 | 8,8,8,8 | 8,6,8,6 | 是 | GoalRowShelved | — | K02 搁置：行高 32，虚线边，文字 ink4 |

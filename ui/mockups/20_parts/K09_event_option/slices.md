# 20_parts/K09_event_option

由 `ui/src/build_goals.py` 生成；格式同 style_guide §5。切片按 @1x 标注，@2x 为同一 SVG 的 2 倍导出。

| 名称 | 源尺寸 @1x | 导出 @1x / @2x | 切片 L,T,R,B | 内容边距 L,T,R,B | 画中心 | 主题变体 | 动效 | 说明 |
|---|---|---|---|---|---|---|---|---|
| `event_option_normal` | 96×56 | 96×56 / 192×112 | 16,12,16,14 | 16,6,16,8 | 是 | EventOptionNormal | — | K09 选项 normal：宣纸底 |
| `event_option_hover` | 96×56 | 96×56 / 192×112 | 16,12,16,14 | 16,6,16,8 | 是 | EventOptionHover | — | K09 hover：提亮 + 外发金光 |
| `event_option_pressed` | 96×56 | 96×56 / 192×112 | 16,12,16,14 | 16,6,16,8 | 是 | EventOptionPressed | — | K09 pressed：下沉 1px |
| `event_option_selected` | 96×56 | 96×56 / 192×112 | 16,12,16,14 | 16,6,16,8 | 是 | EventOptionSelected | — | K09 selected：左 4px 朱红竖条 + 鎏金描边 |
| `event_option_disabled` | 96×56 | 96×56 / 192×112 | 16,12,16,14 | 16,6,16,8 | 是 | EventOptionDisabled | — | K09 disabled / unavailable：灰米底（文字 ink4 + 第二行写原因） |
| `pill_warn` | 40×22 | 40×22 / 80×44 | 10,10,10,10 | 9,2,9,2 | 是 | PillWarn | — | 胜算签“五五”：warn 系胶囊（文字 #8A5A0E） |

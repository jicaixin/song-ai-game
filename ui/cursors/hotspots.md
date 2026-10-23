# 地图光标 · 热点清单

来源：`ui/src/cursors.py`（设计/地块交互方案.md §7.3）。PNG 在 `ui/cursors/png/`，SVG 在 `ui/cursors/svg/`。

| 编号 | 文件 | 名称 | 热点 @1x (32×32) | 热点 @2x (64×64) |
|---|---|---|---|---|
| C01 | `cur_default.png` / `cur_default@2x.png` | 默认（毛笔尖箭头） | (2, 2) | (4, 4) |
| C02 | `cur_select.png` / `cur_select@2x.png` | 选择（手） | (10, 2) | (20, 4) |
| C03 | `cur_move.png` / `cur_move@2x.png` | 移动（靴） | (16, 28) | (32, 56) |
| C04 | `cur_move_far.png` / `cur_move_far@2x.png` | 本月走不到 / 多回合（靴加沙漏） | (16, 28) | (32, 56) |
| C05 | `cur_attack.png` / `cur_attack@2x.png` | 攻击（剑） | (4, 4) | (8, 8) |
| C06 | `cur_ranged.png` / `cur_ranged@2x.png` | 远程（准星） | (16, 16) | (32, 32) |
| C07 | `cur_no.png` / `cur_no@2x.png` | 禁止（墨灰，不用朱） | (16, 16) | (32, 32) |
| C08 | `cur_inspect.png` / `cur_inspect@2x.png` | 查看（放大镜） | (12, 12) | (24, 24) |
| C09 | `cur_city.png` / `cur_city@2x.png` | 城（城门） | (16, 24) | (32, 48) |
| C10 | `cur_drag.png` / `cur_drag@2x.png` | 拖动（抓手，中键拖动） | (16, 16) | (32, 32) |

## Godot 接入

```gdscript
const CUR := preload("res://ui/cursors/hotspots.gd")  # 或直接读 hotspots.json
var tex := load("res://ui/cursors/png/cur_move.png")
Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(16, 28))
```

- 只在光标种类变化时调用 `set_custom_mouse_cursor()`（网页端每次都会改 CSS cursor）。
- 网页版一律用 32px 版：Godot 不会按 DPI 选择 @2x，64px 图在网页上会按 64 CSS px 显示（过大），且部分浏览器在光标靠近窗口边缘时会隐藏 >32px 的光标。
- @2x 版留给桌面原生导出：先检测 `DisplayServer.screen_get_scale() >= 2` 再用 @2x，热点乘 2。

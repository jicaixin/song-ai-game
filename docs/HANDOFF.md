# 《我带着AI穿越大宋》交接

Godot 4.7.2 / GDScript 单人网页回合制。中文界面。GL Compatibility，无线程，不用 SharedArrayBuffer，不加 COOP/COEP。视口 1280×720。

此后以 GitHub `jicaixin/song-ai-game` 为主仓库。这份 Cursor 工作区已冻结，不要再在这里提交。工作区 `main` 仍是未过滤历史 `c7ebed67ab296ce9d05d45906c765edaa20167f4`（35 笔，含 `build/web/`）。应推送的历史在同目录的 bundle 里：过滤后 tip `b1f2ed2f9240f13867d6381937467d501556e397`，34 笔，已去掉 `build/web/` 并在新提交里 gitignore。拼接见 `REASSEMBLE.txt`。

## 目录

场景只有 `scenes/main.tscn`。`scripts/main.gd` 在运行时建标题层、`WorldMap` 和 UI `CanvasLayer`（layer 10）。

| 路径 | 作用 |
|---|---|
| `scripts/autoload/` | Settings、DebugBridge、EventBus、AudioManager、DataDB、GameState、SaveManager、TurnManager |
| `scripts/core/` | 六边形、寻路、日历、战斗、地理、西夏 AI、豆沙包台词 |
| `scripts/view/world_map.gd` | 三维地图、镜头、城池、河流、疆界、势力字 |
| `scripts/view/terrain_factory.gd`、`map_layer.gd` | 地形网格与图层 |
| `scripts/ui/game_ui.gd` | 地图 HUD |
| `scripts/ui/desk.gd` | 各弹层。格物图整页交给 TechDesk |
| `scripts/ui/tech_desk.gd`、`tech_plan.gd` | 格物图 v3 绘制与规则。二者都 `class_name` 且被 preload |
| `scripts/ui/kit.gd` | 面板、按钮、图标、立绘 |
| `scripts/ui/title_screen.gd` | 标题屏 |
| `data/*.json` | 地形、势力、单位、76 城、43 科技、建筑、资源、平衡、开局、豆沙包台词 |
| `data/map/map_1040.json` | 1040 疆域。依据在 `docs/song_1040_borders.md` |
| `docs/设计文档.md` | 原始设计 |
| `shaders/` | `land` `water` `river` `border_fill` `border_stroke` `border_wash` `toon` `glow` |
| `art/models/song_city/clusters/` | `cluster_capital` / `cluster_walled` / `cluster_town` |
| `art/models/song_terrain/` | 山脊、丘陵、黄土、森林、田亩 |
| `ui/components/` | 界面套件。格物图状态图标 `st3_*`（16×16）、总览格 `tile3_*`（40×40），png 与 svg 都在，代码只用 png |
| `ui/icons/png/` | 建筑、资源、科技、天气图标 |
| `ui/art/portraits/{bust,head,frame,full}/` | 立绘 |
| `tests/test_core.gd` | 无头测试 |
| `tools/export_web.sh` `serve.py` `playtest.py` | 导出、静态服务、浏览器冒烟 |
| `export_presets.cfg` | 预设名 `Web` |

不要提交 `.godot/`、`uploads/`、`agent-tools/`、Noto 可变字体、blend、`src/`、`previews/`、`hex_ground_*.glb`。`.import` 要提交。`art/fonts/FusionPixel12-zh_hans.otf` 和 `ui_zh.ttf` 留在仓库里，导出排除。

## 本地运行与无头测试

Godot 4.3 以上可打开，导出以 **4.7.2** 为准。渲染器必须是 GL Compatibility。

```bash
godot --headless --path . -- --test
python3 tools/serve.py          # http://127.0.0.1:8734/  可用 PORT 改
```

测试入口是命令行 `--test`，不是单独场景。`main.gd` 加载 `tests/test_core.gd` 并 `quit(failed)`。覆盖：六边形、投影往返、年号、射程、地理与城、寻路、存档往返、格物图第 52 回合样例、镜头、字体。通过时打印 `ALL TESTS PASSED`，并打印 `SPAN z0/z1/z2`。

最近一次：全部通过。跨度 z0 41.62、z1 15.08、z2 6.00。`check_font` 在场景还在 setup 时 `add_child`，会打一条无害 ERROR，测试仍算通过。

不要对单个 `class_name` 脚本做孤立 `--check-only`。自动加载（DataDB、Settings）不在，会误报找不到标识符。新 `class_name` 进全局类缓存之前，调用方要 `preload`（`main.gd`、`test_core.gd`、`desk.gd` 已经这么做）。

GDScript 易错：fragment shader 不能 `return`；未类型化数组元素上的 `:=` 是解析错误；同一函数里重复 `var` 是解析错误；内嵌类看不见外层类的 const（`Graph`、`LineKey`、`Shade` 自己带颜色）；循环里的回调用 `.bind(id)`，不要用会捕获循环变量的 lambda。

## 导出 Web

```bash
export GODOT=/path/to/godot    # 缺省 /tmp/godot/godot
bash tools/export_web.sh       # --export-release "Web" build/web/index.html
python3 tools/serve.py
```

- 预设 `Web`：`variant/thread_support=false`，`progressive_web_app/ensure_cross_origin_isolation_headers=false`。
- 用模板里的 `web_nothreads_release.zip`。不要用带线程的 web 模板。
- `serve.py` 给 `.wasm` 设 `application/wasm`，`Cache-Control: no-store`，不加 COOP/COEP。
- 预算约 **60 MB**（pck + wasm）。最近一次 pck 17,020,876 + wasm 39,514,754 = **53.92 MB**。wasm 体积基本是引擎模板，pck 主要是字体、立绘和模型。
- 输出目录是 `build/web/`。过滤后的历史已 gitignore 这一目录。工作区这份 `.gitignore` 还没有这一行，不要把 wasm/pck 再交进 GitHub。
- 排除：`art/fonts/FusionPixel12-zh_hans.otf`、`ui_zh.ttf`、`ui_zh.bytes`。JSON 用 include_filter 打进包。
- 立绘导入是有损（全身约 0.58，半身约 0.68，头像与相框约 0.75）。日常只用半身、头像、相框。1024×1536 全身只留给赵祯和豆沙包。

## 字体与主题

项目主题 `ui/theme.tres`，并在 `project.godot` 的 `[gui] theme/custom` 指向它。默认字体是思源宋体常规。`CanvasLayer` 不继承 `Window.theme`，所以 `Settings` 还把主题赋给根窗口，标题屏、GameUI、Desk 再各自 `theme = Settings.theme`。没有 `ThemeDB.set_project_theme`。

`Settings._chain_fallbacks()` 关掉系统回退。网页上看不到操作系统字体，漏掉就会变成豆腐块。

| 变体 | 字体 | 字号 | 用途 |
|---|---|---|---|
| H1 / H2 / H3 | 思源宋体粗 | 28 / 20 / 16 | 标题 |
| Body / Caption | 霞鹜文楷 | 16 / 12 | 正文、说明 |
| Small / Hud / HudMuted | 思源宋体常规 | 13 / 15 / 13 | 小字、HUD |
| Number / HudNumber / 按钮 | 思源宋体粗 | 16（结束回合 22，科技节点 14） | 数字、按钮 |
| Brush / Display | 马善政 | 24 / 64 | 年号、标题屏 |

回退：思源与霞鹜缺的字（主要是 U+3007）走 `ideo-zero.ttf`。马善政缺字（包括「祐」）回思源宋体；年号里有「祐」时日期牌改用 H2，不要画方框。地图城名、势力名用 `Settings.font`（思源常规，城名旗可开 MSDF），不用 `ui_zh.ttf`。

子集没有 ⚡、▾、▸、⋯。界面写「电」「展开 / 收起」。✓ × ● ○ → … 有。

## 热键与操作

弹层开着或输入锁定时，地图热键不响应。Esc 关弹层或取消选择。

- 左键选己方单位，或查看敌军与地块。右键走到高亮格，或点射程内敌军，预览后选「开战」。中键拖动；中键点一下而不拖，等于右键命令。滚轮三档缩放。方向键或 WASD 平移。
- M 全图，只留「按 M 返回」。再按 M 回到原位。平时右下是小地图。
- Enter 或「结束回合」。空格切到仍可动的宋军。F 驻扎。F5 存槽一，F9 读槽一。存档界面另有自动档和三个槽。
- T 格物图，P 控制台，J 匠作院，I 百工图，L 贤才录，Y 朝堂，H 史册，E 时事，R 外交。
- 网页存档同时写 `localStorage`（`songgame_slot_0`…`3`）和 `user://saves`。格式是 JSON，再 gzip，再 base64。版本仍是 1，新字段可缺。

开局是宝元三年正月，镜头在延州。

## 渲染与性能约束

这些已经定稿，不要为了别的界面改回去：

- 三档镜头 `DIST [780, 280, 115]`、`PITCH [50, 52, 40]`、fov 50、near 0.5、far 4200。全图是另一模式，不占这三档。
- 可见六边形跨度：z2 约 4.5–8，z1 约 12–18，z0 约 35–50。最近一次 6.00 / 15.08 / 41.62。
- 拉伸 `canvas_items` + `keep` + 分数缩放，开 HiDPI。截图视口必须是 1280×720。1280×760 会留边，点不中按钮。
- 海岸线、城池集群、中文、跳过六边形底板、黄土、田亩、shader 河、疆界都不要回退。田亩约 65 片。Borders 已确认可以。
- 城：1 单位 = 1 米，模型六角外接圆 10 米，运行时按地图外接圆 18 放大 1.8 倍。都城 / 州府 / 县城用三个 cluster，按城名转 60° 的整数步。顶点色乘底色，材质开 `vertex_color_use_as_albedo`。
- 地图约 64×68，约 57 公里一格。兰伯特等角圆锥，标准纬线 25°N / 45°N，中央经线 112°E。不是 ETOPO / CHGIS。
- 平原橄榄绿，黄土浅赭，沙漠浅沙，草原灰绿。海从青绿到深水。暖色方向光加一点天光，Filmic。没有体积雾和 SDFGI。
- 远景城名按缩放和屏幕间距剔除，避免叠字。

## 已完成

- 月回合、年号（宝元 / 康定 / 庆历 / 皇祐）、天气、太阳能与电池、城市产出和军饷的粗结算。
- 移动力、地形消耗、控制区、寻路。远程攻击攻方不受反击。伤害按设计文档，含地形、城墙、渡河、侧翼、将领、伤势、兵种、冲锋。
- 西夏会靠近、攻击，或残血撤回兴庆。辽军按兵不动。
- 1040 疆界、shader 河、海岸、黄土、田亩、连续地面（不另铺六边形底板）。
- 全套界面套件：标题、HUD、城市、战斗、存档、朝堂、贤才录、史册、时事、外交、匠作院、百工图、控制台、格物图。
- 立绘：豆沙包、赵祯、范仲淹、韩琦、狄青、种世衡、李元昊、辽兴宗（契丹猎鹰装，不是幞头文官）、毕昇、苏颂、燕肃、曾公亮、台谏、冶铁、窑工、船匠。大理、交趾、高丽、吐蕃唃厮啰、西州回鹘没有人物图，外交用势力旗帜。
- 格物可以设计、排队、暂停（进度保留）、试制。试制完成只记下效果，不改产量。固件和朝堂诏令会改待机耗电、设计进度、试制槽、军饷和部分收入。时事是六条按回合出现的卡片。外交可以派使、开岁赐、开关市。
- 格物图 v3（T）：左栏三问接真实数据；聚焦只显示当前时代加下一时代的直接后继，已完成时代收成 44px 窄栏；总览 43 项，筛选只在总览，悬停出全名；节点 136×42，八种状态用形状 + `st3_*` + 文字；五种连线，无关线淡到 30%；右侧 360px 抽屉，单击选中、双击主动作，每个状态一个主按钮；设目标后画青蓝流动虚线，左栏改成目标卡；首次五步引导，可跳过，? 可重看。

第 52 回合样例是 `GameState.load_tech_sample()`：庆历四年四月，设计 K03 22/40，队列空，试制槽 1（K02 已试制 2/3 回合），图纸 I05、K04，铜 14、铁 46，已完成 21 项（全部时代一，加 I04、M05、E02、E03），实践 煤场 4、焦炉 6、水磨 6，电池 46，格物院未颁布，引导标记为已看过。图纸库 2/3。时代二显示 4/17。时代三要 1046 年三月（第 68 回合）或时代二完成 11/17。

## 已知问题（先修这三件视觉）

1. **格物图树区底是透明的。** `TechDesk.build()` 在根上铺了一张纸色 `ColorRect`，但 `Graph` 只描边，中间滚动区没有自己的不透明底。实机节点和连线后面透出三维地图。树区宿主要铺实，盖住地图。
2. **地图 HUD 穿插。** 顶栏、左上格物卡、单位卡、悬停字、底栏豆沙包、右下「结束回合」和小地图都是绝对坐标叠在地图上，彼此以及和城名 `Label3D`、势力字（`RealmLabels`，CanvasLayer 8）会互相穿插。收拢层级，不要为了这个改镜头。
3. **引导没有压暗。** 规格是四周约 60% 黑、洞边金框。`Shade._draw` 写了 alpha 0.6，但控件只靠锚点、没有显式 1280×720，布局前 `size` 为 0 就什么都不画。`_place_tutorial` 只改洞的位置。气泡还在，四周没暗下去。

格物图相对效果图、先不要当成新需求去改的差异：

- E05 在样例里是「缺前置×1」，不是效果图上的「缺铜」节点形。缺铜写在左栏「还缺」和抽屉「去补齐」。设为目标之后抽屉显示「当前目标」，不再重复「设为目标」。
- 抽屉试制回合用 `ceil(craft/12)`，E05 是「预计 6 回合」，效果图写 10。左栏试制显示存档里的 2/3。
- 图例条在第 10 回合之后默认收起。对比图是用调试命令撑开的。
- 抽屉打开时 136×42 的节点排不下，树横向滚动。时代一已经是 44px 窄栏，没有再收窄。
- 总览里已完成阶段仍是 40×40 格，标题写「齐」。筛选把不匹配的淡到 30%，不把它们拿掉。
- 「状态表」「组件」是游戏里的浮层，不是 04c / 04g 那张带 normal/hover/gray 的设计稿像素拷贝。
- 「去推广」打开开封。城市是否已经造过该解锁建筑，游戏没有记。图纸上限显示成 n/3，没有强制。实践 6/6 来自样例的 `site_turns`，不是建筑真实运转。
- I05 只是图纸时，I06 是「缺前置」，连线用青蓝点划，表示「前置只有图纸」。

## 刻意未做

- **匠作院、百工图、控制台的数据层没做。** 三页能打开，格物图能跳过去。匠作院没有图纸时是空的。百工图写明「产量还没接上城池，推广了也只是把这一格点亮」。控制台的手艺和「水轮 +12 电」没有进 `apply_power`。固件名单已经画在纸面上，字是米色。
- 科技完成大多只记一句效果，不改产量，也不能据此占城、征兵、建造。
- 没有战争迷雾、补给、断粮、占领、民夫。三川口不是剧本事件，只是开局把三支西夏部队放在延州城下。
- 大河不挡路，只在近战里扣战力。雪天只减移动力。雨天对远程的完整结算、高士气溃逃都没有。
- 宋朝城多、军饷少，国库每个月都会涨。不是平衡后的经济。
- 地图仍是约 57 公里一格的近似。塘泺只有很少几格。山体是程序脊线，兵模仍是低模。
- 存档版本 1，以后改字段不会迁移旧档。
- 西夏只做「靠近并打」或「残血回兴庆」。辽军不动。

设计文档里的下一段是 M2 / M3：迷雾与补给、三川口剧本、占城征兵建造、溃逃与占领、雨天远程。不是再堆一套新系统。

## 界面与效果图

效果图没有全部进 git。对比图在当时的产物目录，文件名如下。左为效果图，右为实机。

| 实机 | 效果图 / 对比图 |
|---|---|
| 标题 | `pair_06_title.png` |
| 地图 HUD | `pair_01_hud.png` |
| 城市 | `pair_02_city.png` |
| 战斗 | `pair_03_battle.png` |
| 存档 | `pair_05_save.png` |
| 朝堂 | `pair_14_court.png` |
| 贤才录 | `pair_13_talent.png` |
| 史册 | `pair_15_codex.png` |
| 研究条 | `pair_16_research.png` |
| 匠作院 | `pair_11_workshop.png` |
| 百工图 | `pair_12_industry.png` |
| 控制台 | `pair_07_console.png` |
| 格物图聚焦 | `04_tech_tree_v3` → `pair_04_tech_tree_v3.png` |
| 设为目标 | `04e_tech_target_path` → `pair_04e_tech_target_path.png` |
| 总览 | `04b_tech_tree_overview_v2` → `pair_04b_tech_tree_overview.png`（悬停全名另有 `ui_04b_hover_k02.png`） |
| 引导第 1 步 | `04f_tech_tutorial_step1` → `pair_04f_tech_tutorial.png` |
| 八种节点 | `04c_tech_node_states_v2` → `pair_04c_tech_node_states.png`（游戏内「状态表」） |
| 组件 | `04g_tech_components` → `pair_04g_tech_components.png`（游戏内「组件」） |

较早的格物图对比 `pair_04_tech.png`、`pair_04d_tech.png` 是 v3 之前的，不要拿来当现行规格。

## 测试与截图

浏览器要开调试桥：`http://127.0.0.1:8734/?debug=1`。`DebugBridge` 把状态写成 `window.__song`（base64 JSON）。命令从 `window.__techCmd` 读，带一个递增 nonce，例如 `sample|3`。命令：`sample` `open` `focus` `overview` `target` `tutorial` `legend` `parts` `bar` `pick:<科技 id>`。`main.gd` 每帧读命令，每 8 帧发布状态。发布的按钮矩形在 `__song.buttons`，格物图额外有 `tech_view`、`tech_target`、`tech_tutorial`、`tech_picked`。

截图不要靠键盘进 Godot。点 `__song.buttons` 里的矩形。键名包括 `desk_close`、`tech_focus`、`tech_overview`、`tech_help`、`tech_accept`、`tech_verb`、`tech_make_target`、`tech_skip`、`tech_next`、`node_<ID>`、`jump_workshop` / `jump_industry` / `jump_console`。右键在该页第一次截图之前就发，或换一张新页面，否则 Playwright 的右键进不了 Godot。Chrome 用 `--use-gl=angle --use-angle=swiftshader --disable-gpu-sandbox`。一帧大约 1.2–1.7 秒。等跨度稳定后再等约 2800 ms。优先 `canvas.toDataURL`。不要信图像描述模型对中文和「像不像文明」的判断，用像素和字形核对。

冒烟脚本是 `tools/playtest.py`（新游戏、移动或攻击、结束回合、存档、继续）。格物图 v3 的拍摄脚本没有进仓库。

无头测试的合格线就是上面的 `ALL TESTS PASSED` 和三档跨度。改格物图后至少跑一遍 `--test`。改了会进 pck 的资源后再导出，确认 pck+wasm 仍在约 60 MB 以内。

## 外部资源

- 引擎（Linux x86_64）：<https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip>
- 导出模板（约 1.2 GB 的 tpz）：<https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz>
- 归档页：<https://godotengine.org/download/archive/4.7.2-stable/>
- 解压后放到 `~/.local/share/godot/export_templates/4.7.2.stable/`。目录名和里面的 `version.txt` 都必须是 `4.7.2.stable`。网页导出用其中的 `web_nothreads_release.zip`。
- 思源宋体、霞鹜文楷、马善政的子集已经在 `ui/fonts/`，各有 OFL。不要把完整可变字体（曾经放在 `/tmp/fonts/NotoSansSC-VF.ttf`，约 17 MB）提交进来。补字用 `tools/build_ui_font.py`。
- 播放用的浏览器需要 WebGL。无头环境用 SwiftShader。不需要 SharedArrayBuffer。

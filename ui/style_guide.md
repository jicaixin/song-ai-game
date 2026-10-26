# 《我带着AI穿越大宋》UI 套件 · 风格指南

> 本文由 `src/gen_style_guide.py` 自动生成（色值、9-slice、图标表与注册表同源）。改资源后重新运行即可。

## 1. 设计原则

- **布局向《文明6》看齐**：顶栏资源条、左上研究/要务、右下“结束回合 + 小地图”、底部顾问对白、城市旗悬于城上。信息层级清晰，地图永远是主角。
- **视觉是宋式**：宣纸面板（米黄渐变 + 墨线 + 鎏金回纹角）、黛青漆面 HUD（深青绿底，与低多边形地形的青绿/赭黄协调）、朱红主按钮、石青结束回合、鎏金描边、印章点缀、宋体/楷体文字、汝窑天青作中性高光。
- **非像素风**：全部为矢量（SVG 源）+ 双倍图（@2x），线条有抗锯齿，阴影柔和。
- **“电”的专属色**：青蓝 `#3FD6E8` 只用于电量、科研、豆沙包屏幕与未来科技（电力分支）。宋代世界内的一切 UI 不得使用该色，这样玩家一眼就能看出“哪里是 AI 的力量”。
- **全中文**：数字用阿拉伯数字（易读），年号/月份用汉字；不出现英文 UI 文案（豆沙包机身铭牌“DS-8”除外，属于角色设定）。

## 2. 色板

**宣纸 / 墨**

| 名称 | 色值 | 用途 |
|---|---|---|
| `paper0` | `#FBF5E6` | 面板高光/浅色文字 |
| `paper1` | `#F3E9D2` | 面板主底 |
| `paper2` | `#E9DCBC` | 面板暗部/按钮底 |
| `paper3` | `#D8C59C` | 分隔线/禁用描边 |
| `paper4` | `#BFA877` | 宣纸深描边 |
| `ink` | `#2B2620` | 正文/墨线 |
| `ink2` | `#4A4036` | 次级文字 |
| `ink3` | `#76685A` | 说明文字 |
| `ink4` | `#A39482` | 禁用文字 |

**黛青漆面（HUD 深色）**

| 名称 | 色值 | 用途 |
|---|---|---|
| `dai0` | `#14211F` | HUD 最深底 |
| `dai1` | `#1B2B2C` | 顶栏/墨面板底 |
| `dai2` | `#243A3A` | HUD 悬停 |
| `dai3` | `#335050` | HUD 描边 |

**朱红**

| 名称 | 色值 | 用途 |
|---|---|---|
| `zhu` | `#C23B2A` | 主按钮/警示/宋 |
| `zhu_l` | `#DA5A3F` |  |
| `zhu_d` | `#8E2A1E` | 主按钮按下/标题绶带暗部 |
| `zhu_dd` | `#5E1C14` |  |

**鎏金**

| 名称 | 色值 | 用途 |
|---|---|---|
| `gold` | `#C9A24A` | 鎏金描边 |
| `gold_l` | `#E8CB7C` | 高亮描边/HUD 数值 |
| `gold_d` | `#8C6A24` | 回纹角/暗金 |
| `gold_dd` | `#5C4516` |  |

**石青 / 绿 / 天青 / 赭**

| 名称 | 色值 | 用途 |
|---|---|---|
| `qing` | `#2F5D8A` | 结束回合/石青强调 |
| `qing_l` | `#5F8DB8` |  |
| `qing_d` | `#1E3E5E` |  |
| `lv` | `#3E8A6E` | 粮/农/良好 |
| `lv_l` | `#6DB394` |  |
| `tianqing` | `#9FC3B8` | 汝窑天青：中性高光、碗形图标 |
| `tianqing_l` | `#C9DED6` |  |
| `zhe` | `#B5793A` | 匠/赭 |
| `zhe_l` | `#D9A35E` |  |

**电（仅限电力/科研/豆沙包）**

| 名称 | 色值 | 用途 |
|---|---|---|
| `dian` | `#3FD6E8` | 电量/科研 |
| `dian_l` | `#A8F4FF` |  |
| `dian_d` | `#1C8FA6` |  |
| `screen` | `#0F2226` | 豆沙包屏幕底 |

**语义**

| 名称 | 色值 | 用途 |
|---|---|---|
| `good` | `#4E9A45` | 正向数值 |
| `warn` | `#D99A2B` | 警告/中血 |
| `bad` | `#C23B2A` | 负向数值/低血 |

**科技系统 v1.0 专用（见 §9）**

| 名称 | 色值 | 用途 |
|---|---|---|
| `dian（设计）` | `#3FD6E8` | 设计阶段：耗电、豆沙包出图（与电色同一套，提醒“这是 AI 在算”） |
| `dian_ink` | `#1C8FA6` | 宣纸底上的设计文字/描边（青蓝压暗，保证对比度） |
| `zhe（试制）` | `#B5793A` | 试制阶段：匠力、材料、实践（宋人的手艺） |
| `zhe_ink` | `#83501F` | 宣纸底上的试制文字 |
| `court` | `#3F5E99` | 朝堂/政令主色（原“政”分支色移用，不再表示科技分支） |
| `court_d` | `#22375F` | 政令暗部/描边 |
| `court_l` | `#5274B0` | 政令高光 |

### 势力色

| 势力 | 键 | 主色 c1 | 辅色 c2（描边/字） | 暗色 c3 | 旗上文字色 | 徽字 |
|---|---|---|---|---|---|---|
| 北宋 | `song` | `#C23B2A` | `#E3B341` | `#7A2216` | `#FBF5E6` | 宋 |
| 辽 | `liao` | `#24467F` | `#D7DEE9` | `#142A50` | `#FBF5E6` | 辽 |
| 西夏 | `xia` | `#6B3E8E` | `#D8A657` | `#40235A` | `#FBF5E6` | 夏 |
| 唃厮啰（青唐吐蕃） | `tubo` | `#2A8C8A` | `#EFE3C6` | `#175654` | `#FBF5E6` | 蕃 |
| 大理 | `dali` | `#4E8A2F` | `#F1E2A6` | `#2D5619` | `#FBF5E6` | 理 |
| 交趾（李朝） | `jiaozhi` | `#D08A2C` | `#4A2C18` | `#8A5514` | `#2B1A0E` | 交 |
| 高丽 | `goryeo` | `#E6ECE8` | `#3F6A86` | `#9FB0AA` | `#1F3446` | 丽 |
| 叛乱势力 | `rebel` | `#4D4540` | `#C9B38A` | `#2A2522` | `#F3E9D2` | 叛 |

规则：宋＝朱红+鎏金；辽＝深蓝+银白；西夏＝紫+赭金（紫与吐蕃/大理绿、交趾琥珀明显区分）；吐蕃（唃厮啰）＝石青绿+米白；大理＝苍绿+浅金；交趾＝琥珀+深褐；高丽＝月白+青灰（浅底深字）；叛军＝灰褐（文档“民心崩溃→叛军”所需）。

### 科技分支色

| 分支 | 键 | 主色 | 暗色 |
|---|---|---|---|
| 农业水利（农） | `nong` | `#5E9A3A` | `#33601C` |
| 材料冶金（工） | `gong` | `#7D7468` | `#433C34` |
| 机械动力（械） | `xie` | `#4F7A8C` | `#2C4A57` |
| 交通商贸（商） | `shang` | `#C9962F` | `#7A5A16` |
| 军事（军） | `jun` | `#C23B2A` | `#7A2216` |
| 电力（电） | `dian` | `#2BB8CF` | `#156B7C` |
| 终极（终） | `zhong` | `#D4A93A` | `#6B4F12` |

科技系统 v1.0：分支为 农 / 工 / 械 / 商 / 军 / 电 / 终，共 43 项科技。新增“械”（机械动力，钢青 `#4F7A8C`），原“政”分支已取消，其相关内容改为朝堂政令（§9.4），石青色 `#3F5E99` 改作朝堂/政令色。分支徽章 `branch_<键>`，政令徽章 `badge_court`。

## 3. 字体（均为 SIL OFL 1.1，可商用、可随游戏分发、可子集化）

| 角色 | 字体 | 文件 | 授权 | 来源 |
|---|---|---|---|---|
| 标题 / 界面 / 数字（宋体） | 思源宋体 Noto Serif SC 400 / 700 | `fonts/NotoSerifSC-{Regular,Bold}.subset.ttf` | OFL 1.1（`fonts/OFL_notoserifsc.txt`） | github.com/google/fonts `ofl/notoserifsc` |
| 正文 / 对白（楷体） | 霞鹜文楷 LXGW WenKai 400 / 500 | `fonts/LXGWWenKai-{Regular,Medium}.subset.ttf` | OFL 1.1（`fonts/OFL_lxgw.txt`；保留字体名，许可明确允许网页分发子集） | github.com/lxgw/LxgwWenKai v1.520 |
| 书法标题 / 年号 / Logo | 马善政楷书 Ma Shan Zheng | `fonts/MaShanZheng-Regular.subset.ttf` | OFL 1.1（`fonts/OFL_mashanzheng.txt`） | github.com/google/fonts `ofl/mashanzheng` |

子集：GB2312 一级+二级汉字（6763）+ 常用符号 + 设计文档与本套件出现的全部字符，共 7574 字，由 `src/subset_fonts.py` 生成。新文案出现生僻字时把它加进脚本的额外字符表后重跑。Web 包体：宋体每个约 3.3 MB、楷体每个约 3.5 MB、书法约 5.6 MB；若包体吃紧，书法字体可只保留 Logo/年号用字（几百字，约 200 KB）。

### 字号（1280×720 逻辑像素）

| 角色 | 字体 | 字重 | 字号 | 行高 | Theme 变体 |
|---|---|---|---|---|---|
| display | 马善政 | 400 | 64px | 1.1 | DisplayLabel |
| h1 | 思源宋体 | 700 | 28px | 1.3 | H1Label |
| h2 | 思源宋体 | 700 | 20px | 1.35 | H2Label |
| h3 | 思源宋体 | 700 | 16px | 1.4 | H3Label |
| body | 霞鹜文楷 | 500 | 16px | 1.6 | BodyLabel / RichTextLabel |
| ui | 思源宋体 | 400 | 15px | 1.45 | Label（默认） |
| num | 思源宋体 | 700 | 16px | 1.2 | NumberLabel / HudNumberLabel |
| small | 思源宋体 | 400 | 13px | 1.4 | SmallLabel |
| caption | 霞鹜文楷 | 500 | 12px | 1.4 | CaptionLabel |
| button | 思源宋体 | 700 | 16px | 1.2 | Button |

最小字号 12px（说明/图例）。HUD 数值一律宋体粗体 + 1px 黑色投影；深色底上的文字用 `paper1`，宣纸底上用 `ink`。结束回合按钮 22px 宋体粗体，字距 3px。年号/月份在日期牌上用书法 19–20px。

## 4. 间距与布局

- 4px 基础网格；常用间距 4 / 8 / 12 / 16 / 24。屏幕安全边距 16px（顶栏贴边）。
- 顶栏高 50px（贴图 52px，底部 2px 金线 + 投影溢出）；HUD 面板距顶栏 16px。
- 宣纸面板内容边距 20 / 18 / 20 / 22（左/上/右/下），面板之间 12–16px；列表项高 60–78px，间距 6px。
- 右下角坞（dock）：结束回合 240×72（最小宽 220）位于 (1032,462)，小地图框 232×176 位于其下；背后黛青底板防止地图干扰。
- 豆沙包对白：卷轴 830×104，头像 128 圆框压在卷轴左端，文字楷体 16px，最多 3 行。
- 模态窗口居中，四周留 ≥48px 显示被压暗（`#000` 45%）且模糊的地图。

## 5. 9-slice 组件表（texture_margin = 下表“切片”，单位 @1x 像素）

`@2x` 文件的切片值同样按 @1x 填写（配合 `hidpi_theme.gd` 的 size_override 或 DPITexture）。“内容边距”即 StyleBox 的 content_margin；`—` 表示不设（-1，由切片决定最小尺寸）。

| 组件 | 尺寸 | 切片 L,T,R,B | 内容边距 L,T,R,B | 画中心 | 主题变体 | 说明 |
|---|---|---|---|---|---|---|
| `panel_paper` | 96×96 | 26,26,26,28 | 20,18,20,22 | 是 |  | 宣纸面板：城市/科技/存档等主面板底；含 3px 底部投影 |
| `panel_paper_plain` | 64×64 | 10,10,10,10 | 10,8,10,8 | 是 |  | 无装饰宣纸底：面板内的分组卡片 |
| `panel_ink` | 64×64 | 16,16,16,18 | 14,12,14,14 | 是 |  | 黛色漆面板：HUD 浮层（研究、单位卡、战斗预览） |
| `tooltip` | 48×48 | 10,10,10,12 | 12,9,12,11 | 是 |  | 悬停提示框 |
| `panel_scroll` | 240×112 | 30,22,30,22 | 30,16,30,16 | 是 |  | 绢本手卷：豆沙包对话框（左右卷轴，纵向可拉伸） |
| `topbar` | 64×52 | 4,6,4,14 | 12,6,12,14 | 是 |  | 顶栏底条（全宽横向拉伸） |
| `date_cartouche` | 140×34 | 16,12,16,12 | 16,4,16,4 | 是 |  | 顶栏年号牌匾 |
| `header_ribbon` | 220×44 | 46,12,46,12 | 46,6,46,10 | 是 |  | 朱红标题绶带：面板/窗口标题 |
| `nameplate` | 112×28 | 12,8,12,8 | 12,3,12,3 | 是 |  | 名牌（对话框说话人、城市面板标题） |
| `divider_cloud` | 240×16 | 46,0,46,0 | — | 是 |  | 云纹分隔线（HSeparator，三段拉伸） |
| `btn_primary_normal` | 96×40 | 14,12,14,14 | 14,6,14,8 | 是 |  | 朱漆主按钮 |
| `btn_primary_hover` | 96×40 | 14,12,14,14 | 14,6,14,8 | 是 |  |  |
| `btn_primary_pressed` | 96×40 | 14,12,14,14 | 14,6,14,8 | 是 |  |  |
| `btn_primary_disabled` | 96×40 | 14,12,14,14 | 14,6,14,8 | 是 |  |  |
| `btn_secondary_normal` | 96×40 | 14,12,14,14 | 14,6,14,8 | 是 |  | 宣纸次按钮 |
| `btn_secondary_hover` | 96×40 | 14,12,14,14 | 14,6,14,8 | 是 |  |  |
| `btn_secondary_pressed` | 96×40 | 14,12,14,14 | 14,6,14,8 | 是 |  |  |
| `btn_secondary_disabled` | 96×40 | 14,12,14,14 | 14,6,14,8 | 是 |  |  |
| `btn_endturn_normal` | 240×72 | 52,24,52,26 | 52,10,52,14 | 是 |  | 结束回合大按钮（石青；需要命令时用 alert 朱红） |
| `btn_endturn_hover` | 240×72 | 52,24,52,26 | 52,10,52,14 | 是 |  | 结束回合大按钮（石青；需要命令时用 alert 朱红） |
| `btn_endturn_pressed` | 240×72 | 52,24,52,26 | 52,10,52,14 | 是 |  | 结束回合大按钮（石青；需要命令时用 alert 朱红） |
| `btn_endturn_disabled` | 240×72 | 52,24,52,26 | 52,10,52,14 | 是 |  | 结束回合大按钮（石青；需要命令时用 alert 朱红） |
| `btn_endturn_alert` | 240×72 | 52,24,52,26 | 52,10,52,14 | 是 |  | 结束回合大按钮（石青；需要命令时用 alert 朱红） |
| `tab_normal` | 100×36 | 14,10,14,6 | 14,8,14,6 | 是 |  | 页签 |
| `tab_hover` | 100×36 | 14,10,14,6 | 14,8,14,6 | 是 |  | 页签 |
| `tab_selected` | 100×36 | 14,10,14,6 | 14,8,14,6 | 是 |  | 页签 |
| `list_item_normal` | 160×72 | 16,16,16,16 | 16,10,16,10 | 是 |  | 列表项/存档槽 |
| `list_item_hover` | 160×72 | 16,16,16,16 | 16,10,16,10 | 是 |  | 列表项/存档槽 |
| `list_item_selected` | 160×72 | 16,16,16,16 | 16,10,16,10 | 是 |  | 列表项/存档槽 |
| `lineedit_normal` | 96×36 | 10,10,10,10 | 10,6,10,6 | 是 |  | 输入框 |
| `lineedit_focus` | 96×36 | 10,10,10,10 | 10,6,10,6 | 是 |  |  |
| `bar_bg` | 64×14 | 7,7,7,7 | 2,2,2,2 | 是 |  | 进度条底槽（深色，用于 HUD） |
| `bar_bg_paper` | 64×14 | 7,7,7,7 | 2,2,2,2 | 是 |  | 进度条底槽（浅色，用于宣纸面板） |
| `bar_fill_power` | 64×14 | 6,6,6,6 | — | 是 |  | 进度条填充 |
| `bar_fill_food` | 64×14 | 6,6,6,6 | — | 是 |  | 进度条填充 |
| `bar_fill_gold` | 64×14 | 6,6,6,6 | — | 是 |  | 进度条填充 |
| `bar_fill_craft` | 64×14 | 6,6,6,6 | — | 是 |  | 进度条填充 |
| `bar_fill_hp_good` | 64×14 | 6,6,6,6 | — | 是 |  | 进度条填充 |
| `bar_fill_hp_mid` | 64×14 | 6,6,6,6 | — | 是 |  | 进度条填充 |
| `bar_fill_hp_bad` | 64×14 | 6,6,6,6 | — | 是 |  | 进度条填充 |
| `bar_fill_xp` | 64×14 | 6,6,6,6 | — | 是 |  | 进度条填充 |
| `bar_fill_order` | 64×14 | 6,6,6,6 | — | 是 |  | 进度条填充 |
| `slider_track` | 64×10 | 5,5,5,5 | — | 是 |  | 滑条轨道 |
| `slider_fill` | 64×10 | 5,5,5,5 | — | 是 |  | 滑条已填充段（电力分配） |
| `scroll_track` | 12×40 | 6,6,6,6 | — | 是 |  | 滚动条轨道 |
| `scroll_grabber_normal` | 12×40 | 6,7,6,7 | — | 是 |  | 滚动条滑块 |
| `scroll_grabber_hover` | 12×40 | 6,7,6,7 | — | 是 |  | 滚动条滑块 |
| `scroll_grabber_pressed` | 12×40 | 6,7,6,7 | — | 是 |  | 滚动条滑块 |
| `frame_minimap` | 232×176 | 28,28,28,28 | 10,10,10,10 | 否 |  | 小地图边框（中心透明，draw_center=false） |
| `tech_node_locked` | 208×68 | 18,18,18,18 | 14,8,14,8 | 是 |  | 科技节点 |
| `tech_node_available` | 208×68 | 18,18,18,18 | 14,8,14,8 | 是 |  | 科技节点 |
| `tech_node_researching` | 208×68 | 18,18,18,18 | 14,8,14,8 | 是 |  | 科技节点 |
| `tech_node_done` | 208×68 | 18,18,18,18 | 14,8,14,8 | 是 |  | 科技节点 |
| `banner_song` | 128×36 | 18,10,18,10 | 14,4,14,6 | 是 |  | 城市名旗（北宋） |
| `banner_liao` | 128×36 | 18,10,18,10 | 14,4,14,6 | 是 |  | 城市名旗（辽） |
| `banner_xia` | 128×36 | 18,10,18,10 | 14,4,14,6 | 是 |  | 城市名旗（西夏） |
| `banner_tubo` | 128×36 | 18,10,18,10 | 14,4,14,6 | 是 |  | 城市名旗（唃厮啰（青唐吐蕃）） |
| `banner_dali` | 128×36 | 18,10,18,10 | 14,4,14,6 | 是 |  | 城市名旗（大理） |
| `banner_jiaozhi` | 128×36 | 18,10,18,10 | 14,4,14,6 | 是 |  | 城市名旗（交趾（李朝）） |
| `banner_goryeo` | 128×36 | 18,10,18,10 | 14,4,14,6 | 是 |  | 城市名旗（高丽） |
| `banner_rebel` | 128×36 | 18,10,18,10 | 14,4,14,6 | 是 |  | 城市名旗（叛乱势力） |
| `scroll_track_h` | 40×12 | 6,6,6,6 | — | 是 |  | 水平滚动条轨道 |
| `scroll_grabber_h_normal` | 40×12 | 7,6,7,6 | — | 是 |  | 水平滚动条滑块 |
| `scroll_grabber_h_hover` | 40×12 | 7,6,7,6 | — | 是 |  | 水平滚动条滑块 |
| `scroll_grabber_h_pressed` | 40×12 | 7,6,7,6 | — | 是 |  | 水平滚动条滑块 |
| `node2_locked` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 | `TechNodeLocked` | 格物图节点 150×36 · 时代未开；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_locked_hover` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 |  | 格物图节点 150×36 · 时代未开（悬停）；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_noprereq` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 | `TechNodeNoprereq` | 格物图节点 150×36 · 缺前置；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_noprereq_hover` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 |  | 格物图节点 150×36 · 缺前置（悬停）；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_available` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 | `TechNodeAvailable` | 格物图节点 150×36 · 可设计；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_available_hover` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 |  | 格物图节点 150×36 · 可设计（悬停）；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_queued` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 | `TechNodeQueued` | 格物图节点 150×36 · 已排队；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_queued_hover` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 |  | 格物图节点 150×36 · 已排队（悬停）；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_designing` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 | `TechNodeDesigning` | 格物图节点 150×36 · 设计中；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_designing_hover` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 |  | 格物图节点 150×36 · 设计中（悬停）；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_nopower` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 | `TechNodeNopower` | 格物图节点 150×36 · 停电；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_nopower_hover` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 |  | 格物图节点 150×36 · 停电（悬停）；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_blueprint` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 | `TechNodeBlueprint` | 格物图节点 150×36 · 图纸已成；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_blueprint_hover` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 |  | 格物图节点 150×36 · 图纸已成（悬停）；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_trial` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 | `TechNodeTrial` | 格物图节点 150×36 · 试制中；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_trial_hover` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 |  | 格物图节点 150×36 · 试制中（悬停）；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_blocked` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 | `TechNodeBlocked` | 格物图节点 150×36 · 试制受阻；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_blocked_hover` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 |  | 格物图节点 150×36 · 试制受阻（悬停）；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_done` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 | `TechNodeDone` | 格物图节点 150×36 · 已完成；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `node2_done_hover` | 150×36 | 9,9,9,9 | 28,3,22,7 | 是 |  | 格物图节点 150×36 · 已完成（悬停）；左缘压 32px 科技图标，底边 4px 留给分段进度条 |
| `nodebar_bg` | 32×4 | 2,2,2,2 | — | 是 | `NodeBar` | 节点底边进度槽 4px |
| `nodebar_design` | 32×4 | 2,2,2,2 | — | 是 |  | 节点底边：设计进度（青蓝，左半） |
| `nodebar_nopower` | 32×4 | 2,2,2,2 | — | 是 |  | 节点底边：停电时的设计进度（灰） |
| `nodebar_trial` | 32×4 | 2,2,2,2 | — | 是 |  | 节点底边：试制进度（赭，右半） |
| `bar_fill_blocked` | 64×14 | 6,6,6,6 | — | 是 | `CraftBarBlocked`（平铺） | 试制受阻：赭色斑马纹填充（Godot 中横向 TILE） |
| `stage_frame_current` | 40×28 | 8,8,8,8 | 8,4,8,4 | 是 | `StageCurrent` | 当前阶段描金框（可做呼吸光：modulate.a 0.7↔1） |
| `pill_dian` | 40×22 | 10,10,10,10 | 9,2,9,2 | 是 | `PillDian` | 状态胶囊 / 材料小签（dian） |
| `pill_craft` | 40×22 | 10,10,10,10 | 9,2,9,2 | 是 | `PillCraft` | 状态胶囊 / 材料小签（craft） |
| `pill_good` | 40×22 | 10,10,10,10 | 9,2,9,2 | 是 | `PillGood` | 状态胶囊 / 材料小签（good） |
| `pill_bad` | 40×22 | 10,10,10,10 | 9,2,9,2 | 是 | `PillBad` | 状态胶囊 / 材料小签（bad） |
| `pill_mute` | 40×22 | 10,10,10,10 | 9,2,9,2 | 是 | `PillMute` | 状态胶囊 / 材料小签（mute） |
| `pill_gold` | 40×22 | 10,10,10,10 | 9,2,9,2 | 是 | `PillGold` | 状态胶囊 / 材料小签（gold） |
| `pill_court` | 40×22 | 10,10,10,10 | 9,2,9,2 | 是 | `PillCourt` | 状态胶囊 / 材料小签（court） |
| `pill_ink` | 40×22 | 10,10,10,10 | 9,2,9,2 | 是 | `PillInk` | 状态胶囊 / 材料小签（ink） |
| `card_slot_active` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `SlotActive` | 匠作院试制槽：进行中 |
| `card_slot_rush` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `SlotRush` | 试制槽：加急（金色外光） |
| `card_slot_short` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `SlotShort` | 试制槽：缺匠/缺料/缺实践（朱红边） |
| `card_slot_empty` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `SlotEmpty` | 试制槽：空槽（虚线） |
| `card_slot_locked` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `SlotLocked` | 试制槽：锁定（政令解锁） |
| `card_slot_done` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `SlotDone` | 试制槽：完成（金光，下回合清空） |
| `card_blueprint` | 96×72 | 16,14,14,14 | 19,10,12,10 | 是 | `BlueprintCard` | 图纸卡（青蓝左边条 = 豆沙包画的） |
| `card_blueprint_hover` | 96×72 | 16,14,14,14 | 19,10,12,10 | 是 |  | 图纸卡（悬停/拖拽） |
| `card_fw_done` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `FirmwareDone` | 固件卡：已安装 |
| `card_fw_writing` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `FirmwareWriting` | 固件卡：编写中 |
| `card_fw_available` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `FirmwareAvailable` | 固件卡：可编写 |
| `card_fw_locked` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `FirmwareLocked` | 固件卡：缺前置 |
| `card_facility` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `FacilityCard` | 发电设施卡 |
| `card_facility_off` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `FacilityCardOff` | 发电设施卡：未建/锁定 |
| `card_facility_alert` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `FacilityCardAlert` | 发电设施卡：未连通/停摆 |
| `card_edict` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `EdictRow` | 政令行 |
| `card_edict_selected` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `EdictRowSelected` | 政令行：选中 |
| `card_talent` | 150×190 | 20,20,20,20 | 12,10,12,10 | 是 | `TalentCard` | 贤才录人物卡 |
| `card_talent_hover` | 150×190 | 20,20,20,20 | 12,10,12,10 | 是 |  | 贤才录人物卡（悬停） |
| `card_talent_selected` | 150×190 | 20,20,20,20 | 12,10,12,10 | 是 | `TalentCardSelected` | 贤才录人物卡（选中，朱红书签） |
| `card_talent_locked` | 150×190 | 20,20,20,20 | 12,10,12,10 | 是 | `TalentCardLocked` | 贤才录人物卡（未招揽/不可招揽） |
| `chain_raw` | 96×40 | 12,12,12,12 | 10,4,10,6 | 是 | `ChainRaw` | 百工图节点：原料（资源点） |
| `chain_proc` | 96×40 | 12,12,12,12 | 10,4,10,6 | 是 | `ChainProc` | 百工图节点：加工建筑 |
| `chain_prod` | 96×40 | 12,12,12,12 | 10,4,10,6 | 是 | `ChainProd` | 百工图节点：产品 |
| `chain_dest` | 96×40 | 12,12,12,12 | 10,4,10,6 | 是 | `ChainDest` | 百工图节点：去向（单位/科技/电力） |
| `chain_locked` | 96×40 | 12,12,12,12 | 10,4,10,6 | 是 | `ChainLocked` | 百工图节点：未解锁（写明由哪项科技解锁） |
| `chain_short` | 96×40 | 12,12,12,12 | 10,4,10,6 | 是 | `ChainShort` | 百工图节点：缺口 |
| `chain_power` | 96×40 | 12,12,12,12 | 10,4,10,6 | 是 | `ChainPower` | 百工图节点：电力节点 |
| `bubble_paper` | 120×60 | 24,26,14,14 | 18,8,10,8 | 是 | `BubblePaper` | 对白气泡：大臣/台谏（宣纸，尾巴朝左上） |
| `bubble_dsb` | 120×60 | 24,26,14,14 | 18,8,10,8 | 是 | `BubbleDSB` | 对白气泡：豆沙包（屏幕黑底 + 青蓝边） |
| `frame_illust` | 64×64 | 12,12,12,12 | 6,6,6,6 | 否 | `IllustFrame` | 插图边框 320×180 / 160×90（中心透明） |
| `toast_blueprint` | 96×64 | 20,14,14,16 | 18,8,12,10 | 是 | `ToastBlueprint` | “图纸成”提示条（青蓝左边条，320×64） |
| `tl_track` | 64×8 | 4,4,4,4 | — | 是 | `TimelineTrack` | 古今对照轴 |
| `fc_bar` | 16×32 | 4,4,4,2 | — | 是 |  | 电力预报柱（纵向拉伸） |
| `fc_bar_low` | 16×32 | 4,4,4,2 | — | 是 |  | 电力预报柱：低于需求 |
| `strip_warn` | 64×22 | 6,6,6,6 | 8,2,8,2 | 是 | `WarnStrip` | HUD 研发小窗朱红警告行 |
| `row_hover` | 64×24 | 6,6,6,6 | 6,2,6,2 | 是 | `RowHover` | 可点击行悬停底（HUD 小窗、目录、列表） |
| `drawer_edge` | 24×96 | 0,8,0,8 | — | 是 |  | 抽屉左侧投影（纵向拉伸，放在抽屉左缘外 24px） |
| `node3_done` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 | `TechNode3Done` | 格物图 v3 节点 · 已完成；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：去推广 |
| `node3_done_hover` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 |  | 格物图 v3 节点 · 已完成（悬停）；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：去推广 |
| `node3_designing` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 | `TechNode3Designing` | 格物图 v3 节点 · 研发中（设计中）；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：暂停设计 |
| `node3_designing_hover` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 |  | 格物图 v3 节点 · 研发中（设计中）（悬停）；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：暂停设计 |
| `node3_available` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 | `TechNode3Available` | 格物图 v3 节点 · 可设计 / 已排队；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：安排设计 / 移出队列 |
| `node3_available_hover` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 |  | 格物图 v3 节点 · 可设计 / 已排队（悬停）；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：安排设计 / 移出队列 |
| `node3_noprereq` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 | `TechNode3Noprereq`（平铺） | 格物图 v3 节点 · 缺前置；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：设为目标 |
| `node3_noprereq_hover` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 |  | 格物图 v3 节点 · 缺前置（悬停）；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：设为目标 |
| `node3_blocked` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 | `TechNode3Blocked` | 格物图 v3 节点 · 缺电 / 缺匠 / 缺料（受阻）；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：去补齐 |
| `node3_blocked_hover` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 |  | 格物图 v3 节点 · 缺电 / 缺匠 / 缺料（受阻）（悬停）；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：去补齐 |
| `node3_blueprint` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 | `TechNode3Blueprint` | 格物图 v3 节点 · 图纸待试制；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：去匠作院试制 |
| `node3_blueprint_hover` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 |  | 格物图 v3 节点 · 图纸待试制（悬停）；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：去匠作院试制 |
| `node3_trial` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 | `TechNode3Trial` | 格物图 v3 节点 · 试制中；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：查看试制 |
| `node3_trial_hover` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 |  | 格物图 v3 节点 · 试制中（悬停）；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：查看试制 |
| `node3_locked` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 | `TechNode3Locked` | 格物图 v3 节点 · 已锁定（时代未开）；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：— |
| `node3_locked_hover` | 136×42 | 16,18,16,12 | 34,4,8,4 | 是 |  | 格物图 v3 节点 · 已锁定（时代未开）（悬停）；左缘 34px 放科技图标，文字两行：名称 / 状态字；主按钮动词：— |
| `panel_leftcol3` | 40×64 | 4,4,6,4 | 14,10,16,10 | 是 | `LeftColumnPanel` | 格物图左栏底板 300px（右缘双金线） |
| `card_suggest3` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `SuggestCard` | ② 豆沙包建议卡（青蓝左边条；1 条建议 + 1 句理由 + [采纳]） |
| `card_suggest3_telegram` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `SuggestCardTelegram`（平铺） | ② 建议卡·电报体（电量 < 20%：屏幕黑底、等宽短句、无表情） |
| `card_suggest3_none` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `SuggestCardNone` | ② 建议卡·无建议（“本月无需操作”，灰） |
| `card_target3` | 96×72 | 16,14,14,14 | 16,10,12,10 | 是 | `TargetCard` | 目标卡（替换②；青蓝双线 + 顶部 ◎ 标题） |
| `row_missing3` | 64×32 | 10,8,8,8 | 14,4,8,4 | 是 | `MissingRow` | ③ 还缺条目（朱红左边条 + “!” + 原因 + 跳转链接） |
| `row_ok3` | 64×32 | 10,8,8,8 | 14,4,8,4 | 是 | `OkRow` | ③ 无阻塞时：“一切顺利”（绿左边条） |
| `row_now3` | 64×32 | 8,8,8,8 | 8,3,8,3 | 是 | `NowRow` | ① 正在做：可点击行（悬停/点击跳转控制台或匠作院） |
| `row_now3_empty` | 64×32 | 8,8,8,8 | 10,3,10,3 | 是 | `NowRowEmpty` | ① 设计槽空时：整行朱红“选一份图纸” |
| `btn_verb3_normal` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 | `VerbButton` | 抽屉主按钮（朱红：去推广 / 设为目标 / 去补齐）· normal；每个状态只有一个动词 |
| `btn_verb3_hover` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 |  | 抽屉主按钮（朱红：去推广 / 设为目标 / 去补齐）· hover；每个状态只有一个动词 |
| `btn_verb3_pressed` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 |  | 抽屉主按钮（朱红：去推广 / 设为目标 / 去补齐）· pressed；每个状态只有一个动词 |
| `btn_verb3_disabled` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 |  | 抽屉主按钮（朱红：去推广 / 设为目标 / 去补齐）· disabled；每个状态只有一个动词 |
| `btn_verb3_design_normal` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 | `VerbButtonDesign` | 抽屉主按钮（青蓝：安排设计 / 暂停设计 / 移出队列）· normal；每个状态只有一个动词 |
| `btn_verb3_design_hover` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 |  | 抽屉主按钮（青蓝：安排设计 / 暂停设计 / 移出队列）· hover；每个状态只有一个动词 |
| `btn_verb3_design_pressed` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 |  | 抽屉主按钮（青蓝：安排设计 / 暂停设计 / 移出队列）· pressed；每个状态只有一个动词 |
| `btn_verb3_design_disabled` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 |  | 抽屉主按钮（青蓝：安排设计 / 暂停设计 / 移出队列）· disabled；每个状态只有一个动词 |
| `btn_verb3_craft_normal` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 | `VerbButtonCraft` | 抽屉主按钮（赭：去匠作院试制 / 查看试制）· normal；每个状态只有一个动词 |
| `btn_verb3_craft_hover` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 |  | 抽屉主按钮（赭：去匠作院试制 / 查看试制）· hover；每个状态只有一个动词 |
| `btn_verb3_craft_pressed` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 |  | 抽屉主按钮（赭：去匠作院试制 / 查看试制）· pressed；每个状态只有一个动词 |
| `btn_verb3_craft_disabled` | 96×40 | 14,12,14,14 | 16,6,16,8 | 是 |  | 抽屉主按钮（赭：去匠作院试制 / 查看试制）· disabled；每个状态只有一个动词 |
| `era_fold3` | 52×96 | 10,12,10,12 | 4,10,4,10 | 是 | `EraFoldBar` | 时代折叠栏（时代一全部完成后缩成 52px 竖条，点 [展开] 恢复） |
| `tut_spotlight3` | 64×64 | 18,18,18,18 | — | 否 | `TutorialSpotlight` | 引导镂空高亮框（外 60% 压暗由 ColorRect + shader 镂空实现） |
| `menu_card` | 64×64 | 14,14,14,16 | 8,8,8,10 | 是 | `MenuCard` | 命令卡底板：panel_ink 变体，外沿 1px 鎏金；投影 0,3 由贴图自带（代码可再加 0,3,8 α0.35 的 shadow） |
| `menu_row_normal` | 160×36 | 10,8,10,8 | 10,4,10,4 | 是 |  | 命令卡行 normal：透明，底部 1px 金线 α0.16 作分隔 |
| `menu_row_hover` | 160×36 | 10,8,10,8 | 10,4,10,4 | 是 |  | 命令卡行 hover：dai2 底 + 0.8px 暗金边 |
| `menu_row_pressed` | 160×36 | 10,8,10,8 | 10,4,10,4 | 是 |  | 命令卡行 pressed：dai0 + 内阴影 |
| `menu_row_disabled` | 160×36 | 10,8,10,8 | 10,4,10,4 | 是 |  | 命令卡行 disabled：同 normal，整体 α0.4（文字 ink4、图标去色由代码/图标 _off 版负责） |
| `menu_row_default` | 160×36 | 10,8,10,8 | 10,4,10,4 | 是 |  | 命令卡行 default：左侧 3px 金条 + dai2 底（默认项，打开时就有焦点） |
| `menu_row_reason` | 160×48 | 10,8,10,8 | 10,4,10,4 | 是 |  | 命令卡灰显带原因（两行 48）：左侧 2px 墨灰竖条 α0.55 提示“不可用”，第二行原因 13px |
| `menu_forecast` | 200×52 | 8,8,8,8 | 10,6,10,6 | 是 | `MenuForecast` | 预计战果区底：dai0 凹槽 + 暗金 1px |
| `keycap_normal` | 18×18 | 5,5,5,6 | 4,1,4,2 | 是 | `Keycap` | 快捷键帽 normal（字 13px paper1/gold_l，代码写字） |
| `keycap_active` | 18×18 | 5,5,5,6 | 4,1,4,2 | 是 | `KeycapActive` | 快捷键帽 active（字 13px paper1/gold_l，代码写字） |
| `tooltip_map` | 48×48 | 10,10,10,12 | 12,8,12,10 | 是 | `TooltipMap` | 地图悬停提示：tooltip 的黛青版（dai2→dai1 渐变） |
| `menu_leader` | 8×3 | 0,0,0,0 | — | 是 |  | 引线：Line2D 贴图（texture_mode = TILE，宽 3px）：中间 1px 鎏金 + 上下 1px 暗边 α0.45 防止在亮地面上看不见 |

### 非 9-slice 组件（固定尺寸，TextureRect / TextureButton 使用）

| 组件 | 尺寸 | 说明 |
|---|---|---|
| `btn_round_normal` | 44×44 | 圆形菜单按钮（铜镜样式，图标叠加其上） |
| `btn_round_hover` | 44×44 | 圆形菜单按钮（铜镜样式，图标叠加其上） |
| `btn_round_pressed` | 44×44 | 圆形菜单按钮（铜镜样式，图标叠加其上） |
| `btn_round_disabled` | 44×44 | 圆形菜单按钮（铜镜样式，图标叠加其上） |
| `btn_close_normal` | 32×32 | 关闭按钮（朱印方块） |
| `btn_close_hover` | 32×32 | 关闭按钮（朱印方块） |
| `btn_close_pressed` | 32×32 | 关闭按钮（朱印方块） |
| `checkbox_off` | 24×24 | 复选框 |
| `checkbox_off_hover` | 24×24 | 复选框 |
| `checkbox_on` | 24×24 |  |
| `checkbox_on_hover` | 24×24 |  |
| `checkbox_disabled` | 24×24 |  |
| `radio_off` | 24×24 |  |
| `radio_on` | 24×24 |  |
| `slider_grabber_normal` | 22×26 | 滑块（秤砣） |
| `slider_grabber_hover` | 22×26 | 滑块（秤砣） |
| `slider_grabber_disabled` | 22×26 | 滑块（秤砣） |
| `frame_portrait` | 128×128 | 豆沙包/人物圆形头像框（中心透明，内径 106） |
| `portrait_bg` | 128×128 | 头像底盘（天青） |
| `frame_hex` | 80×88 | 单位头像六角框（中心透明） |
| `hex_bg` | 80×88 | 单位头像底 |
| `hex_move` | 128×148 | 尖顶六边形格子高亮（移动/攻击/选中/射程） |
| `hex_attack` | 128×148 | 尖顶六边形格子高亮（移动/攻击/选中/射程） |
| `hex_select` | 128×148 | 尖顶六边形格子高亮（移动/攻击/选中/射程） |
| `hex_range` | 128×148 | 尖顶六边形格子高亮（移动/攻击/选中/射程） |
| `badge` | 20×20 | 红点角标（数字另叠加） |
| `seal_yu` | 48×48 | 印章装饰 |
| `seal_qingli` | 48×48 | 印章装饰 |
| `seal_doushabao` | 48×48 | 印章装饰 |
| `seal_guanjia` | 48×48 | 印章装饰 |
| `banner_pop_song` | 36×36 | 城市人口圆章（数字叠加） |
| `unit_flag_song` | 40×48 | 地图单位旗（兵种图标叠加于上部 20×20 区域） |
| `emblem_song` | 48×48 | 势力徽记（北宋） |
| `banner_pop_liao` | 36×36 | 城市人口圆章（数字叠加） |
| `unit_flag_liao` | 40×48 | 地图单位旗（兵种图标叠加于上部 20×20 区域） |
| `emblem_liao` | 48×48 | 势力徽记（辽） |
| `banner_pop_xia` | 36×36 | 城市人口圆章（数字叠加） |
| `unit_flag_xia` | 40×48 | 地图单位旗（兵种图标叠加于上部 20×20 区域） |
| `emblem_xia` | 48×48 | 势力徽记（西夏） |
| `banner_pop_tubo` | 36×36 | 城市人口圆章（数字叠加） |
| `unit_flag_tubo` | 40×48 | 地图单位旗（兵种图标叠加于上部 20×20 区域） |
| `emblem_tubo` | 48×48 | 势力徽记（唃厮啰（青唐吐蕃）） |
| `banner_pop_dali` | 36×36 | 城市人口圆章（数字叠加） |
| `unit_flag_dali` | 40×48 | 地图单位旗（兵种图标叠加于上部 20×20 区域） |
| `emblem_dali` | 48×48 | 势力徽记（大理） |
| `banner_pop_jiaozhi` | 36×36 | 城市人口圆章（数字叠加） |
| `unit_flag_jiaozhi` | 40×48 | 地图单位旗（兵种图标叠加于上部 20×20 区域） |
| `emblem_jiaozhi` | 48×48 | 势力徽记（交趾（李朝）） |
| `banner_pop_goryeo` | 36×36 | 城市人口圆章（数字叠加） |
| `unit_flag_goryeo` | 40×48 | 地图单位旗（兵种图标叠加于上部 20×20 区域） |
| `emblem_goryeo` | 48×48 | 势力徽记（高丽） |
| `banner_pop_rebel` | 36×36 | 城市人口圆章（数字叠加） |
| `unit_flag_rebel` | 40×48 | 地图单位旗（兵种图标叠加于上部 20×20 区域） |
| `emblem_rebel` | 48×48 | 势力徽记（叛乱势力） |
| `tile2_locked` | 40×40 | 格物图总览 0.55× 图标块 · 时代未开（图标 28px 居中叠加） |
| `tile2_noprereq` | 40×40 | 格物图总览 0.55× 图标块 · 缺前置（图标 28px 居中叠加） |
| `tile2_available` | 40×40 | 格物图总览 0.55× 图标块 · 可设计（图标 28px 居中叠加） |
| `tile2_queued` | 40×40 | 格物图总览 0.55× 图标块 · 已排队（图标 28px 居中叠加） |
| `tile2_designing` | 40×40 | 格物图总览 0.55× 图标块 · 设计中（图标 28px 居中叠加） |
| `tile2_nopower` | 40×40 | 格物图总览 0.55× 图标块 · 停电（图标 28px 居中叠加） |
| `tile2_blueprint` | 40×40 | 格物图总览 0.55× 图标块 · 图纸已成（图标 28px 居中叠加） |
| `tile2_trial` | 40×40 | 格物图总览 0.55× 图标块 · 试制中（图标 28px 居中叠加） |
| `tile2_blocked` | 40×40 | 格物图总览 0.55× 图标块 · 试制受阻（图标 28px 居中叠加） |
| `tile2_done` | 40×40 | 格物图总览 0.55× 图标块 · 已完成（图标 28px 居中叠加） |
| `nb_blocked` | 16×16 | 角标：试制受阻（朱红 !） |
| `nb_skip` | 16×16 | 角标：AI 跳步（青蓝“跳”字小印） |
| `nb_blueprint` | 16×16 | 角标：图纸已成（青蓝“图”字小印） |
| `nb_hammer` | 16×16 | 角标：试制中（锤子） |
| `nb_nopower` | 16×16 | 角标：停电（闪电加叉） |
| `nb_done` | 16×16 | 角标：已完成（朱红勾） |
| `nb_recommend` | 16×16 | 角标：豆沙包推荐（小包子脸） |
| `nb_queue1` | 16×16 | 角标：设计队列序号 ① |
| `nb_queue2` | 16×16 | 角标：设计队列序号 ② |
| `nb_queue3` | 16×16 | 角标：设计队列序号 ③ |
| `nb_talent_ring` | 16×16 | 角标：人才头像外圈（中间叠 char_*_s 缩到 13px） |
| `ring_practice_bg` | 14×14 | 实践门槛进度环底（TextureProgressBar.under，FILL_CLOCKWISE） |
| `ring_practice_fill` | 14×14 | 实践门槛进度环填充（TextureProgressBar.progress） |
| `ring_practice_done` | 14×14 | 实践门槛已满足 |
| `tag_new` | 24×16 | 城市建筑页“新”字小签 |
| `stage_cell_empty` | 10×12 | 阶段进度格：空 |
| `stage_cell_half` | 10×12 | 阶段进度格：半 |
| `stage_cell_full` | 10×12 | 阶段进度格：满 |
| `chain_arrow` | 12×12 | 百工图流向箭头（Line2D 末端） |
| `chain_arrow_short` | 12×12 | 百工图缺口箭头（朱红） |
| `tri_opp` | 12×10 | 反对派强度三角（1–3 个） |
| `tri_opp_empty` | 12×10 | 反对派强度三角（空） |
| `popup_glow` | 192×192 | “格物成”科技图标背后的金色光晕（96 图标居中） |
| `seal_gewu` | 48×48 | “格物成”弹窗朱印 |
| `seal_tuzhi` | 48×48 | 图纸库 / 图纸成 阳文印 |
| `tl_song` | 16×16 | 刻度：宋代已有基础 |
| `tl_game` | 16×16 | 刻度：本局完成回合 |
| `tl_game_empty` | 16×16 | 刻度：本局未完成（空心） |
| `tl_europe` | 16×16 | 刻度：欧洲大致年代 |
| `tile3_done` | 40×40 | 总览图标块 40×40 · 已完成（科技图标 28px 居中叠加） |
| `tile3_designing` | 40×40 | 总览图标块 40×40 · 研发中（设计中）（科技图标 28px 居中叠加） |
| `tile3_available` | 40×40 | 总览图标块 40×40 · 可设计 / 已排队（科技图标 28px 居中叠加） |
| `tile3_noprereq` | 40×40 | 总览图标块 40×40 · 缺前置（科技图标 28px 居中叠加） |
| `tile3_blocked` | 40×40 | 总览图标块 40×40 · 缺电 / 缺匠 / 缺料（受阻）（科技图标 28px 居中叠加） |
| `tile3_blueprint` | 40×40 | 总览图标块 40×40 · 图纸待试制（科技图标 28px 居中叠加） |
| `tile3_trial` | 40×40 | 总览图标块 40×40 · 试制中（科技图标 28px 居中叠加） |
| `tile3_locked` | 40×40 | 总览图标块 40×40 · 已锁定（时代未开）（科技图标 28px 居中叠加） |
| `st3_done` | 16×16 | 状态图标：已完成（朱红 ✓ 印） |
| `st3_designing` | 16×16 | 状态图标：研发中（豆沙包小脸） |
| `st3_available` | 16×16 | 状态图标：可设计（空心圆） |
| `st3_noprereq` | 16×16 | 状态图标：缺前置（断链） |
| `st3_blocked` | 16×16 | 状态图标：受阻（朱红 !） |
| `st3_blueprint` | 16×16 | 状态图标：图纸待试制（“图”字印） |
| `st3_trial` | 16×16 | 状态图标：试制中（锤） |
| `st3_locked` | 16×16 | 状态图标：已锁定（锁） |
| `req3_ok` | 16×16 | 门槛：已满足（绿底 ✓） |
| `req3_no` | 16×16 | 门槛：未满足（朱红 ×） |
| `req3_wait` | 16×16 | 门槛：进行中（赭色钟） |
| `qbadge3_1` | 20×20 | 队列序号角标 ①（压在节点左上角，外移 7px） |
| `qbadge3_2` | 20×20 | 队列序号角标 ②（压在节点左上角，外移 7px） |
| `qbadge3_3` | 20×20 | 队列序号角标 ③（压在节点左上角，外移 7px） |
| `badge3_target` | 20×20 | 目标角标 ◎（节点右上角；抽屉与目标卡标题前） |
| `qnum3_1` | 22×22 | 左栏三问序号 ① |
| `qnum3_2` | 22×22 | 左栏三问序号 ② |
| `qnum3_3` | 22×22 | 左栏三问序号 ③ |
| `line3_done` | 16×4 | 连线：前置已完成（金色实线 2px） |
| `line3_blueprint` | 24×4 | 连线：前置只有图纸（青蓝点划线：可设计，未能试制） |
| `line3_missing` | 10×4 | 连线：缺失的前置（朱红短虚线，仅悬停/选中时显示） |
| `line3_break` | 14×14 | 连线断点符号（放在缺失前置连线中点） |
| `line3_target` | 24×6 | 连线：目标路径（青蓝 3px 流动虚线；Godot 中用 shader 或 texture offset 每秒右移 24px） |
| `line3_arrow` | 12×12 | 目标路径箭头（末端） |
| `tut_arrow3` | 32×20 | 引导指向箭头（朝左，可旋转） |
| `hb_attack` | 16×16（@2x 32×32） | B01 格心：近战可攻击（剑） |
| `hb_move_attack` | 16×16（@2x 32×32） | B01b 格心：移动并攻击（靴加剑） |
| `hb_ranged` | 16×16（@2x 32×32） | B02 格心：远程可攻击（箭靶） |
| `hb_move` | 16×16（@2x 32×32） | B03 格心：本回合可达（脚印） |
| `hb_move_near` | 16×16（@2x 32×32） | B03b 格心：本月走不到，可先走到最近处（脚印加箭头） |
| `hb_acted` | 16×16（@2x 32×32） | B04 格心：己方已行动（✓） |
| `hb_blocked` | 16×16（@2x 32×32） | B05 格心：不可达 / 不可通行（禁止，墨色） |
| `hb_turns` | 16×16（@2x 32×32） | B06 格心：回合牌底（M2）；数字与“回”由代码写，内框 21×17@2x |
| `hb_resource` | 16×16（@2x 32×32） | B08 右上角标：金菱底，中心叠 res_* 图标（约 11px，@2x 22px） |
| `hb_city_own` | 16×16（@2x 32×32） | B09 格心：己方城（城垛朝外） |
| `hb_city_enemy` | 16×16（@2x 32×32） | B10 格心：敌城（城加尖角；颜色中性，势力由提示首行写明） |
| `hb_neutral` | 16×16（@2x 32×32） | B11 格心：中立 / 他国（旗；颜色可按势力 modulate） |
| `hb_river` | 16×16（@2x 32×32） | B12 右上角标：临河（水波） |
| `hb_pass` | 16×16（@2x 32×32） | B13 右上角标：关隘（“关”字朱印） |
| `hb_eye` | 16×16（@2x 32×32） | B14 格心：敌军打不到，只能查看（眼） |
| `hb_guide` | 16×16（@2x 32×32） | B15 格心：引导格指引箭头（呼吸光由代码做 α0.6↔1） |

## 6. 状态

| 状态 | 宣纸按钮 secondary | 朱红按钮 primary | 结束回合 | 列表项 / 页签 | 文字 |
|---|---|---|---|---|---|
| 常态 normal | 米黄底 + 墨线 + 金内线 | 朱红渐变 + 金边 | 石青 + 金边云纹 | 米黄 | ink / paper0 |
| 悬停 hover | 提亮 + 外发金光 | 提亮 `zhu_l` | 提亮 + 金光 | 浅金描边 | 不变 |
| 按下 pressed | 变暗 1 级，内阴影，整体下沉 1px | `zhu_d` | `qing_d` | 选中：左侧朱红竖条 + 金描边 | 不变 |
| 禁用 disabled | 灰米 + 50% 文字 | 灰褐 | 灰（“敌方行动中”） | — | `ink4` |
| 焦点 focus | 2px 鎏金圆角描边（StyleBoxFlat，键盘/手柄） | 同 | 同 | 同 | — |
| 警示 alert | — | — | 朱红 + 金边（“需要命令”/“单位待命”） | 角标 `badge`（朱红圆 + 白字） | — |

旧版科技节点（v0，已被 §9 的十态节点取代，仅为兼容保留）：`locked` 灰纸 + 锁 / `available` 米黄 + 暗金边 / `researching` 青蓝（电色）描边外发光 + 进度条 / `done` 浅金渐变 + 朱红勾。节点左侧放 32px 科技图标（图标外环即分支色）。格子高亮：移动＝月白、攻击＝朱红、选中＝浅鎏金、射程＝赭黄。

## 7. 图标

所有图标在 48×48 网格上绘制（墨线 2.4px、平涂 + 一道高光），按用途导出 @1x 与 @2x：

| 组 | 数量 | 输出尺寸 @1x（@2x） | 用途 |
|---|---|---|---|
| resource | 29 | 24 (48) | 顶栏资源、产出、战斗数值 |
| weather | 7 | 24 (48) | 顶栏天气 |
| branch | 7 | 32 (64) | 科技分支徽章 |
| ui | 27 | 24 (48) | 菜单按钮、操作按钮、城市等级、`badge_court` |
| unit | 36 | 32 (64) | 单位旗、单位卡；`_dark` 用于浅底 |
| building | 25 | 32 (64) | 城市面板、建造队列 |
| improvement | 8 | 32 (64) | 地块改良 |
| tech | 43 | 32 (64) | 科技节点（43 项，`tech_<ID>`） |
| firmware | 4 | 32 (64) | 豆沙包固件 `fw_D01`–`fw_D04`（深青屏幕风格） |
| edict | 8 | 32 (64) | 朝堂政令 `edict_<键>`（石青方印） |

命名：`res_*` 资源、`wx_*` 天气、`branch_*` 分支、`unit_*`（+`_dark`）兵种、`bld_*` 建筑、`imp_*` 改良、`ui_*` 界面、`city_rank_*` 城市等级、`tech_<ID>` 科技（ID 与《科技系统重设计》v1.0 第 5 节一致，如 `tech_M01` 神臂弓、`tech_K01` 齿轮与水磨规范），`fw_D0x` 固件，`edict_*` 政令。通用图标见 `mockups/09_icon_sheet.png`；43 项科技、固件、政令、分支和新建筑见 `mockups/17_tech_icon_sheet.png`。旧版科技图标（v0 旧 ID）与“政”分支、“铅”资源图标已移出套件，存放在 `../_retired_ui_assets/`。

| 资源图标 | 中文 |
|---|---|
| `res_food` | 粮 |
| `res_gold` | 钱 |
| `res_craft` | 匠 |
| `res_iron` | 铁 |
| `res_coal` | 煤 |
| `res_wood` | 木材 |
| `res_horse` | 马 |
| `res_copper` | 铜 |
| `res_saltpeter` | 硝 |
| `res_sulfur` | 硫 |
| `res_steel` | 钢 |
| `res_order` | 民心 |
| `res_prestige` | 皇威 |
| `res_secrecy` | 机密度 |
| `res_deviation` | 历史偏离度（蝴蝶效应） |
| `res_power` | 电 |
| `res_battery` | 电池容量 |
| `res_solar` | 太阳能板 |
| `res_research` | 研究（图纸） |
| `res_turn` | 回合 |
| `res_pop` | 人口 |
| `res_defense` | 城防 |
| `res_strength` | 近战战力 |
| `res_ranged` | 远程战力 |
| `res_move` | 移动力 |
| `res_supply` | 补给（军粮） |
| `res_tea` | 茶 |
| `res_salt` | 盐 |
| `res_silk` | 丝绢 |
| `wx_sunny` | 晴 |
| `wx_partly` | 多云 |
| `wx_overcast` | 阴 |
| `wx_rain` | 雨 |
| `wx_snow` | 雪 |
| `wx_dust` | 沙尘 |
| `wx_hail` | 冰雹 |

## 8. 豆沙包表情

| 文件 | 表情 | 何时使用 |
|---|---|---|
| `dsb_normal`（128，@2x 256）/ `dsb_normal_s`（48） | 普通 | 默认待机/一般提示 |
| `dsb_happy`（128，@2x 256）/ `dsb_happy_s`（48） | 开心 | 完成科技、胜利、玩家采纳建议 |
| `dsb_smug`（128，@2x 256）/ `dsb_smug_s`（48） | 得意 | 推演命中、“我早说了” |
| `dsb_deadpan`（128，@2x 256）/ `dsb_deadpan_s`（48） | 吐槽/无语 | 吐槽、玩家做出离谱决定 |
| `dsb_shocked`（128，@2x 256）/ `dsb_shocked_s`（48） | 惊讶 | 历史偏差骤升、突发事件 |
| `dsb_lowpower`（128，@2x 256）/ `dsb_lowpower_s`（48） | 低电量/困倦 | 电量 < 20%（电报体台词） |
| `dsb_serious`（128，@2x 256）/ `dsb_serious_s`（48） | 严肃 | 战争、危机、机密度告警 |
| `dsb_thinking`（128，@2x 256）/ `dsb_thinking_s`（48） | 思考 | 推演中/加载 |
| `dsb_awkward`（128，@2x 256）/ `dsb_awkward_s`（48） | 尴尬 | 推演失误、电量不足以执行 |
| `dsb_moved`（128，@2x 256）/ `dsb_moved_s`（48） | 感动 | 剧情感动时刻、范仲淹相关 |
| `dsb_off`（128，@2x 256）/ `dsb_off_s`（48） | 黑屏/休眠 | 电量 0 / 收板休眠 |

头像统一套在 `frame_portrait`（内径 106）+ `portrait_bg` 中使用；HUD 角落用 48px 小图。

> 人物立绘与正式头像放在 `art/portraits/`（另有专项重绘，不由本生成脚本产出）。`components/` 中的 `char_*` 人物头像（毕昇、燕肃、苏颂、曾公亮等）是科技界面效果图用的占位图，正式头像就绪后按同名替换。

## 9. 科技系统 v1.0（格物图 / 匠作院 / 百工图 / 贤才录 / 朝堂）

流程固定为：**设计**（耗电，豆沙包出图，青蓝）→ **试制**（匠力 + 材料 + 实践，赭色）→ **推广**（建筑/效果生效，鎏金）。界面里青蓝只出现在“设计”环节，赭色只出现在“试制”环节，玩家一眼就能分清“AI 算的”和“宋人做的”。

### 9.1 格物图节点十态（`node2_<状态>`，150×36，切片 9,9,9,9，内容边距 28,3,22,7）

| 状态 | PanelContainer 变体 | Button 变体（含悬停） | 底色 | 描边 | 含义 |
|---|---|---|---|---|---|
| locked | `TechNodeLocked` | `TechNodeButtonLocked` | `#D8C59C` | `#A39482` | 时代未开 |
| noprereq | `TechNodeNoprereq` | `TechNodeButtonNoprereq` | `#D8C59C` | `#BFA877` | 缺前置 |
| available | `TechNodeAvailable` | `TechNodeButtonAvailable` | `#F3E9D2` | `#8C6A24` | 可设计 |
| queued | `TechNodeQueued` | `TechNodeButtonQueued` | `#F3E9D2` | `#1C8FA6`（虚线） | 已排队 |
| designing | `TechNodeDesigning` | `TechNodeButtonDesigning` | `#FBF5E6` | `#1C8FA6` | 设计中 |
| nopower | `TechNodeNopower` | `TechNodeButtonNopower` | `#F3E9D2` | `#A39482` | 停电 |
| blueprint | `TechNodeBlueprint` | `TechNodeButtonBlueprint` | `#F3E9D2` | `#B5793A`（虚线） | 图纸已成 |
| trial | `TechNodeTrial` | `TechNodeButtonTrial` | `#F3E9D2` | `#B5793A` | 试制中 |
| blocked | `TechNodeBlocked` | `TechNodeButtonBlocked` | `#F3E9D2` | `#B5793A` | 试制受阻 |
| done | `TechNodeDone` | `TechNodeButtonDone` | 浅金渐变 | `#8C6A24` | 已完成 |

节点左缘压 32px 科技图标；底边 4px 放分段进度条：设计用 `NodeBarDesign`（青蓝），试制用 `NodeBarTrial`（赭），停电时用 `NodeBarNoPower`（灰），试制受阻时匠力条用 `CraftBarBlocked`（斜纹）。节点右上角标用 `nb_*` 组件（人才、材料缺口、实践、图纸）。四种状态对照见 `mockups/04c_tech_node_states.png`（v1，格物图已改用 §9.5 的 v3 节点）。

### 9.2 新增组件与主题变体

| 用途 | 组件 | 主题变体 |
|---|---|---|
| 匠作院试制槽 | `card_slot_active/rush/short/empty/locked/done` | SlotActive / SlotRush / SlotShort / SlotEmpty / SlotLocked / SlotDone |
| 图纸库卡片 | `card_blueprint(_hover)` | BlueprintCard |
| 豆沙包固件卡 | `card_fw_done/writing/available/locked` | FirmwareDone / FirmwareWriting / FirmwareAvailable / FirmwareLocked |
| 发电设施卡 | `card_facility(_off/_alert)` | FacilityCard / FacilityCardOff / FacilityCardAlert |
| 政令行 | `card_edict(_selected)` | EdictRow / EdictRowSelected |
| 贤才录人物卡 | `card_talent(_hover/_selected/_locked)` | TalentCard / TalentCardSelected / TalentCardLocked |
| 百工图节点 | `chain_raw/proc/prod/dest/locked/short/power，箭头 chain_arrow(_short)` | ChainRaw / ChainProc / ChainProd / ChainDest / ChainLocked / ChainShort / ChainPower |
| 状态胶囊 / 材料签 | `pill_dian/craft/good/bad/mute/gold/court/ink` | PillDian / PillCraft / PillGood / PillBad / PillMute / PillGold / PillCourt / PillInk |
| 对白气泡 | `bubble_paper / bubble_dsb` | BubblePaper / BubbleDSB |
| 格物志插图框 | `frame_illust` | IllustFrame |
| 图纸完成提示 | `toast_blueprint` | ToastBlueprint |
| 古今对照轴 | `tl_track + tl_song / tl_game / tl_game_empty / tl_europe` | TimelineTrack（平铺） |
| 当前阶段框 / 阶段格 | `stage_frame_current，stage_cell_full/half/empty` | StageCurrent |
| 警告条 / 行悬停 | `strip_warn / row_hover` | WarnStrip / RowHover |
| 其他固定尺寸 | `fc_bar(_low) 预报柱、tri_opp(_empty) 反对派三角、tag_new、popup_glow、seal_gewu、seal_tuzhi` | — |

所有切片值见 §5 表格（“主题变体”一列）。组件总览见 `mockups/18_component_sheet_v2.png`；已在 Godot 4.5.1 中实际加载，截图见 `qa/godot451_theme_v2_tech_variations.png`。

### 9.3 数据与效果图

- 科技数据在 `src/techdata.py`：43 项科技（`T`）、6 个阶段、3 个时代、附录 B 网格位置、4 个固件、8 条政令、6 座新建筑（造价取自 §4.5），以及效果图统一使用的第 52 回合存档 `SAVE`（庆历四年四月）。
- 效果图：04 格物图（04b 总览、04c 节点状态、04d 详情抽屉）、07 豆沙包控制台（07b 发电设施）、11 匠作院、12 百工图、13 贤才录、14 朝堂·制度改革、15 格物志、16 HUD 研究窗与弹窗。
- 资源：铅已从资源表删除。E06 的正式名“铅酸蓄电池”按设计文档保留，但材料只计铜 10、硫 10（极板按铜矿伴生副产计入铜）；界面上不出现铅图标或铅库存。

### 9.4 朝堂与政令

- 原“政”分支取消，制度类内容（皇城司、方田均税、保甲等）改为 8 条政令，在“朝堂 → 制度改革”页颁布，花费皇威/钱，不计入科技数。政令图标用石青方印 `edict_*`，行用 `EdictRow`，反对派强度用 `tri_opp` 三角（满 3）。

### 9.5 格物图 v3（《格物图UX重做》，取代 9.1 的十态节点用于格物图）

格物图打开后先回答三个问题，左栏 300px 固定：**① 正在做**拆成设计槽 1/1（进度、暂停、队列 ①②③，每行可上移或移出）和试制槽 n/m（空槽去匠作院；第二槽颁布格物院后开），下面才是图纸库 → **② 豆沙包建议**（只给 1 条建议 + 1 句理由 + [采纳]；设了目标后换成目标卡）→ **③ 还缺**（最多 3 条阻塞，每条带一个跳转链接）。设计中的节点慢呼吸并带进度环；排队的节点是灰底加序号，还没开始。右侧科技树默认是“聚焦”视图：已完成的时代收成 52px 竖条，展示当前时代全部节点，再加下一时代的直接后继（锁定）。总览（43 个 40×40 图标块）只在“总览”页出现，筛选也只放在总览页。设计前置按“前置科技已完成”，试制槽按代码 1 个、格物院后 2 个。

**硬规则**：状态必须能靠“形状 + 图标 + 状态字”三者分辨，颜色只是辅助（04c_v2 的灰度列可以验证）；每个节点只有一个主按钮动词。

| 状态 | 形状（`node3_<状态>`，136×42） | 图标（`st3_*`） | 状态字示例 | 主按钮动词 | PanelContainer / Button 变体 |
|---|---|---|---|---|---|
| 已完成 | 矩形，实心浅金 | `st3_done` 朱红 ✓ 印 | 已成 | 去推广 | `TechNode3Done` / `TechNode3ButtonDone` |
| 研发中（设计中） | 圆角双线边 + 青蓝外发光 | `st3_designing` 豆沙包小脸 | 设计 22/40 | 暂停设计 | `TechNode3Designing` / `TechNode3ButtonDesigning` |
| 可设计 / 已排队 | 圆角单实线；已排队时左上加 ①②③ | `st3_available` 空心 ○ | 可设计 / 排第1 | 安排设计 / 移出队列 | `TechNode3Available` / `TechNode3ButtonAvailable` |
| 缺前置 | 虚线边（平铺），名称变灰 | `st3_noprereq` 断链 | 缺前置×1 | 设为目标 | `TechNode3Noprereq` / `TechNode3ButtonNoprereq` |
| 缺电 / 缺匠 / 缺料（受阻） | 右上切角 + 朱红切线 | `st3_blocked` 朱红 ! | 缺铜 14/30 | 去补齐 | `TechNode3Blocked` / `TechNode3ButtonBlocked` |
| 图纸待试制 | 卷轴，两端卷边 | `st3_blueprint` “图”字印 | 待试制 | 去匠作院试制 | `TechNode3Blueprint` / `TechNode3ButtonBlueprint` |
| 试制中 | 六角斜切 | `st3_trial` 锤 | 试制 22/28 | 查看试制 | `TechNode3Trial` / `TechNode3ButtonTrial` |
| 已锁定（时代未开） | 矩形，整体 50% | `st3_locked` 锁 | T68开 | — | `TechNode3Locked` / `TechNode3ButtonLocked` |

节点切片 16,18,16,12，内容边距 34,4,8,4（左缘 34px 放科技图标）；悬停贴图 `node3_<状态>_hover`（外圈金光 + 底色提亮）。总览图标块 `tile3_<状态>`（40×40，固定尺寸，科技图标 28px 居中叠加）。

**主按钮动词与颜色族**（抽屉内 324×44，切片 14,12,14,14，内容边距 16,6,16,8）：朱红 `VerbButton` = 离开格物图去处理（去推广 / 设为目标 / 去补齐）；青蓝 `VerbButtonDesign` = 设计（安排设计 / 暂停设计 / 移出队列）；赭 `VerbButtonCraft` = 试制（去匠作院试制 / 查看试制）。已锁定节点不给按钮，只显示开启条件。贴图 `btn_verb3{,_design,_craft}_{normal,hover,pressed,disabled}`。

**设为目标**：抽屉主按钮下方的文字链 `TargetLink`（LinkButton，青蓝，衬线粗 13）。点击后把整条前置链自动排进设计队列（最多 3 项）；节点已完成、已锁定或已是当前目标时不显示。缺前置节点的主按钮本身就是“设为目标”。

**连线 5 种**（同样不靠颜色区分）：`line3_done` 金色实线 2px = 前置已完成；`line3_blueprint` 青蓝点划线 = 前置只有图纸（可设计，还不能试制）；`line3_missing` 朱红短虚线 + 中点 `line3_break` = 缺失的前置（默认隐藏，只在悬停/选中时显示）；`line3_target` 青蓝 3px 流动虚线 + `line3_arrow` = 目标路径（Godot 中用 shader 或 texture offset 每秒右移 24px）；与选中无关的线与节点淡出到 30%。

| 用途 | 组件 | 切片 / 内容边距 | 主题变体 |
|---|---|---|---|
| 左栏底板 | panel_leftcol3 | 4,4,6,4 / 14,10,16,10 | LeftColumnPanel |
| ② 建议卡 · 正常 / 电报体（电量 < 20%）/ 无建议 | card_suggest3 / _telegram / _none | 16,14,14,14 / 16,10,12,10（电报体虚线边，双向平铺） | SuggestCard / SuggestCardTelegram / SuggestCardNone |
| 目标卡（替换 ②） | card_target3 | 16,14,14,14 / 16,10,12,10 | TargetCard |
| ③ 还缺条目 / 一切顺利 | row_missing3 / row_ok3 | 10,8,8,8 / 14,4,8,4 | MissingRow / OkRow |
| ① 正在做 · 行 / 设计槽空 | row_now3 / row_now3_empty | 8,8,8,8 / 8,3,8,3 | NowRow / NowRowEmpty |
| 时代折叠栏 | era_fold3 | 10,12,10,12 / 4,10,4,10 | EraFoldBar |
| 引导镂空高亮框 | tut_spotlight3（中心透明） | 18,18,18,18 / 0 | TutorialSpotlight |
| 角标（固定尺寸） | qbadge3_1–3 队列序号、badge3_target 目标 ◎、qnum3_1–3 三问序号、req3_ok/no/wait 门槛、tut_arrow3 | — | — |
| 状态字颜色 | — | — | StateTextDone / StateTextDesign / StateTextTrial / StateTextBlocked / StateTextMuted（Label，宋体 12） |

**新手引导**（共 5 步，`04f`）：全屏 60% 压暗，只镂空当前讲解的区域（第 1 步是左栏 ①），镂空框用 `TutorialSpotlight`；豆沙包用 `dsb_smug`（得意）表情；底部是步数点 ●○○○○、“跳过引导”文字链和朱红“下一步 ▶”。已用 fontTools 确认思源宋体与霞鹜文楷子集都包含 ● ○ ◎ ✓ ① ② ③ ▶ ›；✗ ⚡ ◀ 不在子集中，界面里用 SVG 图标代替；马善政（书法标题字）不含这些符号，不要用它排符号。

效果图：`04_tech_tree_v3`（默认聚焦视图，与 `04_tech_tree.png` 相同）、`04e_tech_target_path`（E05 设为目标 + 360px 抽屉）、`04b_tech_tree_overview_v2`（总览）、`04f_tech_tutorial_step1`（引导第 1 步）、`04c_tech_node_states_v2`（8 态 × 常态/悬停/灰度 + 连线 + 动词）、`04g_tech_components`（组件）。已在 Godot 4.5.1 中加载，截图见 `qa/godot451_theme_v3_gewutu.png`。

## 10. 使用规则速查

- 主要操作只放一个朱红按钮（如“进攻”“读取此档”“确认分配”），其余用宣纸按钮。
- 正向数字 `good` 绿、负向 `bad` 朱红；电量永远青蓝；钱永远鎏金；粮绿；匠赭。
- 敌我信息：城市旗、单位旗只用势力色，不要再叠加红绿敌我色；敌对关系看外交面板与战斗预览。
- 每屏最多一个“鎏金发光”焦点（当前回合需要处理的东西）。
- 面板阴影统一向下 3px、20% 黑；不要再加 Godot 的 shadow，避免双重阴影。

## 11. 已取代的文件

| 旧文件 | 现状 |
|---|---|
| `mockups/04_tech_tree.png` | 现与 `04_tech_tree_v3.png` 相同（格物图 v3，§9.5） |
| `mockups/04_tech_tree_v2.png` | 已被 `04_tech_tree_v3.png` 取代（保留作对照） |
| `mockups/04b_tech_tree_overview.png` | 已被 `04b_tech_tree_overview_v2.png` 取代 |
| `mockups/04c_tech_node_states.png`（v1 十态） | 已被 `04c_tech_node_states_v2.png`（8 态三重编码）取代；`node2_*` / `TechNode<状态>` 仍可用于其他界面的小节点 |
| `mockups/07_power_console.png` | 已按 v1.0 重绘，内容与 `07_power_console_v2.png` 相同 |
| 主题变体 `TechNodeResearching` | 仅为兼容保留，外观等同 `TechNodeDesigning`；新界面请用 §9.1 的十态 |
| 组件 `tech_node_locked/available/researching/done` | v0 节点，保留文件但不再用于格物图 |
| `icons/*/branch_zheng`、`res_lead`、v0 旧 ID 的 `tech_*` | 已移到 `../_retired_ui_assets/icons_v1/`，不再随套件分发 |
| `src/techdata_v1.py`、`mock_04_tech_v1*.py`、`mock_07_console_v1.py` | 已移到 `../_retired_ui_assets/src_legacy/` |

## 12. 大地图地块交互（《地块交互方案》，对照 93d2cf5）

John 已定：① 卡片式命令菜单（不做环形）；② 点本回合可达格直接走，交战前可撤回；③ 右键 = 执行默认项；④「接战」窗口并入命令卡；⑤ 悬停提示跟随光标，去掉左下固定条。

### 12.1 描边线型与屏幕像素下限

`_stroke_hex` 的宽度是世界单位半宽（HexGrid.SIZE = 18）。z1 时 1 世界单位 ≈ 2.5 px，原始屏幕宽 = 2w × 2.5，0.16 只有 0.8 px，在 Web 上会断续闪烁。建议着色器取 `max(原始宽, 0.8 + 5w)`（z0 乘 0.75，z2 直接用原始值），效果图全部按这个下限画。完整参考见 `mockups/19h_stroke_reference.png`。

| 线型 | 用于状态 | 世界宽 w | z1 原始 px | 建议 px | 颜色 |
|---|---|---|---|---|---|
| 实线细描 | 1 空地 / 14 地形 / 16 / 17 | 0.16 | 0.8 | 1.6 | 白 α.85 |
| 白实线粗描 | 2 本回合可达（悬停） | 0.24 | 1.2 | 2.0 | 白 |
| 长虚线（每边 3 段） | 3 / 3′ 走不到 | 0.20 | 1.0 | 1.8 | paper0 α.7 |
| 点线（每边 10 点） | 4 不可达 / 5 不可通行 + 45° 斜纹 | 0.16 | 0.8 | 1.6 | ink4 #A39482 |
| 点划线 | 8 中立势力 | 0.16 | 0.8 | 1.6 | 势力主色 α.8 |
| 朱粗线 + 内侧 45° 斜纹 α.25 | 9 可攻击 | 0.32 | 1.6 | 2.4 | #C44A3A |
| 朱实线 | 9b 先移动再打 | 0.24 | 1.2 | 2.0 | #C44A3A |
| 短虚线（每边 6 段） | 10 打不到 | 0.16 | 0.8 | 1.6 | #C44A3A α.7 |
| 金双线（外 0.12 + 内 0.08） | 11 己方还能动 | 0.12 | 0.6 | 1.4 | gold_l |
| 单线细描 | 12 己方已行动 | 0.10 | 0.5 | 1.3 | gold α.5 |
| 城垛（齿外凸）+ 金内线 | 6 己方城 | 0.22 | 1.1 | 1.9 | 朱 #C23B2A + 金 |
| 城垛（齿朝内）+ 外沿朱细线 | 7 敌城 | 0.22 | 1.1 | 1.9 | 夏 #6B3E8E / 辽 #24467F |
| 河边加粗 | 13 河 | 0.30 | 1.5 | 2.3 | 天青 tianqing_l |
| 金粗边 + 呼吸光 | 18 引导格 | 0.42 | 2.1 | 2.9 | #E7C98A |

所有描边下面垫一道 `#14211F` α.38、宽 +1.6 px 的暗边，保证在亮黄土和草地上都看得清。色弱验收：红绿色弱下 2（绿填）与 9（朱边）颜色接近，靠形状（白粗描 + 路径 / 斜纹）、光标（靴 / 准星、剑）和首行动词（移动 / 攻击）区分；19c 的色弱版里朱边在黄土上明显变弱，斜纹和暗边是主要线索。

### 12.2 命令卡（MenuCard，宽 232）

结构从上到下：表头（势力徽 + `MenuTitleLabel` 名称 · 地形，`MenuSubLabel` 状态行）→ 敌方卡才有的预计战果区 `MenuForecast`（敌在上、我在下，条上浅色段 = 损失区间，`ForecastGoodLabel` / `ForecastBadLabel`）→ 命令行。命令行高 36（`MenuRow`），默认项用 `MenuRowDefault`（左侧金条 + 焦点底，字 gold_l），灰显带原因的行高 48（`MenuRowReason`，第二行 `MenuReasonLabel` 13px 写“电量不足：需 4，剩 2”）。行左是编号 1–9（13px），可执行命令用数字键；信息行（战斗明细 V、打开城池 C、查看详情 V）和取消（Esc）用字母键，键帽 `Keycap` / `KeycapActive`（默认项）。卡片出现在目标格右侧 24px，放不下依次翻到左 → 下 → 上；卡与格心之间画 1px 鎏金引线（`menu_leader`，Line2D TILE）。

| 组件 | 尺寸 | 切片 L,T,R,B | 内容边距 | Godot 用法 |
|---|---|---|---|---|
| `menu_card` | 64×64 | 14,14,14,16 | 8,8,8,10 | PanelContainer 变体 `MenuCard` |
| `menu_row_normal` | 160×36 | 10,8,10,8 | 10,4,10,4 | `MenuRow`（Button）normal，透明 + 底部 1px 金线 α.16 |
| `menu_row_hover` | 160×36 | 10,8,10,8 | 10,4,10,4 | `MenuRow` hover / focus |
| `menu_row_pressed` | 160×36 | 10,8,10,8 | 10,4,10,4 | `MenuRow` pressed |
| `menu_row_disabled` | 160×36 | 10,8,10,8 | 10,4,10,4 | `MenuRow` disabled（字 ink4，图标换 `*_disabled`） |
| `menu_row_default` | 160×36 | 10,8,10,8 | 10,4,10,4 | `MenuRowDefault` normal |
| `menu_row_reason` | 160×48 | 10,8,10,8 | 10,4,10,4 | PanelContainer 变体 `MenuRowReason` |
| `menu_forecast` | 200×52 | 8,8,8,8 | 10,6,10,6 | `MenuForecast` |
| `keycap_normal` | 18×18 | 5,5,5,6 | 4,1,4,2 | `Keycap` |
| `keycap_active` | 18×18 | 5,5,5,6 | 4,1,4,2 | `KeycapActive` |
| `tooltip_map` | 48×48 | 10,10,10,12 | 12,8,12,10 | `TooltipMap`（地图悬停提示） |
| `menu_leader` | 8×3 | — | — | Line2D.texture，texture_mode = TILE，width = 3 |

```gdscript
# 命令卡（主题已含全部变体）
var card := PanelContainer.new(); card.theme_type_variation = &"MenuCard"; card.custom_minimum_size.x = 232
var row := Button.new(); row.theme_type_variation = &"MenuRow"          # 默认项用 &"MenuRowDefault"
row.icon = preload("res://ui/icons/png/act_ranged.png")                 # 禁用时换 act_ranged_disabled.png（modulate 不能去饱和）
var key := PanelContainer.new(); key.theme_type_variation = &"Keycap"
key.size_flags_vertical = Control.SIZE_SHRINK_CENTER                    # 否则在 HBox 里会被拉高
var kl := Label.new(); kl.theme_type_variation = &"KeycapLabel"; kl.text = "Enter"; key.add_child(kl)
# 引线
var ln := Line2D.new(); ln.texture = preload("res://ui/components/png/menu_leader.png")
ln.texture_mode = Line2D.LINE_TEXTURE_TILE; ln.width = 3; ln.points = [card_anchor, hex_center_screen]
```

### 12.3 悬停提示（TooltipMap，跟随光标）

提示框贴在光标右下 (+18, +22)，碰到屏幕边就翻到左侧 / 上方。首行 15px paper1（动词用 gold_l，攻击类用 `#F2A08F`）；停 600 ms 或按住 Shift 展开明细，明细 13px tianqing_l，每行一条。左下固定条去掉。首行文案的数字必须由代码填（如“花 2 步，剩 0”），不要写死“花 1 步，剩 1”。

### 12.4 光标（32×32，@2x 64×64，`ui/cursors/`）

| 文件 | 用途 | 热点 @1x | 热点 @2x |
|---|---|---|---|
| `cur_default` | 默认（毛笔尖箭头） | (2, 2) | (4, 4) |
| `cur_select` | 手：己方单位 | (10, 2) | (20, 4) |
| `cur_move` | 靴：可达格 | (16, 28) | (32, 56) |
| `cur_move_far` | 靴加沙漏：本月走不到 / 多回合 | (16, 28) | (32, 56) |
| `cur_attack` | 剑：近战可攻击 | (4, 4) | (8, 8) |
| `cur_ranged` | 准星：远程可攻击 | (16, 16) | (32, 32) |
| `cur_no` | 禁止（墨灰，不用红） | (16, 16) | (32, 32) |
| `cur_inspect` | 放大镜：敌城 / 打不到的敌军 | (12, 12) | (24, 24) |
| `cur_city` | 城门：己方城 | (16, 24) | (32, 48) |
| `cur_drag` | 抓手：中键拖动 | (16, 16) | (32, 32) |

`Input.set_custom_mouse_cursor(load("res://ui/cursors/png/cur_move.png"), Input.CURSOR_ARROW, Vector2(16, 28))`。Web 导出时浏览器按 CSS 像素显示自定义光标，64px 版在高分屏上会显示成两倍大，所以 Web 一律用 32px 版；桌面版可按 `DisplayServer.screen_get_scale()` ≥ 2 换 @2x 并把热点 ×2。完整清单 `ui/cursors/hotspots.json` / `hotspots.md`。

### 12.5 命令图标与格心角标

命令图标 `icons/*/act_*`（24，@2x 48；每个另有 `act_*_disabled` 预渲染灰版），格心角标 `components/*/hb_*`（16，@2x 32，带 1px 深色描边，黄土和草地上都清楚）。总表见 `mockups/19g_cursor_icon_sheet.png`。角标位置：格上无单位时在格心，有单位时下移 12px；城、河、关隘、资源放右上。

**跳过（本次不做）**：`act_build_fort` — A14 修筑堡寨：出现条件是厢军或民夫，方案把它和民夫的“建改良”一起放到 M3；按“民夫相关先不做”跳过；`act_capture` — A15 占领：占城规则 M3 才上线；按“占领相关先不做”跳过；`hb_fog` — B07 战争迷雾问号：迷雾 M2，按“迷雾相关先不做”跳过；状态 15 / 15b（战争迷雾，M2）。

### 12.6 效果图与验收

`19a_hover_states`（状态表：正常 / 灰度 / 红绿色弱）、`19b_hover_move`、`19c_hover_attack`、`19d_menu_enemy`、`19e_menu_self`、`19f_tutorial_step2`、`19g_cursor_icon_sheet`、`19h_stroke_reference`（参考）。底图是 93d2cf5 开局第 1 回合延州 z1 的真实截图（`src/mockup_bg/map_t1_z1*.png`），数值来自 `CombatResolver.assess()` 实算。每张在 `mockups/cvd/` 下另有 `_gray`、`_deutan`、`_protan`、`_tritan` 四版（Machado 2009，linear RGB）。QA 报告：`qa/map_qa.md`；Godot 4.5.1 加载截图：`qa/map_theme_godot.png`。


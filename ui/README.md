# 《我带着AI穿越大宋》UI 套件

Godot 4 Web（Compatibility 渲染器）· 基础分辨率 1280×720 · 支持 HiDPI · 只有中文 · 宋式矢量风格（不是像素风）

## 目录结构

```
ui/
├─ theme.tres            Godot 4 主题，引用 @1x PNG，所有 Godot 4.x 版本可用（推荐）
├─ theme_hidpi.tres      同一套主题，改为引用 SVG，需按 DPITexture 导入（见下文 HiDPI 部分，要求 Godot 4.6 及以上）
├─ hidpi_theme.gd        HiDPI 自动加载脚本：高分屏下把主题贴图换成 @2x PNG，逻辑尺寸不变
├─ style_guide.md        风格指南：色板、势力色、字体与授权、字号、间距、9-slice 表、图标、状态、豆沙包表情
├─ components/svg|png    UI 组件（面板、按钮、进度条、旗帜、头像框、豆沙包立绘等），提供 SVG 源、@1x 与 @2x PNG
├─ cursors/svg|png       大地图光标 C01–C10（32 与 @2x 64），热点清单 hotspots.json / hotspots.md
├─ icons/svg|png         原创图标（资源、天气、科技分支、兵种、建筑、改良、界面图标、43 项科技、4 个豆沙包固件、8 条政令），提供 SVG 源、@1x 与 @2x PNG
├─ fonts/                子集化后的字体（思源宋体、霞鹜文楷、马善政）及 OFL 授权文本
├─ mockups/              1280×720 效果图 01–19（科技系统 v1.0、地块交互见下文）；mockups/cvd/ 为灰度与色弱模拟验收版
├─ demo/                 theme_demo.tscn 演示场景，展示所有主题变体
├─ qa/                   在 Godot 4.5.1 中实际运行的截图
├─ art/                  效果图用素材：标题主视觉、小地图示例、存档缩略图、格物志插图（art/illust/）
│  └─ portraits/         人物立绘与头像（另有专项重绘，不由本套件脚本生成）
├─ src/                  生成脚本（Python），可完整重建上述资源
└─ ref/                  参考图（未改动）
```

## 导入 Godot

1. 把整个 `ui/` 文件夹复制到工程中，路径为 `res://ui/`。主题内全部使用 `res://ui/...` 路径；若放在别处，请全局替换 `res://ui/`。`src/`、`mockups/`、`ref/` 和 `qa/` 可以不复制，复制了也可在导出预设中排除。
2. 项目设置：
   - `display/window/size/viewport_width=1280`，`viewport_height=720`
   - `display/window/stretch/mode="canvas_items"`，`aspect="expand"`
   - `gui/theme/custom="res://ui/theme.tres"`；也可以只在根 Control 节点上设置 `theme`
   - 渲染器设为 `gl_compatibility`
3. PNG 默认导入方式（Lossless）即可。若需要缩放显示，建议在项目设置中开启 `rendering/textures/canvas_textures/default_texture_filter = Linear`；`Linear Mipmap` 可选，适合需要缩小显示的情况。
4. 字体：TTF 会自动导入为 FontFile，主题已设置默认字体（思源宋体 15px）。建议在 FontFile 导入设置中开启 `Multichannel SDF = off`、`Oversampling` 保持默认，以及 `Generate Mipmaps = on`。
5. 使用主题变体：选中节点后，在 `Theme Type Variation` 中填写变体名：
   - **Button**：`PrimaryButton`（朱红主按钮）、`EndTurnButton` / `EndTurnAlertButton`、`ListItemButton`（存档槽、队列项，需开启 `toggle_mode`）、`RoundButton` / `CloseButton`（只显示图标，图标用 `components/png/btn_round_*`、`btn_close_*`，可配合 TextureButton 使用）
   - **PanelContainer**：`PaperPanel`、`PlainPanel`、`InkPanel`、`ScrollPanel`（豆沙包对白）、`TopBar`、`DateCartouche`、`HeaderRibbon`、`NamePlate`、`MinimapFrame`、`TechNode<状态>`（Locked / Noprereq / Available / Queued / Designing / Nopower / Blueprint / Trial / Blocked / Done，见 style_guide §9.1；`TechNodeResearching` 仅作兼容别名）、科技系统组件变体（`Slot*`、`BlueprintCard`、`Firmware*`、`FacilityCard*`、`EdictRow*`、`TalentCard*`、`Chain*`、`Pill*`、`BubblePaper`/`BubbleDSB`、`IllustFrame`、`ToastBlueprint`、`TimelineTrack`、`StageCurrent`、`WarnStrip`、`RowHover`）、`CityBannerSong/Liao/Xia/Tubo/Dali/Jiaozhi/Goryeo/Rebel`
   - **Button（科技节点，带悬停）**：`TechNodeButton<状态>`，状态同上。
   - **Label**：`H1Label`、`H2Label`、`H3Label`、`BodyLabel`、`SmallLabel`、`CaptionLabel`、`NumberLabel`、`BrushLabel`、`DisplayLabel`、`HudLabel`、`HudNumberLabel`、`HudMutedLabel`、`PowerLabel`、`GoldLabel`、`BannerLabel`
   - **ProgressBar**：`PowerBar`、`FoodBar`、`GoldBar`、`CraftBar`、`HPBar`、`HPBarMid`、`HPBarLow`、`XPBar`、`OrderBar`。以上每种都有 `…Paper` 版本，用于宣纸底；使用时请关闭 `show_percentage`。科技节点底部分段进度条用 `NodeBarDesign`（设计，青蓝）、`NodeBarTrial`（试制，赭）、`NodeBarNoPower`（停电），试制受阻的匠力条用 `CraftBarBlocked`。
   - 默认类型已设置好样式：Button、Label、RichTextLabel、LineEdit、TextEdit、TabBar、TabContainer、HSlider、CheckBox（含单选样式）、V/HScrollBar、HSeparator、OptionButton、MenuButton、ItemList、Tree、PopupMenu、TooltipPanel、Window/AcceptDialog。
6. 运行 `res://ui/demo/theme_demo.tscn` 可查看效果，截图见 `qa/godot451_theme_1x.png`；科技系统新增变体在 4.5.1 中的加载截图见 `qa/godot451_theme_v2_tech_variations.png`。
7. 9-slice 参数已写入主题。若要手工新建 StyleBoxTexture，切片值以 `style_guide.md` §5 为准，填 @1x 数值。

## HiDPI

- **推荐（Godot 4.x 全版本，已在 4.5.1 验证）**：主题使用 `theme.tres`，再把 `hidpi_theme.gd` 加为 Autoload。当有效缩放 ≥ 1.5（窗口尺寸÷1280×720，或屏幕缩放）时，脚本会把主题中的贴图替换为 `@2x` 版本，并调用 `set_size_override` 保持 @1x 的逻辑尺寸，因此切片和布局不变，只有清晰度翻倍。对照截图见 `qa/godot451_theme_2x_hidpi_script.png`。
- **SVG / DPITexture（Godot 4.6 及以上）**：把 `components/svg`、`icons/svg` 的导入器改为 DPITexture，主题换成 `theme_hidpi.tres`，可在任意缩放下保持矢量清晰。注意：在 **4.5.1** 下实测，9-slice 在 2 倍缩放时切片会被放大，导致边角错位（见 `qa/godot451_dpitexture_2x_BROKEN.png`），因此 4.5 请不要使用此方案。4.6 的修复未经本套件实测。
- 图标和头像（TextureRect）：直接使用 `@2x.png`，并设置 `expand_mode = Ignore Size`、`custom_minimum_size` 为 @1x 尺寸；也可以交给上面的脚本处理。

## 重新生成

依赖：Python 3、fontTools、Pillow、`rsvg-convert`（librsvg2-bin）、Playwright 与 Chrome（仅生成效果图时需要）。

```
cd ui/src
python3 subset_fonts.py                 # 用 /workspace/tt/fonts 下的原版字体生成子集，新增文案用字可加入脚本中的额外字符表
python3 build_assets.py components      # 也可以是 icons 或 portraits；生成 SVG、@1x 和 @2x PNG
python3 build_v3.py                     # 只重建格物图 v3 组件
python3 theme_gen.py                    # 从组件注册表生成 theme.tres 和 theme_hidpi.tres
python3 gen_style_guide.py              # 生成 style_guide.md
python3 build_map.py                    # 只重建地块交互：act_* 图标（含 _disabled）、hb_* 角标、命令卡组件、光标与热点清单
python3 mock_19_tile.py; python3 mock_19_sheets.py   # 地块交互效果图 19a–19h
python3 cvd.py                          # mockups/19*.png → mockups/cvd/*_gray|_deutan|_protan|_tritan.png
python3 qa_map.py                       # 尺寸、@2x 对应、对比度、主题接线 → qa/map_qa.md
python3 mock_01_hud.py … mock_16_hud.py; python3 mock_08_sheets.py; python3 mock_17_sheets_v2.py   # 生成效果图（HTML 源保存在 src/mockups_html/）
```

调色板、势力色和分支色都定义在 `src/kitlib.py`。组件的尺寸和切片定义在 `src/components.py`，图标在 `src/icons.py`，科技数据在 `src/techdata.py`（与《科技系统重设计》v1.0 一致：43 项科技、固件、政令、新建筑和第 52 回合存档），科技系统新增组件在 `src/components_v2.py`，效果图共用的绘制函数在 `src/v2common.py`。

## 字体来源（均为 SIL OFL 1.1）

- 思源宋体 Noto Serif SC：github.com/google/fonts `ofl/notoserifsc`，可变字体，实例化为 400 和 700 两个字重
- 霞鹜文楷 LXGW WenKai v1.520：github.com/lxgw/LxgwWenKai
- 马善政 Ma Shan Zheng：github.com/google/fonts `ofl/mashanzheng`

子集包含 GB2312 全部汉字，以及设计文档中出现的字，以及《科技系统重设计》中出现的字，共 7574 字。

## 科技系统 v1.0（《科技系统重设计》v1.0，GDD v0.2）

流程：设计（耗电，豆沙包出图，青蓝）→ 试制（匠力 + 材料 + 实践，赭色）→ 推广。分支为 农 / 工 / 械 / 商 / 军 / 电 / 终，共 43 项科技，分 6 个阶段、3 个时代。效果图统一使用第 52 回合存档（庆历四年四月）。

| 效果图 | 内容 |
|---|---|
| `mockups/04_tech_tree_v3.png`（= `04_tech_tree.png`） | 格物图 v3 · 默认聚焦视图（左栏三问 + 科技树） |
| `mockups/04e_tech_target_path.png` | 格物图 v3 · 水轮发电机设为目标：目标路径 + 360px 抽屉 |
| `mockups/04b_tech_tree_overview_v2.png` | 格物图 v3 · 总览（43 个图标块，筛选只在此页） |
| `mockups/04f_tech_tutorial_step1.png` | 格物图 v3 · 新手引导第 1 步 |
| `mockups/04c_tech_node_states_v2.png` | 格物图 v3 · 8 态 × 常态/悬停/灰度，5 种连线，8 个主按钮动词 |
| `mockups/04g_tech_components.png` | 格物图 v3 · 组件（建议卡三种、还缺条目、目标卡、主按钮、设为目标链接、角标） |
| `mockups/04d_tech_detail_drawer.png` | 科技详情抽屉 |
| `mockups/07_power_console_v2.png` | 豆沙包控制台 · 电力分配 |
| `mockups/07b_power_facilities.png` | 控制台 · 发电设施 |
| `mockups/11_workshop.png` | 匠作院（试制槽、图纸库） |
| `mockups/12_industry_chain.png` | 百工图（产业链） |
| `mockups/13_talent.png` | 贤才录 |
| `mockups/14_court_reform.png` | 朝堂 · 制度改革（政令） |
| `mockups/15_codex_tech.png` | 格物志 · 科技条目 |
| `mockups/16_hud_research_popup.png` | HUD 研究窗与图纸、试制完成弹窗 |
| `mockups/17_tech_icon_sheet.png` | 43 项科技、固件、政令、分支、新建筑图标 |
| `mockups/18_component_sheet_v2.png` | 科技系统新增组件 |

- 分支：新增“械”（机械动力，`branch_xie`）。原“政”分支已取消，其制度类内容改为 8 条朝堂政令（`edict_*`），原石青徽章改作 `badge_court`。
- 资源：铅已删除，不再有铅图标或铅库存；E06 只消耗铜 10、硫 10，正式名按设计文档保留。
- 人物头像：正式立绘与头像放在 `art/portraits/`（另有专项重绘）。`components/` 中的 `char_*` 是效果图占位图。
- 标题主视觉 `art/title_keyart*` 与 `mockups/06_title_screen*` 不在本次科技系统更新范围内。

### 格物图 v3（《格物图UX重做》）

按 `设计/格物图UX重做.md` 重做格物图：左栏固定回答三个问题（① 正在做 ② 豆沙包建议 / 目标卡 ③ 还缺），右侧默认是聚焦视图（已完成的时代折叠成竖条）。节点 8 态用“形状 + 图标 + 状态字”三重编码，颜色只做辅助；每个节点只有一个主按钮动词。细则、切片值和主题变体见 `style_guide.md` §9.5。

- 组件定义在 `src/components_v3.py`（`node3_*`、`tile3_*`、`st3_*`、`req3_*`、`qbadge3_*`、`badge3_target`、`qnum3_*`、`line3_*`、`card_suggest3*`、`card_target3`、`row_missing3`、`row_ok3`、`row_now3*`、`btn_verb3*`、`era_fold3`、`tut_spotlight3`、`tut_arrow3`），用 `python3 build_v3.py` 只重建这一组（72 个）。
- 主题变体：`TechNode3<状态>`、`TechNode3Button<状态>`、`VerbButton` / `VerbButtonDesign` / `VerbButtonCraft`、`TargetLink`、`SuggestCard*`、`TargetCard`、`MissingRow`、`OkRow`、`NowRow*`、`LeftColumnPanel`、`EraFoldBar`、`TutorialSpotlight`、`StateText*`。已在 Godot 4.5.1 中加载（356 个样式盒，0 个空贴图），截图见 `qa/godot451_theme_v3_gewutu.png`。
- 效果图脚本：`mock_04_v3.py`（04 v3 / 04e / 04f，并复制为 `04_tech_tree.png`）、`mock_04b_v2.py`、`mock_04c_v2.py`、`mock_04g_components.py`；共用绘制代码在 `src/v3common.py`。
- 存档调整：实践门槛 K03 改为 3/3、E05 改为 6/6（水磨坊已运行 6 回合，与重做文档 §4.2 一致），11 匠作院、04c/04d、16 等受影响的效果图已重新生成。
- 字体：思源宋体与霞鹜文楷子集都包含 ● ○ ◎ ✓ ① ② ③ ▶ ›；✗ ⚡ ◀ 不在子集中，改用 SVG 图标。

## 大地图地块交互（《地块交互方案》，对照 93d2cf5）

按 `设计/地块交互方案.md` §7 出图。John 已定：卡片式命令菜单、点可达格直接走（交战前可撤回）、右键 = 默认项、「接战」并入卡片、悬停提示跟随光标。细则（线型与像素下限、命令卡结构、光标热点、Godot 片段）见 `style_guide.md` §12。

- 命令图标：`icons/svg|png/act_*`，16 个（A01–A13、A16 及 A01b / A10b），24 与 @2x 48，另有 `act_*_disabled` 灰版。定义在 `src/icons_act.py`。
- 格心角标：`components/svg|png/hb_*`，16 个（B01–B15 及 B01b / B03b，除 B07），16 与 @2x 32。命令卡组件 `menu_card`、`menu_row_{normal,hover,pressed,disabled,default}`、`menu_row_reason`、`menu_forecast`、`keycap_{normal,active}`、`tooltip_map`、`menu_leader`。定义在 `src/components_map.py`，已写进 `theme.tres` / `theme_hidpi.tres`（变体 `MenuCard`、`MenuRow`、`MenuRowDefault`、`MenuRowReason`、`MenuForecast`、`Keycap`、`KeycapActive`、`TooltipMap` 及 8 个 Label 变体），Godot 4.5.1 加载截图 `qa/map_theme_godot.png`。
- 光标：`cursors/`，10 个，定义在 `src/cursors.py`；Web 导出只用 32px 版（浏览器不按 DPI 缩放自定义光标）。
- 效果图：`19a_hover_states`、`19b_hover_move`、`19c_hover_attack`、`19d_menu_enemy`、`19e_menu_self`、`19f_tutorial_step2`、`19g_cursor_icon_sheet`、`19h_stroke_reference`，均有 @2x；底图为 93d2cf5 开局第 1 回合真实截图（`src/mockup_bg/`），共用代码 `src/mapcommon.py`。
- 跳过（本次不做）：A14 `act_build_fort`（民夫 / M3）、A15 `act_capture`（占领 / M3）、B07 `hb_fog` 与状态 15 / 15b（迷雾 / M2）。

### 已取代的文件

- `mockups/04_tech_tree.png`：现与 `04_tech_tree_v3.png` 相同（格物图 v3）。`mockups/07_power_console.png` 与 `07_power_console_v2.png` 相同。保留旧文件名方便引用。
- `mockups/04_tech_tree_v2.png`、`04b_tech_tree_overview.png`、`04c_tech_node_states.png`（v1 十态）：已被格物图 v3 的 `04_tech_tree_v3`、`04b_tech_tree_overview_v2`、`04c_tech_node_states_v2` 取代，仅保留作对照。
- v0 的科技图标、`branch_zheng`、`res_lead`，以及 `techdata_v1.py`、`mock_04_tech_v1*.py`、`mock_07_console_v1.py`：已移到 `../_retired_ui_assets/`，不再随套件分发。
- 组件 `tech_node_*`（v0 四态节点）保留文件，新界面请改用 `node2_*` 与 `TechNode<状态>`。

# RadialMenu Tool

一个为 REAPER 设计的轮盘菜单工具，使用 Lua 和 ReaImGui 开发。

---

## 📖 项目简介

RadialMenu Tool 是一个模块化的轮盘菜单系统，旨在为 REAPER 提供快速、直观的操作界面。通过圆形布局的扇区菜单，用户可以快速访问常用的 Actions、FX 插件和脚本。

### 主要特性

- 🎨 **可视化轮盘界面** - 圆形扇区布局，直观易用
- ⚙️ **高度可配置** - 通过 JSON 配置文件自定义菜单内容
- 🎯 **智能上下文检测** - 自动判断 FX 挂载到 Track 还是 Item
- 🔍 **模糊搜索** - 快速查找 Actions 和 FX
- 🚀 **模块化架构** - GUI/Logic/Data 清晰分离，易于维护和扩展

---

## 📁 项目结构

```
RadialMenu_Tool/
├── index.lua                    # 脚本入口点
├── config.json                  # 用户配置文件
├── src/                         # 源代码
│   ├── config_manager.lua       # 配置文件管理
│   ├── main_runtime.lua         # 主运行时循环
│   ├── main_settings.lua        # 设置编辑器
│   ├── gui/                     # GUI 模块
│   │   ├── wheel.lua           # 轮盘绘制
│   │   ├── list_view.lua       # 子菜单列表
│   │   └── styles.lua          # 样式定义
│   └── logic/                   # 业务逻辑
│       ├── actions.lua         # Reaper Actions 执行
│       ├── fx_engine.lua       # FX 智能挂载引擎
│       └── search.lua          # 模糊搜索算法
└── utils/                       # 工具函数
    ├── math_utils.lua          # 几何数学计算
    ├── im_utils.lua            # ImGui 辅助函数
    └── json.lua                # JSON 编码/解码
```

---

## 🛠️ 技术栈

- **语言**: Lua
- **UI 框架**: ReaImGui
- **API**: REAPER Lua API
- **数据格式**: JSON

---

## 📋 依赖要求

- REAPER v6.0 或更高版本
- **ReaImGui 扩展**（必需） - 从 ReaPack 安装

---

## 🚀 安装与使用

### 安装步骤

1. **安装 ReaImGui 扩展**
   - 打开 REAPER
   - 进入 Extensions > ReaPack > Browse Packages
   - 搜索 "ReaImGui" 并安装

2. **复制脚本文件**
   - 将整个 `RadialMenu_Tool` 文件夹复制到 REAPER Scripts 目录
   - 通常位于：`%APPDATA%\REAPER\Scripts\` (Windows)

3. **加载脚本**
   - 在 REAPER 中，打开 Actions > Show action list
   - 点击 "New action" > "Load ReaScript..."
   - 选择 `RadialMenu_Tool/index.lua`

4. **（可选）设置快捷键**
   - 在 Action List 中找到刚加载的脚本
   - 右键选择 "Set key shortcut"
   - 设置你喜欢的快捷键（例如：`Shift+Space`）

### 基本使用

1. 运行脚本，轮盘菜单将出现
2. 鼠标悬停在扇区上高亮显示
3. 点击扇区查看子菜单
4. 点击子菜单项执行对应的动作

---

## ⚙️ 配置说明

### config.json 结构

```json
{
  "version": "1.0.0",
  "menu": {
    "outer_radius": 200,       // 轮盘外半径
    "inner_radius": 50,        // 中心圆半径
    "sector_border_width": 2,  // 扇区边框宽度
    "hover_brightness": 1.3,   // 悬停时亮度增加
    "animation_speed": 0.2     // 动画速度
  },
  "colors": {
    "background": [30, 30, 30, 240],
    "center_circle": [50, 50, 50, 255],
    "border": [100, 100, 100, 200],
    "hover_overlay": [255, 255, 255, 50],
    "text": [255, 255, 255, 255]
  },
  "sectors": [
    {
      "id": 1,
      "name": "Actions",
      "icon": "⚡",
      "color": [70, 130, 180, 200],
      "slots": [...]
    }
  ]
}
```

### 插槽类型

#### Action（执行 REAPER 命令）
```json
{
  "type": "action",
  "name": "Split Items",
  "data": {
    "command_id": 40012
  },
  "description": "在光标位置分割 Items"
}
```

#### FX（添加效果器）
```json
{
  "type": "fx",
  "name": "ReaEQ",
  "data": {
    "fx_name": "ReaEQ"
  },
  "description": "添加均衡器"
}
```

#### Script（执行脚本）
```json
{
  "type": "script",
  "name": "Custom Script",
  "data": {
    "script_path": "path/to/script.lua"
  },
  "description": "执行自定义脚本"
}
```

---

## 🔧 开发状态

**当前版本：脚手架阶段**

本项目目前处于脚手架阶段。所有文件结构已创建，包含详细的 TODO 注释和函数签名存根，但核心功能尚未实现。

### 完成情况

- ✅ 项目结构设计
- ✅ 文件和文件夹创建
- ✅ 函数接口定义
- ✅ 配置文件示例
- ⏳ Phase 1: Infrastructure & Data（待实现）
- ⏳ Phase 2: The Wheel (UI & Math)（待实现）
- ⏳ Phase 3: Submenu & Interaction（待实现）
- ⏳ Phase 4: Logic Implementation（待实现）

详细的开发路线图请查看 [TODO.md](TODO.md)。

---

## 🏗️ 架构设计

### 模块化设计原则

本项目遵循严格的模块化设计，分为三个主要层次：

1. **GUI 层** (`src/gui/`)
   - 负责所有视觉呈现
   - 不包含业务逻辑
   - 使用 ImGui 绘制界面

2. **Logic 层** (`src/logic/`)
   - 包含所有业务逻辑
   - Actions 执行、FX 挂载、搜索等
   - 与 REAPER API 交互

3. **Data 层** (`src/config_manager.lua`)
   - 配置文件的读写
   - 数据验证和默认值管理

### 工具函数层 (`utils/`)
- 提供通用的数学、ImGui、JSON 工具
- 可在各模块中复用

---

## 🤝 贡献指南

欢迎贡献！由于项目处于早期阶段，以下是开发建议：

1. **按阶段开发** - 遵循 TODO.md 中的开发阶段
2. **保持模块化** - 确保 GUI/Logic/Data 分离
3. **添加注释** - 所有函数都应有清晰的注释
4. **测试功能** - 每个功能实现后都要测试

### 开发环境设置

1. 安装 REAPER 和 ReaImGui
2. 克隆或下载本项目
3. 在 REAPER 中加载 `index.lua`
4. 开始实现 TODO 标记的功能

---

## 📚 参考资源

- [REAPER Lua API Documentation](https://www.reaper.fm/sdk/reascript/reascripthelp.html)
- [ReaImGui Documentation](https://github.com/cfillion/reaimgui)
- [Lua 5.4 Manual](https://www.lua.org/manual/5.4/)

---

## 📝 许可证

MIT License

---

## 👤 作者

Lee

---

## 📞 联系方式

如有问题或建议，请通过以下方式联系：

- GitHub Issues（如果有仓库链接）
- REAPER 论坛

---

## 📅 更新日志

### v1.0.0 (脚手架) - 2024-12-05
- ✅ 创建项目结构
- ✅ 定义所有模块接口
- ✅ 编写 TODO 注释和函数存根
- ✅ 创建配置文件示例
- ✅ 编写文档（README, TODO）

---

**注意**：本项目目前仅为脚手架，核心功能尚未实现。请参考 [TODO.md](TODO.md) 了解开发计划。

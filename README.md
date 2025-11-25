# Lee Scripts 脚本库

REAPER Lua脚本集合，按功能分类管理。

## 📁 目录结构

```
Lee_Scripts/
├── Items/          # Items相关操作（分割、裁剪、fade等）
├── Tracks/         # Tracks相关操作
├── Takes/          # Takes相关操作
├── Markers/        # Markers相关操作（工作站+功能模块）
│   └── MarkerFunctions/  # Marker功能模块目录
├── Workflow/       # 工作流自动化脚本
├── Utilities/      # 工具类脚本
├── Main/           # 主要工作流脚本
├── test/           # 测试脚本（验证后移至正式目录）
│   └── Archive/    # 归档脚本（暂时不使用，后续有需要再用）
└── Backup/         # 备份文件
```

## 📝 命名规范

**格式：** `Lee_[分类] - [功能描述].lua`

### 分类前缀

- `Lee_Items` - Items操作（分割、裁剪、fade、移动等）
- `Lee_Tracks` - Tracks操作（创建、删除、路由等）
- `Lee_Takes` - Takes操作（标记、切换、编辑等）
- `Lee_Markers` - Markers操作（工作站、功能模块等）
- `Lee_Workflow` - 工作流自动化
- `Lee_Utils` - 工具类脚本
- `Lee_Main` - 主要工作流（放在Main目录）
- `Lee_Test` - 测试脚本（放在test目录）

### 示例

```
Lee_Items - Split at Time Selection.lua
Lee_Items - Add Fade In Out.lua
Lee_Tracks - Add New Track.lua
Lee_Markers - Workstation.lua
Lee_Workflow - Auto Move Item.lua
```

## 🚀 使用方法

1. 在REAPER中，通过 `Actions` → `Show action list` → `ReaScript` 加载脚本
2. 或直接将脚本添加到工具栏
3. 脚本按字母顺序排列，使用统一前缀便于查找

## 📋 脚本列表

### Items
- `Lee_Items - Split at Time Selection.lua` - 在时间选区两端进行分割
- `Lee_Items - Add Fade In Out.lua` - 给选中的items添加0.2秒fade in/out
- `Lee_Items - Trim to Time Selection.lua` - 将items裁剪到时间选区（选中items或所有重叠items）
- `Lee_Items - Implode Mono to Stereo.lua` - 将匹配的单声道items合并为立体声item

### Markers
- `Lee_Markers - Workstation.lua` - Marker工作站（模块化GUI工具）
  - Copy to Cursor - 复制最近的marker到光标处
  - Move to Cursor - 移动最近的marker到光标处
  - Create from Items - 从选中items创建markers（优化版，避免重复）
  - Delete in Time Selection - 删除时间选区内的所有markers

### Workflow
- `Lee_Workflow - Bounce Items.lua` - 渲染items或tracks（支持pre/post fader、mono/stereo/multi、tail等）

### Main
- `Lee_Main - Add New Track.lua` - 添加新轨道

## 🔄 工作流程

### 开发流程
1. **测试阶段**：在 `test/` 目录下创建和测试脚本
2. **验证通过**：功能稳定后，移至对应的正式分类目录
3. **命名规范**：使用 `Lee_[分类] - [功能描述].lua` 格式

### Marker功能添加流程
1. 在 `test/MarkerFunctions/` 创建新功能模块进行测试
2. 测试通过后，复制到 `Markers/MarkerFunctions/`
3. Marker Workstation会自动加载新功能

## 🔄 更新日志

- 2024-11-18: 添加"Implode Mono to Stereo"功能（基于rodilab脚本）
- 2024-11-18: 修复Bounce脚本的offline问题（分离offline/online操作，添加错误检查）
- 2024-11-18: 整理根目录脚本，将有用脚本移至对应分类目录
- 2024-11-18: 添加"Delete in Time Selection"功能到Marker Workstation
- 2024-11-18: 创建Markers目录，Marker Workstation正式化
- 2024-11-17: 创建分类目录结构，统一命名规范


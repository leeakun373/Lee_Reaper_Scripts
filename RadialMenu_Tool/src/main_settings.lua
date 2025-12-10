-- @description RadialMenu Tool - 设置编辑器
-- @author Lee
-- @about
--   配置编辑界面
--   允许用户可视化编辑扇区和插槽

local M = {}

-- ============================================================================
-- 模块依赖
-- ============================================================================

local config_manager = require("config_manager")
local styles = require("styles")
local wheel = require("wheel")
local math_utils = require("math_utils")
local im_utils = require("im_utils")

-- ============================================================================
-- 设置界面状态
-- ============================================================================

local ctx = nil
local config = nil
local original_config = nil  -- 原始配置（用于丢弃更改）
local is_open = false
local is_modified = false
local selected_sector_index = nil  -- 当前选中的扇区索引（1-based）
local preview_config = nil  -- 缓存的预览配置（避免每次绘制都深拷贝）

-- ============================================================================
-- Phase 4 - 初始化
-- ============================================================================

-- 初始化设置编辑器
-- @return boolean: 初始化是否成功
function M.init()
    -- 单例检查：如果设置窗口已经打开，检查上下文是否真的存在
    local settings_open = reaper.GetExtState("RadialMenu", "SettingsOpen")
    if settings_open == "1" then
        -- 如果 ExtState 是 "1"，检查上下文是否真的存在
        -- 如果 ctx 存在且有效，说明窗口确实已打开
        if ctx and reaper.ImGui_GetWindowSize then
            -- 尝试获取窗口尺寸来验证上下文是否有效
            local w, h = reaper.ImGui_GetWindowSize(ctx)
            if w and h then
                -- 窗口确实已打开
                -- -- reaper.ShowConsoleMsg("设置窗口已打开，请关闭现有窗口后再打开\n")
                return false
            end
        end
        -- 如果 ExtState 是 "1" 但上下文不存在或无效，说明窗口已关闭但 ExtState 未清除
        -- 清除 ExtState 并继续初始化
        reaper.SetExtState("RadialMenu", "SettingsOpen", "0", false)
        -- -- reaper.ShowConsoleMsg("检测到残留的 ExtState，已清除并重新初始化\n")
    end
    
    -- 检查 ReaImGui 是否可用
    if not reaper.ImGui_CreateContext then
        reaper.ShowMessageBox("错误: ReaImGui 未安装或不可用", "初始化失败", 0)
        return false
    end
    
    -- 创建 ImGui 上下文
    ctx = reaper.ImGui_CreateContext("RadialMenu_Settings", reaper.ImGui_ConfigFlags_None())
    if not ctx then
        reaper.ShowMessageBox("错误: 无法创建 ImGui 上下文", "初始化失败", 0)
        return false
    end
    
    -- 加载配置
    config = config_manager.load()
    if not config then
        reaper.ShowMessageBox("错误: 无法加载配置", "初始化失败", 0)
        return false
    end
    
    -- 深拷贝配置（用于丢弃更改）
    original_config = M.deep_copy_config(config)
    
    -- 从配置初始化样式
    styles.init_from_config(config)
    
    -- 初始化状态变量
    is_open = true
    is_modified = false
    selected_sector_index = nil
    
    -- 标记设置窗口已打开
    reaper.SetExtState("RadialMenu", "SettingsOpen", "1", false)
    
    -- reaper.ShowConsoleMsg("========================================\n")
    -- reaper.ShowConsoleMsg("设置编辑器初始化成功\n")
    -- reaper.ShowConsoleMsg("  版本: 1.0.0 (Build #001)\n")
    -- reaper.ShowConsoleMsg("========================================\n")
    
    return true
end

-- ============================================================================
-- Phase 4 - 主循环
-- ============================================================================

-- 设置编辑器主循环
function M.loop()
    if not ctx or not is_open then
        M.cleanup()
        return
    end
    
    -- 绘制设置窗口
    M.draw()
    
    -- 如果窗口打开，继续 defer
    if is_open then
        reaper.defer(M.loop)
    else
        M.cleanup()
    end
end

-- ============================================================================
-- Phase 4 - 绘制主窗口
-- ============================================================================

-- 应用主题（参考Markers Modern主题风格）
function M.apply_theme()
    -- 应用样式变量（参考 Markers Modern 主题）
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 10, 10)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 8, 8)  -- Markers Modern: {8, 8}
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 10, 6)  -- Markers Modern: {10, 6}
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4)  -- Markers Modern: 4
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 6)  -- Markers Modern: 6
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupRounding(), 4)  -- Markers Modern: 4
    
    -- 应用颜色（参考 Markers Modern 主题 - 低饱和度，耐看）
    -- 使用 0xRRGGBBAA 格式，与 Markers 保持一致
    local WINDOW_BG = 0x18181BFF  -- Zinc-900 (#18181B)
    local POPUP_BG = 0x1D1D20F0  -- 弹窗稍亮
    local BORDER = 0x27272AFF  -- 淡淡的边框 (#27272A)
    local FRAME_BG = 0x09090BFF  -- 极黑输入框 (#09090B)
    local FRAME_BG_HOVERED = 0x18181BFF  -- 悬停稍亮
    local FRAME_BG_ACTIVE = 0x202020FF  -- 激活时稍亮
    local BUTTON = 0x27272AFF  -- 默认深灰 (#27272A)
    local BUTTON_HOVERED = 0x3F3F46FF  -- 悬停变亮 (#3F3F46)
    local BUTTON_ACTIVE = 0x18181BFF  -- 点击变深
    local TEXT = 0xE4E4E7FF  -- 锌白 (#E4E4E7)
    local TEXT_DISABLED = 0xA1A1AAFF  -- 灰字 (#A1A1AA)
    local TITLE_BG = 0x18181BFF  -- 标题栏融入背景
    local TITLE_BG_ACTIVE = 0x18181BFF  -- 激活时也不变色
    
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), WINDOW_BG)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(), POPUP_BG)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), BORDER)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), FRAME_BG)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), FRAME_BG_HOVERED)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), FRAME_BG_ACTIVE)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), BUTTON)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), BUTTON_HOVERED)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), BUTTON_ACTIVE)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), TEXT)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(), TEXT_DISABLED)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), TITLE_BG)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), TITLE_BG_ACTIVE)
    
    return 13, 6  -- color_count, style_var_count
end

-- 恢复主题
function M.pop_theme(color_count, style_var_count)
    if color_count then
        reaper.ImGui_PopStyleColor(ctx, color_count)
    end
    if style_var_count then
        reaper.ImGui_PopStyleVar(ctx, style_var_count)
    end
end

-- 绘制设置编辑器主窗口
function M.draw()
    -- 应用主题
    local color_count, style_var_count = M.apply_theme()
    
    -- 设置窗口大小和位置
    reaper.ImGui_SetNextWindowSize(ctx, 1000, 700, reaper.ImGui_Cond_FirstUseEver())
    
    -- 开始窗口
    local visible, open = reaper.ImGui_Begin(ctx, "RadialMenu 设置编辑器", true, reaper.ImGui_WindowFlags_None())
    
    -- 如果窗口不可见，直接返回（不需要调用 End）
    if not visible then
        is_open = open
        M.pop_theme(color_count, style_var_count)
        return
    end
    
    -- 检查窗口是否关闭
    if not open then
        is_open = false
        reaper.ImGui_End(ctx)
        M.pop_theme(color_count, style_var_count)
        return
    end
    
    -- 绘制标题（参考Markers Modern主题风格）
    local TEXT_NORMAL = 0xE4E4E7FF  -- 锌白 (#E4E4E7)
    local TEXT_DIM = 0xA1A1AAFF  -- 灰字 (#A1A1AA)
    reaper.ImGui_TextColored(ctx, TEXT_NORMAL, "RadialMenu 设置编辑器")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_TextColored(ctx, TEXT_DIM, string.format("(%d 个扇区)", #config.sectors))
    
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- 绘制底部操作栏（在内容之前，使用 SameLine 布局）
    M.draw_action_bar()
    
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- 使用表格创建 2 列布局
    if reaper.ImGui_BeginTable(ctx, "##MainLayout", 2, 
        reaper.ImGui_TableFlags_Resizable() | reaper.ImGui_TableFlags_BordersInnerV(), -1, -1) then
        
        -- 左侧列：预览面板
        reaper.ImGui_TableNextColumn(ctx)
        M.draw_preview_panel()
        
        -- 右侧列：编辑器面板
        reaper.ImGui_TableNextColumn(ctx)
        M.draw_editor_panel()
        
        reaper.ImGui_EndTable(ctx)
    end
    
    reaper.ImGui_End(ctx)
    
    -- 恢复主题
    M.pop_theme(color_count, style_var_count)
end

-- ============================================================================
-- Phase 4 - 左侧预览面板
-- ============================================================================

-- 绘制预览面板
function M.draw_preview_panel()
    reaper.ImGui_Text(ctx, "实时预览")
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- 创建预览区域（使用 Child 窗口）
    local preview_size = 350
    if reaper.ImGui_BeginChild(ctx, "##PreviewArea", preview_size, preview_size, 1, 
        reaper.ImGui_WindowFlags_None()) then
        
        -- 获取预览区域的中心点（Child窗口）
        -- 注意：在Child窗口内，需要使用Child窗口的坐标系统
        local preview_w, preview_h = reaper.ImGui_GetWindowSize(ctx)
        local preview_center_x_local = preview_w / 2
        local preview_center_y_local = preview_h / 2
        
        -- 获取Child窗口的屏幕坐标（用于鼠标检测）
        local preview_x, preview_y = reaper.ImGui_GetWindowPos(ctx)
        local preview_center_x_screen = preview_x + preview_center_x_local
        local preview_center_y_screen = preview_y + preview_center_y_local
        
        -- 创建或更新预览配置（每次绘制都更新，确保预览与配置同步）
        -- 使用浅拷贝避免深拷贝的性能问题
        preview_config = {
            version = config.version,
            menu = {
                outer_radius = 120,  -- 较小的预览尺寸
                inner_radius = 30,
                sector_border_width = config.menu.sector_border_width or 2,
                hover_brightness = config.menu.hover_brightness or 1.3,
                animation_speed = config.menu.animation_speed or 0.2,
                max_slots_per_sector = config.menu.max_slots_per_sector or 12
            },
            colors = config.colors,
            sectors = config.sectors  -- 直接引用，不需要深拷贝
        }
        
        -- 绘制轮盘预览（使用简化的绘制，避免 wheel.draw_wheel 的交互检测导致卡死）
        local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
        local center_x = preview_x + preview_center_x_local
        local center_y = preview_y + preview_center_y_local
        
        -- 简化预览：只绘制扇区，不进行悬停检测
        M.draw_simple_preview(draw_list, ctx, center_x, center_y, preview_config, selected_sector_index)
        
        -- 检测预览区域的鼠标点击，选择扇区
        if reaper.ImGui_IsWindowHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 0) then
            local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
            local relative_x = mouse_x - preview_center_x_screen
            local relative_y = mouse_y - preview_center_y_screen
            local distance = math_utils.distance(relative_x, relative_y, 0, 0)
            local inner_radius = preview_config.menu.inner_radius
            local outer_radius = preview_config.menu.outer_radius
            
            -- 如果点击在轮盘区域内（排除中心圆）
            if distance > inner_radius and distance <= outer_radius then
                -- 使用 math_utils 计算角度
                local angle, _ = math_utils.cartesian_to_polar(relative_x, relative_y)
                local rotation_offset = -math.pi / 2
                local sector_index = math_utils.angle_to_sector_index(angle, #config.sectors, rotation_offset)
                
                if sector_index >= 1 and sector_index <= #config.sectors then
                    selected_sector_index = sector_index
                    -- reaper.ShowConsoleMsg("选择扇区: " .. sector_index .. "\n")
                end
            end
        end
        
        reaper.ImGui_EndChild(ctx)
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- 轮盘大小调节
    reaper.ImGui_Text(ctx, "轮盘大小")
    reaper.ImGui_Spacing(ctx)
    
    -- 外半径滑块
    reaper.ImGui_Text(ctx, "外半径:")
    reaper.ImGui_SameLine(ctx)
    local outer_radius = config.menu.outer_radius or 150
    local outer_radius_changed, new_outer_radius = reaper.ImGui_SliderInt(ctx, "##OuterRadius", outer_radius, 80, 300, "%d px")
    if outer_radius_changed and new_outer_radius ~= outer_radius then
        config.menu.outer_radius = new_outer_radius
        is_modified = true
        -- 更新预览配置
        preview_config = nil
    end
    
    -- 内半径滑块
    reaper.ImGui_Text(ctx, "内半径:")
    reaper.ImGui_SameLine(ctx)
    local inner_radius = config.menu.inner_radius or 35
    local inner_radius_changed, new_inner_radius = reaper.ImGui_SliderInt(ctx, "##InnerRadius", inner_radius, 20, 100, "%d px")
    if inner_radius_changed and new_inner_radius ~= inner_radius then
        config.menu.inner_radius = new_inner_radius
        is_modified = true
        -- 更新预览配置
        preview_config = nil
    end
    
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- 扇区数量滑块
    reaper.ImGui_Text(ctx, "扇区数量")
    local sector_count = #config.sectors
    local sector_count_changed, new_count = reaper.ImGui_SliderInt(ctx, "##SectorCount", sector_count, 1, 8, "%d")
    
    if sector_count_changed and new_count ~= sector_count then
        M.adjust_sector_count(new_count)
        is_modified = true
    end
end

-- ============================================================================
-- Phase 4 - 右侧编辑器面板
-- ============================================================================

-- 绘制编辑器面板
function M.draw_editor_panel()
    if not selected_sector_index or selected_sector_index < 1 or selected_sector_index > #config.sectors then
        reaper.ImGui_TextDisabled(ctx, "请从左侧预览中选择一个扇区进行编辑")
        return
    end
    
    local sector = config.sectors[selected_sector_index]
    if not sector then
        return
    end
    
    -- 扇区基本信息编辑
    reaper.ImGui_Text(ctx, "扇区信息")
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- 名称输入框
    reaper.ImGui_Text(ctx, "名称:")
    reaper.ImGui_SameLine(ctx)
    local name_buf = sector.name or ""
    local name_changed, new_name = reaper.ImGui_InputText(ctx, "##SectorName", name_buf, 256)
    if name_changed then
        sector.name = new_name
        is_modified = true
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- 图标输入框
    reaper.ImGui_Text(ctx, "图标:")
    reaper.ImGui_SameLine(ctx)
    local icon_buf = sector.icon or ""
    local icon_changed, new_icon = reaper.ImGui_InputText(ctx, "##SectorIcon", icon_buf, 16)
    if icon_changed then
        sector.icon = new_icon
        is_modified = true
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- 颜色选择器已移除：强制执行统一的深灰色主题（Mantrika 风格）
    -- 所有扇区使用统一的灰色，不再支持自定义颜色
    
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- 插槽编辑器（紧凑表格布局）
    reaper.ImGui_Text(ctx, "插槽列表 (12 个)")
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- 设置紧凑的行高
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 4, 2)
    
    local max_slots = 12
    -- 使用表格创建紧凑的插槽列表
    if reaper.ImGui_BeginTable(ctx, "##SlotTable", 5, 
        reaper.ImGui_TableFlags_RowBg() | reaper.ImGui_TableFlags_BordersInnerH() | 
        reaper.ImGui_TableFlags_ScrollY(), -1, -1) then
        
        -- 表头
        reaper.ImGui_TableSetupColumn(ctx, "ID", reaper.ImGui_TableColumnFlags_WidthFixed(), 40, 0)
        reaper.ImGui_TableSetupColumn(ctx, "标签", reaper.ImGui_TableColumnFlags_WidthStretch(), 0, 1)
        reaper.ImGui_TableSetupColumn(ctx, "类型", reaper.ImGui_TableColumnFlags_WidthFixed(), 80, 2)
        reaper.ImGui_TableSetupColumn(ctx, "值", reaper.ImGui_TableColumnFlags_WidthStretch(), 0, 3)
        reaper.ImGui_TableSetupColumn(ctx, "操作", reaper.ImGui_TableColumnFlags_WidthFixed(), 60, 4)
        reaper.ImGui_TableSetupScrollFreeze(ctx, 0, 1)  -- 冻结表头
        reaper.ImGui_TableHeadersRow(ctx)
        
        -- 绘制所有 12 个插槽
        for i = 1, max_slots do
            reaper.ImGui_TableNextRow(ctx)
            reaper.ImGui_TableNextColumn(ctx)
            
            local slot = sector.slots and sector.slots[i] or nil
            
            -- ID 列
            reaper.ImGui_Text(ctx, tostring(i))
            
            -- 标签列
            reaper.ImGui_TableNextColumn(ctx)
            if slot then
                local name_buf = slot.name or ""
                local name_changed, new_name = reaper.ImGui_InputText(ctx, "##SlotName" .. i, name_buf, 256)
                if name_changed then
                    slot.name = new_name
                    is_modified = true
                end
            else
                reaper.ImGui_TextDisabled(ctx, "(空)")
            end
            
            -- 类型列
            reaper.ImGui_TableNextColumn(ctx)
            if slot then
                local type_options = {"action", "fx", "script"}
                local current_type = slot.type or "action"
                local current_type_display = current_type
                
                if reaper.ImGui_BeginCombo(ctx, "##SlotType" .. i, current_type_display, reaper.ImGui_ComboFlags_None()) then
                    for j, opt in ipairs(type_options) do
                        local is_selected = (opt == current_type)
                        if reaper.ImGui_Selectable(ctx, opt, is_selected, reaper.ImGui_SelectableFlags_None(), 0, 0) then
                            slot.type = opt
                            -- 重置 data 字段
                            if slot.type == "action" then
                                slot.data = {command_id = 0}
                            elseif slot.type == "fx" then
                                slot.data = {fx_name = ""}
                            elseif slot.type == "script" then
                                slot.data = {script_path = ""}
                            end
                            is_modified = true
                        end
                        if is_selected then
                            reaper.ImGui_SetItemDefaultFocus(ctx)
                        end
                    end
                    reaper.ImGui_EndCombo(ctx)
                end
            else
                reaper.ImGui_TextDisabled(ctx, "-")
            end
            
            -- 值列
            reaper.ImGui_TableNextColumn(ctx)
            if slot then
                if slot.type == "action" then
                    local cmd_id = slot.data and slot.data.command_id or 0
                    local cmd_id_changed, new_cmd_id = reaper.ImGui_InputInt(ctx, "##SlotValue" .. i, cmd_id, 1, 100)
                    if cmd_id_changed then
                        if not slot.data then slot.data = {} end
                        slot.data.command_id = new_cmd_id
                        is_modified = true
                    end
                elseif slot.type == "fx" then
                    local fx_name = slot.data and slot.data.fx_name or ""
                    local fx_name_changed, new_fx_name = reaper.ImGui_InputText(ctx, "##SlotValue" .. i, fx_name, 256)
                    if fx_name_changed then
                        if not slot.data then slot.data = {} end
                        slot.data.fx_name = new_fx_name
                        is_modified = true
                    end
                elseif slot.type == "script" then
                    local script_path = slot.data and slot.data.script_path or ""
                    local script_path_changed, new_script_path = reaper.ImGui_InputText(ctx, "##SlotValue" .. i, script_path, 512)
                    if script_path_changed then
                        if not slot.data then slot.data = {} end
                        slot.data.script_path = new_script_path
                        is_modified = true
                    end
                end
            else
                reaper.ImGui_TextDisabled(ctx, "-")
            end
            
            -- 操作列
            reaper.ImGui_TableNextColumn(ctx)
            if slot then
                if reaper.ImGui_Button(ctx, "删除##Slot" .. i, 0, 0) then
                    sector.slots[i] = nil
                    is_modified = true
                end
            else
                if reaper.ImGui_Button(ctx, "添加##Slot" .. i, 0, 0) then
                    sector.slots[i] = {
                        type = "action",
                        name = "新插槽",
                        data = {command_id = 0},
                        description = ""
                    }
                    is_modified = true
                end
            end
        end
        
        reaper.ImGui_EndTable(ctx)
    end
    
    reaper.ImGui_PopStyleVar(ctx)  -- 恢复 FramePadding
end

-- ============================================================================
-- Phase 4 - 插槽编辑
-- ============================================================================

-- 绘制单个插槽的编辑器
-- @param slot table: 插槽数据（可能为 nil）
-- @param index number: 插槽索引
-- @param sector table: 所属扇区
function M.draw_slot_editor(slot, index, sector)
    local header_text = string.format("插槽 %d", index)
    
    if not slot then
        reaper.ImGui_TextDisabled(ctx, header_text .. " (空)")
        return
    end
    
    reaper.ImGui_Text(ctx, header_text)
    reaper.ImGui_SameLine(ctx)
    
    -- 删除按钮
    if reaper.ImGui_Button(ctx, "删除##Slot" .. index, 0, 0) then
        sector.slots[index] = nil
        is_modified = true
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- 标签输入
    reaper.ImGui_Text(ctx, "  标签:")
    reaper.ImGui_SameLine(ctx)
    local name_buf = slot.name or ""
    local name_changed, new_name = reaper.ImGui_InputText(ctx, "##SlotName" .. index, name_buf, 256)
    if name_changed then
        slot.name = new_name
        is_modified = true
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- 类型下拉框
    reaper.ImGui_Text(ctx, "  类型:")
    reaper.ImGui_SameLine(ctx)
    local type_options = {"action", "fx", "script"}
    local current_type = slot.type or "action"
    local current_type_display = current_type
    
    -- 使用 BeginCombo/EndCombo
    if reaper.ImGui_BeginCombo(ctx, "##SlotType" .. index, current_type_display, reaper.ImGui_ComboFlags_None()) then
        for i, opt in ipairs(type_options) do
            local is_selected = (opt == current_type)
            if reaper.ImGui_Selectable(ctx, opt, is_selected, reaper.ImGui_SelectableFlags_None(), 0, 0) then
                slot.type = opt
                -- 重置 data 字段
                if slot.type == "action" then
                    slot.data = {command_id = 0}
                elseif slot.type == "fx" then
                    slot.data = {fx_name = ""}
                elseif slot.type == "script" then
                    slot.data = {script_path = ""}
                end
                is_modified = true
            end
            if is_selected then
                reaper.ImGui_SetItemDefaultFocus(ctx)
            end
        end
        reaper.ImGui_EndCombo(ctx)
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- 根据类型显示不同的输入字段
    if slot.type == "action" then
        reaper.ImGui_Text(ctx, "  Command ID:")
        reaper.ImGui_SameLine(ctx)
        local cmd_id = slot.data and slot.data.command_id or 0
        local cmd_id_changed, new_cmd_id = reaper.ImGui_InputInt(ctx, "##SlotValue" .. index, cmd_id, 1, 100)
        if cmd_id_changed then
            if not slot.data then slot.data = {} end
            slot.data.command_id = new_cmd_id
            is_modified = true
        end
        
    elseif slot.type == "fx" then
        reaper.ImGui_Text(ctx, "  FX 名称:")
        reaper.ImGui_SameLine(ctx)
        local fx_name = slot.data and slot.data.fx_name or ""
        local fx_name_changed, new_fx_name = reaper.ImGui_InputText(ctx, "##SlotValue" .. index, fx_name, 256)
        if fx_name_changed then
            if not slot.data then slot.data = {} end
            slot.data.fx_name = new_fx_name
            is_modified = true
        end
        
    elseif slot.type == "script" then
        reaper.ImGui_Text(ctx, "  脚本路径:")
        reaper.ImGui_SameLine(ctx)
        local script_path = slot.data and slot.data.script_path or ""
        local script_path_changed, new_script_path = reaper.ImGui_InputText(ctx, "##SlotValue" .. index, script_path, 512)
        if script_path_changed then
            if not slot.data then slot.data = {} end
            slot.data.script_path = new_script_path
            is_modified = true
        end
    end
    
    -- 描述输入
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Text(ctx, "  描述:")
    reaper.ImGui_SameLine(ctx)
    local desc_buf = slot.description or ""
    local desc_changed, new_desc = reaper.ImGui_InputText(ctx, "##SlotDesc" .. index, desc_buf, 256)
    if desc_changed then
        slot.description = new_desc
        is_modified = true
    end
end

-- ============================================================================
-- Phase 4 - 底部操作栏
-- ============================================================================

-- 绘制底部操作栏（参考Markers风格）
function M.draw_action_bar()
    -- 显示修改状态
    if is_modified then
        local yellow_color = im_utils.color_to_u32(255, 200, 0, 255)
        reaper.ImGui_TextColored(ctx, yellow_color, "* 有未保存的更改")
        reaper.ImGui_SameLine(ctx, 0, 20)
    end
    
    -- 保存更改按钮（使用Markers风格的按钮颜色）
    local save_btn_color = im_utils.color_to_u32(66, 165, 245, 200)  -- #42A5F5
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), save_btn_color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), im_utils.color_to_u32(100, 181, 246, 255))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), im_utils.color_to_u32(30, 136, 229, 255))
    if reaper.ImGui_Button(ctx, " 保存更改 ", 0, 0) then
        M.save_config()
    end
    reaper.ImGui_PopStyleColor(ctx, 3)
    
    reaper.ImGui_SameLine(ctx, 0, 8)
    
    -- 丢弃按钮
    if reaper.ImGui_Button(ctx, " 丢弃 ", 0, 0) then
        M.discard_changes()
    end
    
    reaper.ImGui_SameLine(ctx, 0, 8)
    
    -- 重置按钮（使用警告颜色）
    local reset_btn_color = im_utils.color_to_u32(255, 82, 82, 200)  -- #FF5252
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), reset_btn_color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), im_utils.color_to_u32(255, 112, 112, 255))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), im_utils.color_to_u32(229, 57, 53, 255))
    if reaper.ImGui_Button(ctx, " 重置 ", 0, 0) then
        M.reset_to_default()
    end
    reaper.ImGui_PopStyleColor(ctx, 3)
end

-- ============================================================================
-- Phase 4 - 配置操作
-- ============================================================================

-- 保存配置到文件
-- @return boolean: 是否保存成功
function M.save_config()
    -- 清理空插槽（nil 值）
    for _, sector in ipairs(config.sectors) do
        if sector.slots then
            local cleaned_slots = {}
            for _, slot in ipairs(sector.slots) do
                if slot then
                    table.insert(cleaned_slots, slot)
                end
            end
            sector.slots = cleaned_slots
        end
    end
    
    -- 保存配置
    local success = config_manager.save(config)
    if success then
        is_modified = false
        original_config = M.deep_copy_config(config)
        reaper.ShowMessageBox("配置已保存", "成功", 0)
        return true
    else
        reaper.ShowMessageBox("配置保存失败", "错误", 0)
        return false
    end
end

-- 丢弃更改，重新加载配置
function M.discard_changes()
    if is_modified then
        local result = reaper.ShowMessageBox(
            "确定要丢弃所有未保存的更改吗？",
            "确认",
            4  -- 4 = Yes/No
        )
        if result == 6 then  -- 6 = Yes
            config = M.deep_copy_config(original_config)
            is_modified = false
            selected_sector_index = nil
            -- reaper.ShowConsoleMsg("已丢弃更改\n")
        end
    end
end

-- 重置为默认配置
function M.reset_to_default()
    local result = reaper.ShowMessageBox(
        "确定要重置为默认配置吗？这将丢失所有自定义设置。",
        "确认",
        4  -- 4 = Yes/No
    )
    if result == 6 then  -- 6 = Yes
        config = config_manager.get_default()
        original_config = M.deep_copy_config(config)
        is_modified = true
        selected_sector_index = nil
        styles.init_from_config(config)
        -- reaper.ShowConsoleMsg("已重置为默认配置\n")
    end
end

-- 调整扇区数量
function M.adjust_sector_count(new_count)
    local current_count = #config.sectors
    
    if new_count > current_count then
        -- 添加新扇区
        for i = current_count + 1, new_count do
            table.insert(config.sectors, {
                id = i,
                name = "扇区 " .. i,
                icon = "●",
                color = {26, 26, 26, 180},
                slots = {}
            })
        end
    elseif new_count < current_count then
        -- 删除多余的扇区
        for i = current_count, new_count + 1, -1 do
            table.remove(config.sectors, i)
        end
        -- 更新 ID
        for i, sector in ipairs(config.sectors) do
            sector.id = i
        end
        -- 如果选中的扇区被删除，清除选择
        if selected_sector_index and selected_sector_index > new_count then
            selected_sector_index = nil
        end
    end
end

-- ============================================================================
-- Phase 4 - 清理
-- ============================================================================

-- 清理资源
function M.cleanup()
    if is_modified then
        local result = reaper.ShowMessageBox(
            "有未保存的更改，确定要关闭吗？",
            "确认",
            4  -- 4 = Yes/No
        )
        if result ~= 6 then  -- 6 = Yes
            is_open = true  -- 保持打开
            return
        end
    end
    
    -- 清除设置窗口打开标记
    reaper.SetExtState("RadialMenu", "SettingsOpen", "0", false)
    
    if ctx then
        if reaper.ImGui_DestroyContext then
            reaper.ImGui_DestroyContext(ctx)
        end
        ctx = nil
    end
    
    config = nil
    original_config = nil
    is_open = false
    is_modified = false
    selected_sector_index = nil
    
    -- reaper.ShowConsoleMsg("设置编辑器已关闭\n")
end

-- ============================================================================
-- Phase 4 - 启动
-- ============================================================================

-- 显示设置编辑器窗口
function M.show()
    if M.init() then
        M.loop()
    else
        -- reaper.ShowConsoleMsg("设置编辑器启动失败\n")
    end
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

-- 简化的预览绘制（避免 wheel.draw_wheel 的交互检测导致卡死）
-- 使用与 wheel.lua 相同的间隙逻辑
function M.draw_simple_preview(draw_list, ctx, center_x, center_y, preview_config, selected_index)
    if not preview_config or not preview_config.sectors then
        return
    end
    
    local inner_radius = preview_config.menu.inner_radius
    local outer_radius = preview_config.menu.outer_radius
    local total_sectors = #preview_config.sectors
    local gap_radians = 0.04  -- 间隙角度（与 wheel.lua 一致）
    
    -- 绘制所有扇区（使用真正的透明间隙）
    for i, sector in ipairs(preview_config.sectors) do
        local is_selected = (selected_index == i)
        
        -- 获取扇区角度
        local rotation_offset = -math.pi / 2
        local start_angle, end_angle = math_utils.get_sector_angles(i, total_sectors, rotation_offset)
        
        -- 应用间隙（缩小扇区角度，创建真正的透明间隙）
        local draw_start = start_angle + gap_radians
        local draw_end = end_angle - gap_radians
        
        -- 获取颜色
        local color = styles.get_sector_color_u32(sector, is_selected, preview_config)
        
        -- 绘制扇形（使用缩小后的角度，高分辨率）
        local base_segments = 64  -- 预览使用稍低的分辨率（64），但仍保持平滑
        local angle_span = draw_end - draw_start
        if angle_span < 0 then
            angle_span = angle_span + 2 * math.pi
        end
        local sector_segments = math.max(16, math.floor(base_segments * angle_span / (2 * math.pi)))
        
        for j = 0, sector_segments - 1 do
            local a1 = draw_start + angle_span * (j / sector_segments)
            local a2 = draw_start + angle_span * ((j + 1) / sector_segments)
            
            local x1_inner, y1_inner = math_utils.polar_to_cartesian(a1, inner_radius)
            local x1_outer, y1_outer = math_utils.polar_to_cartesian(a1, outer_radius)
            local x2_inner, y2_inner = math_utils.polar_to_cartesian(a2, inner_radius)
            local x2_outer, y2_outer = math_utils.polar_to_cartesian(a2, outer_radius)
            
            reaper.ImGui_DrawList_AddQuadFilled(draw_list,
                center_x + x1_inner, center_y + y1_inner,
                center_x + x1_outer, center_y + y1_outer,
                center_x + x2_outer, center_y + y2_outer,
                center_x + x2_inner, center_y + y2_inner,
                color)
        end
        
        -- 绘制扇区文本和图标（修复预览显示问题）
        local text_radius = outer_radius * (styles.sizes.text_radius_ratio or 0.65)
        local center_angle = (start_angle + end_angle) / 2
        local text_x, text_y = math_utils.polar_to_cartesian(center_angle, text_radius)
        text_x = center_x + text_x
        text_y = center_y + text_y
        
        -- 组合文本：图标 + 名称
        local display_text = (sector.icon or "") .. "\n" .. (sector.name or "")
        
        -- 获取文本颜色
        local text_color = styles.get_text_color_u32()
        
        -- 计算文本尺寸用于居中
        local text_width, text_height = reaper.ImGui_CalcTextSize(ctx, display_text)
        
        -- 绘制居中文本（带阴影）
        im_utils.draw_text_with_shadow(draw_list, ctx, 
            text_x - text_width / 2, 
            text_y - text_height / 2,
            display_text, text_color, 1)
    end
    
    -- 绘制中心环（甜甜圈效果，与 wheel.lua 一致，去荧光化）
    local outer_center_radius = inner_radius
    local inner_center_radius = outer_center_radius - 6  -- 6 像素宽的环
    -- 使用灰色系颜色（#3f3c40 相关）
    local dark_grey = im_utils.color_to_u32(63, 60, 64, 255)  -- 深灰色 (#3f3c40)
    local inner_grey = im_utils.color_to_u32(50, 47, 51, 255)  -- 内圆灰色（稍深）
    local subtle_border = styles.get_glass_border_u32()  -- 深色边框
    
    -- 1. 绘制外圆（深灰色，半径 = InnerRadius）
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, center_x, center_y, outer_center_radius, dark_grey, 0)
    
    -- 2. 绘制内圆（稍深的灰色，半径 = InnerRadius - 6px）
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, center_x, center_y, inner_center_radius, inner_grey, 0)
    
    -- 不绘制边框线条（隐藏所有线条，只保留填充）
    -- 3. 不绘制外环（与主轮盘一致，隐藏线条）
end

-- 深拷贝配置表
function M.deep_copy_config(src)
    if type(src) ~= "table" then
        return src
    end
    
    local dst = {}
    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = M.deep_copy_config(value)
        else
            dst[key] = value
        end
    end
    
    -- 处理数组部分
    if #src > 0 then
        for i = 1, #src do
            if type(src[i]) == "table" then
                dst[i] = M.deep_copy_config(src[i])
            else
                dst[i] = src[i]
            end
        end
    end
    
    return dst
end

return M

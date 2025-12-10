-- @description RadialMenu Tool - 列表视图模块
-- @author Lee
-- @about
--   显示扇区的子菜单列表 (3x3 网格布局，高对比度优化版)

local M = {}

-- 加载依赖
local actions = require("actions")
local styles = require("styles")
local math_utils = require("math_utils")

-- ============================================================================
-- 配置常量 (3x3 紧凑布局)
-- ============================================================================
local GRID_COLS = 3
local GRID_ROWS = 3
local TOTAL_SLOTS = 9 
local SLOT_WIDTH = 80   
local SLOT_HEIGHT = 32  
local GAP = 4           

-- 计算总尺寸
local WINDOW_PADDING = 10
local SUBMENU_WIDTH = (SLOT_WIDTH * GRID_COLS) + (GAP * (GRID_COLS - 1)) + (WINDOW_PADDING * 2)
local SUBMENU_HEIGHT = (SLOT_HEIGHT * GRID_ROWS) + (GAP * (GRID_ROWS - 1)) + (WINDOW_PADDING * 2)

-- 列表视图状态
local current_sector = nil

-- ============================================================================
-- Phase 3 - 绘制子菜单 (主入口)
-- ============================================================================

function M.draw_submenu(ctx, sector_data, center_x, center_y)
    if not sector_data then return end
    
    current_sector = sector_data
    
    -- 1. 计算智能位置
    local x, y = M.calculate_submenu_position(ctx, sector_data, center_x, center_y)
    
    -- 2. 设置窗口属性
    reaper.ImGui_SetNextWindowPos(ctx, x, y, reaper.ImGui_Cond_Always())
    reaper.ImGui_SetNextWindowSize(ctx, SUBMENU_WIDTH, SUBMENU_HEIGHT, reaper.ImGui_Cond_Always())
    
    -- 3. 样式设置 (深色背景容器)
    
    -- 背景色：深色磨砂背景
    local bg_col = styles.correct_rgba_to_u32({20, 20, 22, 240})
    -- 面板边框：纯黑
    local border_col = styles.correct_rgba_to_u32({0, 0, 0, 255})
    
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), bg_col) 
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), border_col)
    
    -- 布局样式
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), WINDOW_PADDING, WINDOW_PADDING)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), GAP, GAP)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 1)

    if reaper.ImGui_Begin(ctx, "##Submenu_" .. sector_data.id, true, reaper.ImGui_WindowFlags_NoDecoration() | reaper.ImGui_WindowFlags_NoMove()) then
        M.draw_grid_buttons(ctx, sector_data)
        reaper.ImGui_End(ctx)
    end
    
    reaper.ImGui_PopStyleVar(ctx, 4)
    reaper.ImGui_PopStyleColor(ctx, 2)
end

-- ============================================================================
-- 绘制按钮网格
-- ============================================================================

function M.draw_grid_buttons(ctx, sector_data)
    for i = 1, TOTAL_SLOTS do
        local slot = sector_data.slots and sector_data.slots[i] or nil
        
        if (i - 1) % GRID_COLS ~= 0 then
            reaper.ImGui_SameLine(ctx)
        end
        
        M.draw_single_button(ctx, slot, i)
    end
end

function M.draw_single_button(ctx, slot, index)
    local label = slot and slot.name or ""
    
    -- ============================================================
    -- 颜色优化区域 (High Contrast)
    -- ============================================================
    
    local col_normal, col_hover, col_active, col_border
    local text_color = styles.correct_rgba_to_u32(styles.colors.text_normal)
    
    if slot then
        -- [有功能的按钮]
        -- 稍微亮一点的灰色，使其从黑色背景中凸显出来
        col_normal = styles.correct_rgba_to_u32({60, 62, 66, 255}) 
        -- 悬停高亮色 (使用配置的蓝色)
        col_hover  = styles.correct_rgba_to_u32(styles.colors.sector_active_out)
        -- 点击高亮色
        col_active = styles.correct_rgba_to_u32(styles.colors.sector_active_in)
        -- 边框色 (亮灰色描边，增强轮廓)
        col_border = styles.correct_rgba_to_u32({85, 85, 90, 100})
    else
        -- [空插槽]
        -- 更暗的背景，表示"空"
        col_normal = styles.correct_rgba_to_u32({30, 30, 32, 100}) 
        -- 悬停时稍微亮一点
        col_hover  = styles.correct_rgba_to_u32({50, 50, 55, 150})
        col_active = styles.correct_rgba_to_u32({60, 60, 65, 150})
        -- 边框色 (暗淡的描边，仅用于显示网格位置)
        col_border = styles.correct_rgba_to_u32({60, 60, 60, 60})
        -- 文字变暗
        text_color = styles.correct_rgba_to_u32(styles.colors.text_disabled)
    end

    -- 应用颜色
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), col_normal)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), col_hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), col_active)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), col_border)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), text_color)
    
    -- 应用样式 (增加 BorderSize 以显示描边)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 1) -- 关键：开启按钮描边
    
    if reaper.ImGui_Button(ctx, label .. "##Slot" .. index, SLOT_WIDTH, SLOT_HEIGHT) then
        if slot then M.handle_item_click(slot) end
    end
    
    reaper.ImGui_PopStyleVar(ctx, 2)
    reaper.ImGui_PopStyleColor(ctx, 5)
    
    -- Tooltip
    if slot and reaper.ImGui_IsItemHovered(ctx) then
        local tooltip = slot.description
        if not tooltip or tooltip == "" then tooltip = slot.name end
        if tooltip and tooltip ~= "" then
            reaper.ImGui_BeginTooltip(ctx)
            reaper.ImGui_Text(ctx, tooltip)
            reaper.ImGui_EndTooltip(ctx)
        end
    end
end

-- ============================================================================
-- 智能位置计算
-- ============================================================================

function M.calculate_submenu_position(ctx, sector_data, center_x, center_y)
    local config_manager = require("config_manager")
    local config = config_manager.load()
    local math_utils = require("math_utils")
    
    local outer_radius = config.menu.outer_radius or 200
    local total_sectors = #config.sectors
    local angle = math_utils.get_sector_center_angle(sector_data.id, total_sectors, -math.pi / 2)
    
    -- 增加 overlap
    local overlap_offset = 12 
    local anchor_dist = outer_radius - overlap_offset
    
    local anchor_x_rel, anchor_y_rel = math_utils.polar_to_cartesian(angle, anchor_dist)
    local anchor_x = center_x + anchor_x_rel
    local anchor_y = center_y + anchor_y_rel
    
    local final_x = anchor_x
    local final_y = anchor_y - (SUBMENU_HEIGHT / 2)
    
    local is_right_side = math.cos(angle) >= 0
    
    if is_right_side then
        final_x = anchor_x + 5 
    else
        final_x = anchor_x - SUBMENU_WIDTH - 5
    end
    
    return final_x, final_y
end

-- ============================================================================
-- 交互逻辑
-- ============================================================================

function M.handle_item_click(slot)
    if not slot then return end
    
    if slot.type == "action" and slot.data and slot.data.command_id then
        actions.execute_command(slot.data.command_id)
    elseif slot.type == "fx" and slot.data and slot.data.fx_name then
        local fx_engine = require("fx_engine")
        fx_engine.smart_add_fx(slot.data.fx_name)
    elseif slot.type == "script" and slot.data and slot.data.script_path then
        actions.execute_script(slot.data.script_path)
    end
end

function M.get_current_sector()
    return current_sector
end

return M
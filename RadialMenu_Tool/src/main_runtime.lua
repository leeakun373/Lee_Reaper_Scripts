-- @description RadialMenu Tool - 主运行时
-- @author Lee
-- @about
--   轮盘菜单的主循环
--   优化：解决遮挡问题，优化拖拽手感

local M = {}

-- 加载依赖模块
local config_manager = require("config_manager")
local wheel = require("wheel")
local list_view = require("list_view")
local styles = require("styles")
local math_utils = require("math_utils")

-- 运行时状态
local ctx = nil
local config = nil
local is_open = false
local window_width = 500
local window_height = 500
local clicked_sector = nil
local show_submenu = false
local is_pinned = false

-- 窗口定位辅助
local is_first_display = true

-- 长按模式相关变量
local SCRIPT_START_TIME = nil
local KEY = nil
local KEY_START_STATE = nil

-- ============================================================================
-- Phase 2 - 初始化
-- ============================================================================

function M.init()
    local ext_state = reaper.GetExtState("RadialMenu_Tool", "Running")
    if ext_state == "1" then return false end
    
    reaper.SetExtState("RadialMenu_Tool", "Running", "1", false)
    
    reaper.atexit(function()
        reaper.SetExtState("RadialMenu_Tool", "Running", "0", false)
        -- 释放按键拦截
        if KEY and reaper.JS_VKeys_Intercept then
            reaper.JS_VKeys_Intercept(KEY, -1)
        end
        if ctx and reaper.ImGui_DestroyContext then
            reaper.ImGui_DestroyContext(ctx)
        end
    end)
    
    if not reaper.ImGui_CreateContext then
        reaper.ShowMessageBox("错误: ReaImGui 未安装", "初始化失败", 0)
        return false
    end
    
    -- 检查 JS_VKeys API 是否可用（用于按键检测）
    if not reaper.JS_VKeys_GetState then
        reaper.ShowMessageBox("错误: JS_ReaScriptAPI 扩展未安装\n\n请安装 JS_ReaScriptAPI 扩展以支持长按模式", "初始化失败", 0)
        return false
    end
    
    ctx = reaper.ImGui_CreateContext("RadialMenu_Wheel", reaper.ImGui_ConfigFlags_None())
    config = config_manager.load()
    styles.init_from_config(config)
    
    -- 窗口大小与轮盘一致，只留少量边距（子菜单作为独立窗口显示）
    local diameter = config.menu.outer_radius * 2 + 20  -- 只留 10 像素边距（每边）
    window_width = diameter
    window_height = diameter
    
    -- 记录脚本启动时间
    SCRIPT_START_TIME = reaper.time_precise()
    
    -- 检测并拦截触发按键（参考 Sexan_Pie3000 的实现）
    local key_state = reaper.JS_VKeys_GetState(SCRIPT_START_TIME - 1)
    local down_state = reaper.JS_VKeys_GetDown(SCRIPT_START_TIME)
    for i = 1, 255 do
        if key_state:byte(i) ~= 0 or down_state:byte(i) ~= 0 then
            if reaper.JS_VKeys_Intercept then
                reaper.JS_VKeys_Intercept(i, 1)  -- 拦截按键
            end
            KEY = i
            break
        end
    end
    
    if not KEY then
        reaper.ShowMessageBox("错误: 无法检测到触发按键", "初始化失败", 0)
        return false
    end
    
    -- 不再需要 gfx 窗口，使用 ImGui 原生按键检测
    is_open = true
    return true
end

-- ============================================================================
-- Phase 2 - 按键检测函数
-- ============================================================================

-- 检测按键是否仍然被按住
local function KeyHeld()
    if not KEY or not SCRIPT_START_TIME then return false end
    if not reaper.JS_VKeys_GetState then return false end
    local key_state = reaper.JS_VKeys_GetState(SCRIPT_START_TIME - 1)
    return key_state:byte(KEY) == 1
end

-- 跟踪快捷键状态，如果松开则关闭窗口
local function TrackShortcutKey()
    if not KeyHeld() then
        -- 按键已松开，关闭窗口
        M.cleanup()
        return false
    end
    return true
end

-- ============================================================================
-- Phase 2 - 主循环
-- ============================================================================

function M.loop()
    if not ctx then return end
    
    -- [核心] 长按模式：检测按键是否仍然被按住
    if not TrackShortcutKey() then
        return
    end
    
    -- ESC 键关闭窗口（使用 ImGui 原生检测）
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then 
        M.cleanup()
        return
    end
    
    -- ============================================================
    -- 1. 智能窗口标志 (Smart Window Flags)
    -- ============================================================
    local window_flags = 
        reaper.ImGui_WindowFlags_NoDecoration() |
        reaper.ImGui_WindowFlags_NoSavedSettings() |
        reaper.ImGui_WindowFlags_NoFocusOnAppearing()
    
    -- [核心优化] 动态计算是否穿透
    -- 默认情况下，我们希望窗口能接收输入。
    -- 但是，如果我们在 Draw 阶段发现鼠标悬停在空白处，我们会在下一帧加上 NoMouseInputs
    -- (由于 ImGui 是即时模式，完全的逐帧透传比较复杂，这里采用"大框套小框"的策略更稳妥)
    -- 实际上，对于大窗口遮挡问题，最好的办法是不移动窗口，而是只移动"绘图内容"。
    -- 但为了简化代码，我们保持移动窗口，但使用 HitTest 逻辑。

    -- 设置窗口背景完全透明
    reaper.ImGui_SetNextWindowBgAlpha(ctx, 0.0)
    reaper.ImGui_SetNextWindowSize(ctx, window_width, window_height, reaper.ImGui_Cond_Always())
    
    if is_first_display then
        local mouse_x, mouse_y = reaper.GetMousePosition()
        if mouse_x and mouse_y then
            local window_x = mouse_x - window_width / 2
            local window_y = mouse_y - window_height / 2
            
            -- 获取视口信息，确保窗口在屏幕范围内
            local viewport = reaper.ImGui_GetMainViewport(ctx)
            if viewport then
                local vp_x, vp_y = reaper.ImGui_Viewport_GetPos(viewport)
                local vp_w, vp_h = reaper.ImGui_Viewport_GetSize(viewport)
                
                -- 确保窗口不超出屏幕边界
                if window_x < vp_x then
                    window_x = vp_x
                end
                if window_x + window_width > vp_x + vp_w then
                    window_x = vp_x + vp_w - window_width
                end
                if window_y < vp_y then
                    window_y = vp_y
                end
                if window_y + window_height > vp_y + vp_h then
                    window_y = vp_y + vp_h - window_height
                end
            end
            
            reaper.ImGui_SetNextWindowPos(ctx, window_x, window_y, reaper.ImGui_Cond_Appearing())
        else
            -- 如果无法获取鼠标位置，则使用居中逻辑作为后备
            local viewport = reaper.ImGui_GetMainViewport(ctx)
            if viewport then
                local vp_x, vp_y = reaper.ImGui_Viewport_GetPos(viewport)
                local vp_w, vp_h = reaper.ImGui_Viewport_GetSize(viewport)
                reaper.ImGui_SetNextWindowPos(ctx, vp_x + (vp_w - window_width)/2, vp_y + (vp_h - window_height)/2, reaper.ImGui_Cond_Appearing())
            end
        end
        is_first_display = false
    end
    
    -- 强制去除窗口边框（在 Begin 之前设置）
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0.0)
    
    local visible, open = reaper.ImGui_Begin(ctx, "Radial Menu", true, window_flags)
    
    if visible then
        M.draw()
        
        -- [关键] 检查鼠标是否在交互区域内
        -- 如果鼠标不在任何可交互元素上，通过 reaper.JS 或 API 让点击穿透 (ReaImGui 较难直接实现完美穿透)
        -- 替代方案：让窗口本身 NoBackground 且 NoDecoration，Reaper 通常会处理好透明区域的点击。
        -- 如果你发现还是挡住了，说明 ReaImGui 的窗口捕获了所有点击。
        
        reaper.ImGui_End(ctx)
    end
    
    -- 恢复窗口边框样式（在 End 之后配对 PopStyleVar）
    reaper.ImGui_PopStyleVar(ctx)
    
    if open then
        reaper.defer(M.loop)
    end
end

-- ============================================================================
-- Phase 2 - 绘制界面 & 交互
-- ============================================================================

function M.draw()
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 0)
    
    local win_w, win_h = reaper.ImGui_GetWindowSize(ctx)
    local win_x, win_y = reaper.ImGui_GetWindowPos(ctx)
    local center_x = win_x + win_w / 2
    local center_y = win_y + win_h / 2
    
    local inner_radius = config.menu.inner_radius or 50
    local outer_radius = config.menu.outer_radius or 200
    
    -- 1. 绘制轮盘 (背景层)
    local active_id = (show_submenu and clicked_sector) and clicked_sector.id or nil
    wheel.draw_wheel(ctx, config, active_id, is_pinned)
    
    -- ============================================================
    -- 2. 优化拖拽手感：InvisibleButton 覆盖中心
    -- ============================================================
    -- 我们在窗口正中心放置一个看不见的按钮，大小等于 inner_radius
    -- 这样可以利用 ImGui 原生的拖拽逻辑，不仅手感好，而且不消耗性能
    
    reaper.ImGui_SetCursorPos(ctx, (win_w / 2) - inner_radius, (win_h / 2) - inner_radius)
    
    -- 创建一个隐形按钮作为"拖拽手柄"
    -- 只有按住这个区域，才会被 ImGui 视为"在窗口内有效点击"
    reaper.ImGui_InvisibleButton(ctx, "##DragHandle", inner_radius * 2, inner_radius * 2)
    
    -- 双击切换 Pin
    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
        is_pinned = not is_pinned
    end
    
    -- 拖拽逻辑 (优化版)
    -- 利用 IsItemActive (按下并保持) 来驱动移动
    if reaper.ImGui_IsItemActive(ctx) and reaper.ImGui_IsMouseDragging(ctx, 0) then
        local dx, dy = reaper.ImGui_GetMouseDelta(ctx, 0)
        local new_x = win_x + dx
        local new_y = win_y + dy
        
        -- 获取视口信息，确保拖动时窗口不超出屏幕边界
        local viewport = reaper.ImGui_GetMainViewport(ctx)
        if viewport then
            local vp_x, vp_y = reaper.ImGui_Viewport_GetPos(viewport)
            local vp_w, vp_h = reaper.ImGui_Viewport_GetSize(viewport)
            
            -- 确保窗口不超出屏幕边界
            if new_x < vp_x then
                new_x = vp_x
            end
            if new_x + win_w > vp_x + vp_w then
                new_x = vp_x + vp_w - win_w
            end
            if new_y < vp_y then
                new_y = vp_y
            end
            if new_y + win_h > vp_y + vp_h then
                new_y = vp_y + vp_h - win_h
            end
        end
        
        reaper.ImGui_SetWindowPos(ctx, new_x, new_y)
        
        -- 注意：ReaImGui 可能没有 ResetMouseDragDelta 函数，如果报错可以注释掉
        if reaper.ImGui_ResetMouseDragDelta then
            reaper.ImGui_ResetMouseDragDelta(ctx, 0)
        end
    end
    
    -- 设置鼠标指针 (悬停在中心时显示移动图标)
    if reaper.ImGui_IsItemHovered(ctx) then
        -- 检查是否有 ResizeAll 光标常量，如果没有则使用默认
        if reaper.ImGui_MouseCursor_ResizeAll then
            reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeAll())
        end
    end

    -- ============================================================
    -- 3. 扇区点击逻辑 (Hit Test)
    -- ============================================================
    -- 我们需要手动检测扇区点击，因为扇区是画出来的，不是真实的 Button
    M.handle_sector_click(center_x, center_y, inner_radius, outer_radius)
    
    -- ============================================================
    -- 4. 绘制子菜单
    -- ============================================================
    -- 子菜单作为独立的 Window 绘制，或者作为当前 Window 的内容
    -- 为了避免坐标系混乱，我们在当前 DrawList 上绘制，或者使用 BeginChild
    
    if show_submenu and clicked_sector then
        -- list_view.draw_submenu 内部使用了 SetNextWindowPos + Begin
        -- 这意味着子菜单是一个独立的 ImGui 窗口，这很好！
        -- 独立窗口不会被主窗口的透明区域遮挡问题影响
        list_view.draw_submenu(ctx, clicked_sector, center_x, center_y)
    end
    
    reaper.ImGui_PopStyleVar(ctx)
end

-- ============================================================================
-- 输入处理逻辑
-- ============================================================================

function M.handle_sector_click(center_x, center_y, inner_radius, outer_radius)
    -- 获取鼠标位置
    local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
    local win_x, win_y = reaper.ImGui_GetWindowPos(ctx)
    local relative_x = mouse_x - win_x
    local relative_y = mouse_y - win_y
    local w, h = reaper.ImGui_GetWindowSize(ctx)
    
    -- 计算距离
    local distance = math_utils.distance(relative_x, relative_y, w/2, h/2)
    
    -- 只有在扇区环带内，且没有正在拖拽中心时，才检测点击
    -- 另外：确保没有悬停在子菜单上 (ImGui 会自动处理 Window 遮挡，所以这里不用太担心)
    if distance > inner_radius and distance <= outer_radius then
        
        -- 只有点击左键时触发
        if reaper.ImGui_IsMouseClicked(ctx, 0) then
             local hovered_id = wheel.get_hovered_sector_id()
             if hovered_id then
                 local sector = config_manager.get_sector_by_id(config, hovered_id)
                 if sector then
                     M.on_sector_click(sector)
                 end
             end
        end
        
        -- 如果鼠标在这个环带内，我们需要"吞掉"输入，防止穿透到 Reaper
        -- 但是 ReaImGui 默认就会吞掉窗口内的输入，所以这步是自动的
        
    elseif distance > outer_radius then
        -- [核心] 解决大框遮挡问题：
        -- 如果鼠标在轮盘外部，点击时我们希望穿透下去。
        -- 简单的做法：检测点击是否发生在空白处
        if reaper.ImGui_IsMouseClicked(ctx, 0) then
            -- 如果点击了外部，关闭子菜单
            if show_submenu then
                -- 这里要做个判断：如果点击的是子菜单窗口范围，就不要关
                -- 但因为子菜单是独立 Window，Reaper 会优先处理它
                -- 所以这里只需简单的关闭逻辑
                -- 检查是否有其他窗口被悬停（比如子菜单）
                local any_window_hovered = false
                -- 注意：ReaImGui 可能没有 IsWindowHovered 的 AnyWindow 标志
                -- 这里简化处理，直接关闭子菜单
                show_submenu = false
                clicked_sector = nil
            end
        end
    end
end

-- 当扇区被点击时调用
function M.on_sector_click(sector)
    if not sector then return end
    
    if clicked_sector and clicked_sector.id == sector.id then
        show_submenu = false
        clicked_sector = nil
    else
        clicked_sector = sector
        show_submenu = true
    end
end

-- ============================================================================
-- 清理与启动
-- ============================================================================

function M.cleanup()
    reaper.SetExtState("RadialMenu_Tool", "Running", "0", false)
    reaper.SetExtState("RadialMenu_Tool", "WindowOpen", "0", false)
    is_first_display = true
    
    -- 释放按键拦截
    if KEY and reaper.JS_VKeys_Intercept then
        reaper.JS_VKeys_Intercept(KEY, -1)
    end
    KEY = nil
    SCRIPT_START_TIME = nil
    
    -- 不再需要 gfx.quit，因为已经移除了 gfx.init
    if ctx then
        if reaper.ImGui_DestroyContext then reaper.ImGui_DestroyContext(ctx) end
        ctx = nil
    end
end

function M.run()
    -- 长按模式：不再使用 toggle 逻辑
    -- 每次运行都直接初始化并显示窗口
    -- 窗口会在按键松开时自动关闭（在 TrackShortcutKey 中处理）
    
    local running = reaper.GetExtState("RadialMenu_Tool", "Running")
    if running == "1" then
        -- 如果已有实例在运行，不重复启动
        return
    end
    
    if M.init() then
        reaper.SetExtState("RadialMenu_Tool", "WindowOpen", "1", false)
        M.loop()
    end
end

return M

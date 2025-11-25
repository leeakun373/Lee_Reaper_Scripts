--[[
  REAPER Lua脚本: 修剪Item左边缘
  功能说明:
  - 将item的左边缘修剪到鼠标光标位置
  - 支持组选中的items
  - 保留淡入淡出的绝对位置（淡入结束点位置不变）
  - 自动处理snapoffset和take的startoffset
  - 只会在item范围内trim，不会拉长item
  
  使用方法:
  1. 将鼠标放在想要修剪的位置
  2. 运行此脚本
  3. item的左边缘会被修剪到鼠标位置
]]

local proj = 0

-- 移动编辑光标到鼠标位置
reaper.Main_OnCommand(40513, 0) -- Move edit cursor to mouse cursor
local cursor_pos = reaper.GetCursorPosition()

-- 获取鼠标下的item和选中的items
local item_under_mouse = reaper.BR_ItemAtMouseCursor()
local sel_count = reaper.CountSelectedMediaItems(proj)

-- 确定要处理的初始item和items列表
local init_item = nil
local items_to_process = {}

if sel_count > 1 then
    -- 选中了多个items，处理所有选中的items（但只在cursor位置相关的item上trim）
    -- 先找到cursor位置的item
    local cursor_item = item_under_mouse
    if not cursor_item then
        -- 在轨道上查找cursor位置的item
        local track, track_context, pos = reaper.BR_TrackAtMouseCursor()
        if track and track_context == 2 then
            local item_count = reaper.CountTrackMediaItems(track)
            for i = 0, item_count - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                if item then
                    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                    if item_start >= cursor_pos then
                        cursor_item = item
                        break
                    end
                end
            end
        end
    end
    
    -- 如果找到cursor位置的item，只处理选中的items中与cursor item同组的items
    if cursor_item then
        local cursor_group_id = reaper.GetMediaItemInfo_Value(cursor_item, "I_GROUPID")
        for i = 0, sel_count - 1 do
            local item = reaper.GetSelectedMediaItem(proj, i)
            if item then
                local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
                -- 如果cursor item有组，只处理同组的items；否则处理所有选中的items
                if cursor_group_id == 0 or group_id == cursor_group_id then
                    if not init_item then
                        init_item = item
                    end
                    table.insert(items_to_process, item)
                end
            end
        end
    else
        -- 没有找到cursor位置的item，处理所有选中的items
        for i = 0, sel_count - 1 do
            local item = reaper.GetSelectedMediaItem(proj, i)
            if item then
                if not init_item then
                    init_item = item
                end
                table.insert(items_to_process, item)
            end
        end
    end
elseif sel_count == 1 then
    -- 只选中了一个item，优先使用cursor位置的item（如果存在）
    local cursor_item = item_under_mouse
    if not cursor_item then
        -- 在轨道上查找cursor位置的item
        local track, track_context, pos = reaper.BR_TrackAtMouseCursor()
        if track and track_context == 2 then
            local item_count = reaper.CountTrackMediaItems(track)
            for i = 0, item_count - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                if item then
                    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    if item_start >= cursor_pos then
                        cursor_item = item
                        break
                    end
                end
            end
        end
    end
    
    if cursor_item then
        -- 使用cursor位置的item
        init_item = cursor_item
        table.insert(items_to_process, cursor_item)
    else
        -- 如果没有cursor位置的item，使用选中的item
        init_item = reaper.GetSelectedMediaItem(proj, 0)
        table.insert(items_to_process, init_item)
    end
else
    -- 没有选中item，使用cursor位置的item
    local cursor_item = item_under_mouse
    if not cursor_item then
        -- 在轨道上查找cursor位置的item
        local track, track_context, pos = reaper.BR_TrackAtMouseCursor()
        if track and track_context == 2 then
            local item_count = reaper.CountTrackMediaItems(track)
            for i = 0, item_count - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                if item then
                    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    if item_start >= cursor_pos then
                        cursor_item = item
                        break
                    end
                end
            end
        end
    end
    
    init_item = cursor_item
    if init_item then
        table.insert(items_to_process, init_item)
    end
end

if not init_item or #items_to_process == 0 then
    return -- 没有找到合适的item
end

-- 获取初始item的轨道和组信息
local init_track = reaper.GetMediaItem_Track(init_item)
local init_item_start = reaper.GetMediaItemInfo_Value(init_item, "D_POSITION")
local init_item_length = reaper.GetMediaItemInfo_Value(init_item, "D_LENGTH")
local init_item_end = init_item_start + init_item_length
local init_group_id = reaper.GetMediaItemInfo_Value(init_item, "I_GROUPID")

-- 如果items_to_process只有一个item，且该item在cursor右侧，需要找到cursor后的第一个item
if #items_to_process == 1 and init_item_end <= cursor_pos then
    -- 查找同一轨道上cursor位置后的第一个item
    local track_item_count = reaper.CountTrackMediaItems(init_track)
    for i = 0, track_item_count - 1 do
        local item = reaper.GetTrackMediaItem(init_track, i)
        if item then
            local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            if item_start >= cursor_pos then
                init_item = item
                items_to_process[1] = item
                init_item_start = item_start
                init_item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                init_item_end = init_item_start + init_item_length
                init_group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
                break
            end
        end
    end
end

-- 检查是否有合适的item需要处理
if #items_to_process == 1 then
    -- 关键修复：检查cursor是否在item范围内，如果cursor在item左侧（会拉长item），则不处理
    if cursor_pos < init_item_start then
        return -- cursor在item左侧，不应该trim（会拉长item）
    end
    
    if init_item_end <= cursor_pos then
        return -- 没有找到合适的item
    end
    
    -- 单个item时，检查是否需要处理组
    if init_group_id > 0 then
        local group_items = {}
        local track_count = reaper.CountTracks(proj)
        for t = 0, track_count - 1 do
            local track = reaper.GetTrack(proj, t)
            if track then
                local item_count = reaper.CountTrackMediaItems(track)
                for i = 0, item_count - 1 do
                    local item = reaper.GetTrackMediaItem(track, i)
                    if item then
                        local group_id = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
                        if group_id == init_group_id then
                            table.insert(group_items, item)
                        end
                    end
                end
            end
        end
        -- 如果有多个组items，替换items_to_process
        if #group_items > 1 then
            items_to_process = group_items
        end
    end
else
    -- 多个items时，过滤掉不在cursor右侧的items，并且cursor不能在item左侧（防止拉长）
    local filtered_items = {}
    for _, item in ipairs(items_to_process) do
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = item_start + item_length
        -- cursor必须在item右侧（在item范围内），不能在item左侧
        if item_end > cursor_pos and cursor_pos >= item_start then
            table.insert(filtered_items, item)
        end
    end
    if #filtered_items > 0 then
        items_to_process = filtered_items
    else
        return -- 没有合适的item需要处理
    end
end

-- 选中要处理的items
reaper.SelectAllMediaItems(proj, false)
for _, item in ipairs(items_to_process) do
    reaper.SetMediaItemSelected(item, true)
end

-- 找到所有选中items中最左侧的位置（用于计算diff）
local min_start = math.huge
for _, item in ipairs(items_to_process) do
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local mute = reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1
    if not mute and item_start < min_start then
        min_start = item_start
    end
end
if min_start == math.huge then
    min_start = reaper.GetMediaItemInfo_Value(init_item, "D_POSITION")
end

local init_diff = min_start - cursor_pos

-- 开始撤销组
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- 处理每个item
for i, item in ipairs(items_to_process) do
    if not reaper.ValidatePtr(item, "MediaItem*") then
        goto continue
    end
    
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_length
    local diff = item_start - cursor_pos
    
    -- 关键修复：检查cursor是否在item范围内
    if cursor_pos < item_start or cursor_pos >= item_end then
        goto continue -- cursor不在item范围内，跳过（防止拉长item）
    end
    
    -- 如果item在cursor左侧，设置automute
    if i > 1 then
        if item_end <= cursor_pos then
            reaper.SetMediaItemInfo_Value(item, "I_AUTOMUTE", 2) -- automute
        else
            local automute = reaper.GetMediaItemInfo_Value(item, "I_AUTOMUTE")
            if automute == 2 then
                reaper.SetMediaItemInfo_Value(item, "I_AUTOMUTE", 0) -- 取消automute
            end
        end
    end
    
    -- 只有item在cursor右侧时才需要修剪
    if item_end > cursor_pos and (diff <= init_diff + 0.0001 or diff < 0 or (#items_to_process > 1 and i == 1)) then
        local init_item_pos = item_start
        local init_item_len = item_length
        
        -- 保存淡入淡出信息（绝对位置）
        local fadein_len_auto = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO")
        local fadein_len_manual = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
        local fadein_auto = fadein_len_auto > 0
        local fadein_len = fadein_auto and fadein_len_auto or fadein_len_manual
        
        local fadeout_len_auto = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO")
        local fadeout_len_manual = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
        local fadeout_auto = fadeout_len_auto > 0
        local fadeout_len = fadeout_auto and fadeout_len_auto or fadeout_len_manual
        
        local fadein_shape = reaper.GetMediaItemInfo_Value(item, "C_FADEINSHAPE")
        local fadeout_shape = reaper.GetMediaItemInfo_Value(item, "C_FADEOUTSHAPE")
        local fadein_curv = reaper.GetMediaItemInfo_Value(item, "D_FADEINDIR")
        local fadeout_curv = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTDIR")
        
        -- 计算淡入结束的绝对位置（如果存在淡入）
        local fadein_end_absolute = item_start + fadein_len
        local fadeout_start_absolute = item_end - fadeout_len
        
        -- 检查轨道是否可见
        local track = reaper.GetMediaItem_Track(item)
        local track_visible = reaper.IsTrackVisible(track, false)
        
        if track_visible then
            -- 使用REAPER的内置命令（仅在可见轨道上工作）
            reaper.SetMediaItemSelected(item, true)
            reaper.Main_OnCommand(41305, 0) -- Trim/Untrim left edge
            
            -- 重新获取item信息（因为内置命令可能改变了item）
            item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            item_end = item_start + item_length
        else
            -- 手动处理不可见轨道
            local new_item_start = cursor_pos
            local new_item_length = init_item_len + diff
            
            -- 更新item位置和长度
            reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_item_start)
            reaper.SetMediaItemInfo_Value(item, "D_LENGTH", new_item_length)
            
            -- 更新snapoffset
            local snapoffset = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
            if snapoffset > 0 then
                reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", snapoffset + diff)
            end
            
            -- 更新所有takes的startoffset
            local take_count = reaper.CountTakes(item)
            for t = 0, take_count - 1 do
                local take = reaper.GetTake(item, t)
                if take then
                    local startoffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
                    local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
                    reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", startoffs - diff * playrate)
                end
            end
            
            item_start = new_item_start
            item_end = item_start + new_item_length
        end
        
        -- Trim Left时：淡入长度保持不变（保持原有的淡入长度）
        -- 参考nvk的实现：让REAPER内置命令处理，然后手动恢复淡入长度
        -- 注意：REAPER的内置trim命令可能会改变淡入，所以我们需要恢复它
        
        -- 先保存原始的淡入设置
        local original_fadein_len = fadein_len
        
        -- 如果使用内置命令，内置命令会自动处理，我们需要恢复淡入长度
        if track_visible then
            -- 内置命令已经执行，我们需要恢复淡入长度
            if original_fadein_len > 0.0001 then
                -- 确保淡入长度不超过item长度
                local restored_fadein_len = math.min(original_fadein_len, item_length)
                
                if fadein_auto then
                    reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", restored_fadein_len)
                else
                    reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", restored_fadein_len)
                end
                reaper.SetMediaItemInfo_Value(item, "C_FADEINSHAPE", fadein_shape)
                reaper.SetMediaItemInfo_Value(item, "D_FADEINDIR", fadein_curv)
            end
        else
            -- 手动处理时，直接保持淡入长度不变
            if original_fadein_len > 0.0001 then
                local restored_fadein_len = math.min(original_fadein_len, item_length)
                
                if fadein_auto then
                    reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", restored_fadein_len)
                else
                    reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", restored_fadein_len)
                end
                reaper.SetMediaItemInfo_Value(item, "C_FADEINSHAPE", fadein_shape)
                reaper.SetMediaItemInfo_Value(item, "D_FADEINDIR", fadein_curv)
            end
        end
        
        -- Trim Left时：淡出保持不变（不应该调整淡出）
        -- 淡出设置已经在trim后保持不变，无需额外处理
    end
    
    ::continue::
end

-- 恢复光标位置
reaper.SetEditCurPos(cursor_pos, false, false)

-- 结束撤销组
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Trim Left Edge", -1)

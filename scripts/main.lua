-- ============================================================================
-- 2048 游戏
-- 经典数字合并益智游戏
-- 操作: 方向键/WASD 或触摸滑动
-- ============================================================================

local UI = require("urhox-libs/UI")

-- ============================================================================
-- 全局变量
-- ============================================================================
local uiRoot_ = nil
local GRID_SIZE = 4
local board = {}         -- 4x4 棋盘数据
local score = 0
local bestScore = 0
local gameOver = false
local gameWon = false
local canContinue = false -- 赢了之后是否继续
local moved = false       -- 本轮是否有移动

-- 触摸滑动相关
local touchStartX = 0
local touchStartY = 0
local isTouching = false
local SWIPE_THRESHOLD = 30  -- 滑动最小距离

-- 方块颜色映射
local TILE_COLORS = {
    [0]    = { bg = {205, 193, 180, 255}, fg = {119, 110, 101, 255} },
    [2]    = { bg = {238, 228, 218, 255}, fg = {119, 110, 101, 255} },
    [4]    = { bg = {237, 224, 200, 255}, fg = {119, 110, 101, 255} },
    [8]    = { bg = {242, 177, 121, 255}, fg = {249, 246, 242, 255} },
    [16]   = { bg = {245, 149, 99,  255}, fg = {249, 246, 242, 255} },
    [32]   = { bg = {246, 124, 95,  255}, fg = {249, 246, 242, 255} },
    [64]   = { bg = {246, 94,  59,  255}, fg = {249, 246, 242, 255} },
    [128]  = { bg = {237, 207, 114, 255}, fg = {249, 246, 242, 255} },
    [256]  = { bg = {237, 204, 97,  255}, fg = {249, 246, 242, 255} },
    [512]  = { bg = {237, 200, 80,  255}, fg = {249, 246, 242, 255} },
    [1024] = { bg = {237, 197, 63,  255}, fg = {249, 246, 242, 255} },
    [2048] = { bg = {237, 194, 46,  255}, fg = {249, 246, 242, 255} },
}

-- ============================================================================
-- 游戏逻辑
-- ============================================================================

--- 初始化棋盘
function InitBoard()
    board = {}
    for r = 1, GRID_SIZE do
        board[r] = {}
        for c = 1, GRID_SIZE do
            board[r][c] = 0
        end
    end
    score = 0
    gameOver = false
    gameWon = false
    canContinue = false
    AddRandomTile()
    AddRandomTile()
end

--- 获取所有空格位置
function GetEmptyCells()
    local empty = {}
    for r = 1, GRID_SIZE do
        for c = 1, GRID_SIZE do
            if board[r][c] == 0 then
                empty[#empty + 1] = { r = r, c = c }
            end
        end
    end
    return empty
end

--- 在随机空格添加新方块 (90% 概率为2, 10% 概率为4)
function AddRandomTile()
    local empty = GetEmptyCells()
    if #empty == 0 then return false end
    local pos = empty[math.random(#empty)]
    board[pos.r][pos.c] = (math.random() < 0.9) and 2 or 4
    return true
end

--- 向左滑动一行 (核心合并逻辑)
function SlideRowLeft(row)
    local newRow = {}
    local mergedScore = 0
    local hasMoved = false

    -- 1. 提取非零元素
    local nonZero = {}
    for i = 1, GRID_SIZE do
        if row[i] ~= 0 then
            nonZero[#nonZero + 1] = row[i]
        end
    end

    -- 2. 合并相邻相同的
    local merged = {}
    local i = 1
    while i <= #nonZero do
        if i + 1 <= #nonZero and nonZero[i] == nonZero[i + 1] then
            local val = nonZero[i] * 2
            merged[#merged + 1] = val
            mergedScore = mergedScore + val
            i = i + 2
        else
            merged[#merged + 1] = nonZero[i]
            i = i + 1
        end
    end

    -- 3. 填充零
    for j = 1, GRID_SIZE do
        newRow[j] = merged[j] or 0
    end

    -- 4. 检查是否有变化
    for j = 1, GRID_SIZE do
        if newRow[j] ~= row[j] then
            hasMoved = true
            break
        end
    end

    return newRow, mergedScore, hasMoved
end

--- 移动整个棋盘
function Move(direction)
    if gameOver then return false end
    if gameWon and not canContinue then return false end

    moved = false
    local totalScore = 0

    if direction == "left" then
        for r = 1, GRID_SIZE do
            local newRow, s, m = SlideRowLeft(board[r])
            if m then moved = true end
            totalScore = totalScore + s
            board[r] = newRow
        end
    elseif direction == "right" then
        for r = 1, GRID_SIZE do
            -- 翻转行，左移，再翻转
            local reversed = {}
            for c = 1, GRID_SIZE do
                reversed[c] = board[r][GRID_SIZE + 1 - c]
            end
            local newRow, s, m = SlideRowLeft(reversed)
            if m then moved = true end
            totalScore = totalScore + s
            for c = 1, GRID_SIZE do
                board[r][c] = newRow[GRID_SIZE + 1 - c]
            end
        end
    elseif direction == "up" then
        for c = 1, GRID_SIZE do
            local col = {}
            for r = 1, GRID_SIZE do col[r] = board[r][c] end
            local newCol, s, m = SlideRowLeft(col)
            if m then moved = true end
            totalScore = totalScore + s
            for r = 1, GRID_SIZE do board[r][c] = newCol[r] end
        end
    elseif direction == "down" then
        for c = 1, GRID_SIZE do
            local col = {}
            for r = 1, GRID_SIZE do col[r] = board[GRID_SIZE + 1 - r][c] end
            local newCol, s, m = SlideRowLeft(col)
            if m then moved = true end
            totalScore = totalScore + s
            for r = 1, GRID_SIZE do board[r][c] = newCol[GRID_SIZE + 1 - r] end
        end
    end

    if moved then
        score = score + totalScore
        if score > bestScore then bestScore = score end
        AddRandomTile()
        CheckGameState()
        RefreshUI()
    end

    return moved
end

--- 检查游戏状态
function CheckGameState()
    -- 检查是否达成 2048
    if not gameWon then
        for r = 1, GRID_SIZE do
            for c = 1, GRID_SIZE do
                if board[r][c] == 2048 then
                    gameWon = true
                    return
                end
            end
        end
    end

    -- 检查是否还有空格
    if #GetEmptyCells() > 0 then return end

    -- 检查是否还能合并
    for r = 1, GRID_SIZE do
        for c = 1, GRID_SIZE do
            local val = board[r][c]
            if c < GRID_SIZE and board[r][c + 1] == val then return end
            if r < GRID_SIZE and board[r + 1][c] == val then return end
        end
    end

    gameOver = true
end

--- 获取方块颜色
function GetTileColor(value)
    if TILE_COLORS[value] then
        return TILE_COLORS[value]
    end
    -- 超过2048的方块用深色
    return { bg = {60, 58, 50, 255}, fg = {249, 246, 242, 255} }
end

--- 获取方块字体大小
function GetTileFontSize(value)
    if value < 100 then return 28
    elseif value < 1000 then return 24
    elseif value < 10000 then return 20
    else return 16
    end
end

-- ============================================================================
-- UI 构建
-- ============================================================================

--- 创建单个方块
function CreateTile(r, c)
    local value = board[r][c]
    local colors = GetTileColor(value)

    local children = {}
    if value > 0 then
        children[1] = UI.Label {
            id = "tileText_" .. r .. "_" .. c,
            text = tostring(value),
            fontSize = GetTileFontSize(value),
            fontWeight = "bold",
            fontColor = colors.fg,
            textAlign = "center",
        }
    end

    return UI.Panel {
        id = "tile_" .. r .. "_" .. c,
        width = 58,
        height = 58,
        borderRadius = 6,
        backgroundColor = colors.bg,
        justifyContent = "center",
        alignItems = "center",
        children = children,
    }
end

--- 创建棋盘 UI
function CreateBoardUI()
    local rows = {}
    for r = 1, GRID_SIZE do
        local tiles = {}
        for c = 1, GRID_SIZE do
            tiles[c] = CreateTile(r, c)
        end
        rows[r] = UI.Panel {
            flexDirection = "row",
            gap = 6,
            children = tiles,
        }
    end

    return UI.Panel {
        id = "boardContainer",
        padding = 6,
        gap = 6,
        backgroundColor = {187, 173, 160, 255},
        borderRadius = 8,
        alignItems = "center",
        children = rows,
    }
end

--- 创建分数面板
function CreateScorePanel(label, value, id)
    return UI.Panel {
        id = id,
        width = 80,
        paddingVertical = 6,
        paddingHorizontal = 12,
        backgroundColor = {187, 173, 160, 255},
        borderRadius = 6,
        alignItems = "center",
        gap = 2,
        children = {
            UI.Label {
                text = label,
                fontSize = 10,
                fontColor = {238, 228, 218, 255},
                textAlign = "center",
            },
            UI.Label {
                id = id .. "Value",
                text = tostring(value),
                fontSize = 18,
                fontWeight = "bold",
                fontColor = {255, 255, 255, 255},
                textAlign = "center",
            },
        },
    }
end

--- 创建覆盖层 (游戏结束/胜利)
function CreateOverlay()
    if gameOver then
        return UI.Panel {
            id = "overlay",
            position = "absolute",
            top = 0, left = 0, right = 0, bottom = 0,
            backgroundColor = {238, 228, 218, 130},
            borderRadius = 8,
            justifyContent = "center",
            alignItems = "center",
            gap = 12,
            pointerEvents = "auto",
            children = {
                UI.Label {
                    text = "Game Over!",
                    fontSize = 28,
                    fontWeight = "bold",
                    fontColor = {119, 110, 101, 255},
                },
                UI.Button {
                    text = "Try Again",
                    variant = "primary",
                    onClick = function(self)
                        InitBoard()
                        RefreshUI()
                    end,
                },
            },
        }
    elseif gameWon and not canContinue then
        return UI.Panel {
            id = "overlay",
            position = "absolute",
            top = 0, left = 0, right = 0, bottom = 0,
            backgroundColor = {237, 194, 46, 130},
            borderRadius = 8,
            justifyContent = "center",
            alignItems = "center",
            gap = 12,
            pointerEvents = "auto",
            children = {
                UI.Label {
                    text = "You Win!",
                    fontSize = 28,
                    fontWeight = "bold",
                    fontColor = {249, 246, 242, 255},
                },
                UI.Panel {
                    flexDirection = "row",
                    gap = 8,
                    children = {
                        UI.Button {
                            text = "Continue",
                            variant = "primary",
                            onClick = function(self)
                                canContinue = true
                                RefreshUI()
                            end,
                        },
                        UI.Button {
                            text = "New Game",
                            onClick = function(self)
                                InitBoard()
                                RefreshUI()
                            end,
                        },
                    },
                },
            },
        }
    end
    return nil
end

--- 构建完整 UI
function BuildUI()
    local boardUI = CreateBoardUI()
    local overlay = CreateOverlay()

    -- 棋盘包装（带覆盖层）
    local boardWrapChildren = { boardUI }
    if overlay then
        boardWrapChildren[#boardWrapChildren + 1] = overlay
    end

    local boardWrap = UI.Panel {
        id = "boardWrap",
        children = boardWrapChildren,
    }

    uiRoot_ = UI.Panel {
        id = "gameRoot",
        width = "100%",
        height = "100%",
        backgroundColor = {250, 248, 239, 255},
        justifyContent = "center",
        alignItems = "center",
        gap = 16,
        pointerEvents = "box-none",
        children = {
            -- 标题
            UI.Label {
                text = "2048",
                fontSize = 48,
                fontWeight = "bold",
                fontColor = {119, 110, 101, 255},
            },
            -- 分数区域
            UI.Panel {
                flexDirection = "row",
                gap = 8,
                alignItems = "center",
                children = {
                    CreateScorePanel("SCORE", score, "score"),
                    CreateScorePanel("BEST", bestScore, "best"),
                },
            },
            -- 棋盘
            boardWrap,
            -- 新游戏按钮
            UI.Button {
                text = "New Game",
                variant = "primary",
                paddingHorizontal = 24,
                onClick = function(self)
                    InitBoard()
                    RefreshUI()
                end,
            },
            -- 操作提示
            UI.Label {
                text = "Arrow Keys / WASD / Swipe",
                fontSize = 12,
                fontColor = {170, 160, 150, 255},
            },
        },
    }

    UI.SetRoot(uiRoot_)
end

--- 刷新 UI (重建)
function RefreshUI()
    BuildUI()
end

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = "2048"

    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })

    math.randomseed(os.time())
    InitBoard()
    BuildUI()

    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")

    print("=== 2048 Game Started ===")
    print("Controls: Arrow Keys / WASD / Swipe")
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- 输入处理
-- ============================================================================

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if key == KEY_UP or key == KEY_W then
        Move("up")
    elseif key == KEY_DOWN or key == KEY_S then
        Move("down")
    elseif key == KEY_LEFT or key == KEY_A then
        Move("left")
    elseif key == KEY_RIGHT or key == KEY_D then
        Move("right")
    elseif key == KEY_R then
        InitBoard()
        RefreshUI()
    end
end

--- 处理鼠标滑动 (开始)
---@param eventType string
---@param eventData MouseButtonDownEventData
function HandleMouseDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button == MOUSEB_LEFT then
        touchStartX = eventData["X"]:GetInt()
        touchStartY = eventData["Y"]:GetInt()
        isTouching = true
    end
end

--- 处理鼠标滑动 (结束)
---@param eventType string
---@param eventData MouseButtonUpEventData
function HandleMouseUp(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button == MOUSEB_LEFT and isTouching then
        local endX = eventData["X"]:GetInt()
        local endY = eventData["Y"]:GetInt()
        ProcessSwipe(touchStartX, touchStartY, endX, endY)
        isTouching = false
    end
end

--- 鼠标移动 (空实现，保留以避免报错)
function HandleMouseMove(eventType, eventData)
end

--- 处理触摸滑动 (开始)
---@param eventType string
---@param eventData TouchBeginEventData
function HandleTouchBegin(eventType, eventData)
    touchStartX = eventData["X"]:GetInt()
    touchStartY = eventData["Y"]:GetInt()
    isTouching = true
end

--- 处理触摸滑动 (结束)
---@param eventType string
---@param eventData TouchEndEventData
function HandleTouchEnd(eventType, eventData)
    if isTouching then
        local endX = eventData["X"]:GetInt()
        local endY = eventData["Y"]:GetInt()
        ProcessSwipe(touchStartX, touchStartY, endX, endY)
        isTouching = false
    end
end

--- 处理滑动方向判定
function ProcessSwipe(startX, startY, endX, endY)
    local dx = endX - startX
    local dy = endY - startY
    local absDx = math.abs(dx)
    local absDy = math.abs(dy)

    -- 距离太短不算滑动
    if absDx < SWIPE_THRESHOLD and absDy < SWIPE_THRESHOLD then
        return
    end

    if absDx > absDy then
        -- 水平滑动
        if dx > 0 then
            Move("right")
        else
            Move("left")
        end
    else
        -- 垂直滑动
        if dy > 0 then
            Move("down")
        else
            Move("up")
        end
    end
end

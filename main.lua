local tick = require("tick")
local lume = require("lume")
local s = require("say")

-- colors
local color_bg = {238/255, 236/255, 237/255}  -- #eeeced
local color_fg = {98/255, 114/255, 122/255}  -- #62727a
local color_cell = {74/255, 195/255, 203/255}  -- #4ac3cb
local color_mine = {229/255, 81/255, 109/255}  -- #e5516d
local color_mine_open = {229/255, 81/255, 109/255, 0.25}  -- #e5516d
local color_empty_cell = {98/255, 114/255, 122/255, 0.25}  -- #62727a
local color_press_cell = {255/255, 221/255, 103/255}  -- #ffdd67

-- images
local image_paper = love.graphics.newImage("images/paper.png")
local image_cell = love.graphics.newImage("images/cell.png")
local image_flag = love.graphics.newImage("images/flag.png")
local image_menu = love.graphics.newImage("images/menu.png")
local image_back = love.graphics.newImage("images/back.png")
local image_info = love.graphics.newImage("images/info.png")
local image_easy = love.graphics.newImage("images/easy.png")
local image_normal = love.graphics.newImage("images/normal.png")
local image_hard = love.graphics.newImage("images/hard.png")
local image_random = love.graphics.newImage("images/random.png")
local image_action_pick = love.graphics.newImage("images/action_pick.png")
local image_action_flag = love.graphics.newImage("images/action_flag.png")
local image_lose = love.graphics.newImage("images/lose.png")
local image_win = love.graphics.newImage("images/win.png")
local image_game_over = image_win
local image_collision = love.graphics.newImage("images/collision.png")
local image_easy_mode = love.graphics.newImage("images/easy_mode.png")
local image_normal_mode = love.graphics.newImage("images/normal_mode.png")
local image_hard_mode = love.graphics.newImage("images/hard_mode.png")
local image_random_mode = love.graphics.newImage("images/random_mode.png")
local image_lang = love.graphics.newImage("images/lang.png")
local image_move = love.graphics.newImage("images/move.png")
local image_stop = love.graphics.newImage("images/stop.png")
local image_sound = love.graphics.newImage("images/sound.png")
local image_mute = love.graphics.newImage("images/mute.png")
local image_about = love.graphics.newImage("images/about.png")
local image_exit = love.graphics.newImage("images/exit.png")

-- calculate
local offset = 18
local cell_size = 64
local k_scale = 1
local game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", 32 )
local coord = {}

-- game
local matrix = {}
local group = tick.group()
local board = {16, 8, 20}  -- width, height, mines
local action = "pick"  -- "flag"
local game_mode = "easy"  -- normal, hard, random
local press_cell = {0, 0}
local press_button = ""  -- menu, action, hard, normal, easy, random, lang, about, anim, sound, exit
local is_new_game = false
local is_game_over = true
local is_show_menu = false
local is_show_info = false
local is_sound = true
local is_anim = true
local k_anim = 1
local vector_anim = -1
local particles = {}
local count_cell = 0
local game_lang = "ru"  -- "en" or "ru"
local info_text = "Info text"  -- "About text"

-- audio
local sound_click = love.audio.newSource("audio/click.ogg", "static")
local sound_open = love.audio.newSource("audio/open.ogg", "static")
local sound_error = love.audio.newSource("audio/error.ogg", "static")
local sound_lose = love.audio.newSource("audio/lose.ogg", "static")
local sound_win = love.audio.newSource("audio/win.ogg", "static")


local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


local function resize()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    offset = math.min(W, H) / 40
    cell_size = math.min( (math.max(W, H) - offset * 3) / 18, (math.min(W, H) - offset * 2) / 8 )
    k_scale = cell_size / image_cell:getWidth()
    k_anim = 1
    vector_anim = -1
    game_font = love.graphics.newFont( "JetBrainsMono-ExtraBold.ttf", cell_size * 0.5 )
    love.graphics.setFont(game_font)

    if W > H then
        coord.menu = {x = offset, y = offset}
        coord.action = {x = offset, y = H - cell_size * 2 - offset}
        coord.ptext = {x = offset + cell_size * 0.3, y = H - cell_size * 2 - offset * 2, rad = - math.pi / 2}
        coord.gmode = {x = offset, y = offset + cell_size * 2}
    else
        coord.menu = {x = W - cell_size * 2 - offset, y = offset}
        coord.action = {x = offset, y = offset}
        coord.ptext = {x = offset * 2 + cell_size * 2, y = offset + cell_size * 0.3, rad = 0}
        coord.gmode = {x = W - cell_size * 4 - offset, y = offset}
    end

    local particles_colors = { {66/255, 173/255, 226/255}, {237/255, 76/255, 92/255}, {255/255, 135/255, 54/255}, {194/255, 143/255, 239/255} }
    local particles_alpha = {0.3, 0.6}
    for p=1,#particles do
        particles[p].size = love.math.random( math.floor(cell_size/10), math.ceil(cell_size/5) )
        particles[p].x = love.math.random( 0, W - particles[p].size )
        particles[p].y = love.math.random( 0, H - particles[p].size )
        local c = love.math.random( 1, 4 )
        local a = love.math.random( 1, 2 )
        local pc = particles_colors[c]
        pc[4] = particles_alpha[a]
        particles[p].color = pc
    end
end


local function new_game(width, height, mines, gmode)
    is_game_over = true
    local w, h, m, g = width or 8, height or 8, mines or 10, gmode or "easy"

    -- очистка, чтобы не было сбоя цикла рисования
    board = {1, 1, 1}
    local new_matrix = {}
    for row=1,h do
        table.insert(new_matrix, {})
        for _col=1,w do
            table.insert(new_matrix[row], {value=0, flag=0, open=0})
        end
    end

    matrix = new_matrix
    board = {w, h, m}
    game_mode = g
    count_cell = w * h

    is_new_game = true
    is_game_over = false
end


local function save_game()
    local data = {}
    data.matrix = deepcopy(matrix)
    data.board = deepcopy(board)
    data.action = action
    data.game_mode = game_mode
    data.is_new_game = is_new_game
    data.is_game_over = is_game_over
    data.is_sound = is_sound
    data.is_anim = is_anim
    data.count_cell = count_cell
    data.game_lang = game_lang

    local result = "win"
    if image_game_over ~= image_win then result = "lose" end
    data.result = result

    local serialized = lume.serialize(data)
    love.filesystem.write("data", serialized)
end


function love.load()
    -- Internationalization
    -- EN
    s:set_namespace("en")
    s:set("Info text", [[MINES (sapper)
Open all the cells on the field except those containing mines. The number in the open cell indicates the number of mines in the adjacent cells. You can mark a cell with a flag if you think it is mined. A cell with a flag is blocked from being opened accidentally. Use tapping on numbers to recursively chord flags and open cells. Good luck!]])
    s:set("About text", [[ABOUT GAME

Images: Emojitwo
emojitwo.github.io

The Programming Language Lua
lua.org

LÖVE Free 2D Game Engine
love2d.org

(c) 2026 Anton Bezdolny
avbezdolny.github.io]])

    -- RU
    s:set_namespace("ru")
    s:set("Info text", [[МИНЫ (сапер)
Откройте все ячейки на поле, кроме содержащих мины. Число в открытой ячейке означает количество мин в соседних ячейках. Можно пометить ячейку флагом, если считаете, что она заминирована. Ячейка с флагом заблокирована от случайного открытия. Используйте нажатия на числа для рекурсивного аккорда флагами и открытия соседних ячеек. Удачи!]])
    s:set("About text", [[ОБ ИГРЕ

Изображения: Emojitwo
emojitwo.github.io

Язык Программирования Lua
lua.org

LÖVE Свободный 2D Игровой Движок
love2d.org

(c) 2026 Антон Бездольный
avbezdolny.github.io]])

    s:set_namespace(game_lang)
    love.graphics.setBackgroundColor(color_bg)

    coord.menu = {x = 0, y = 0}
    coord.action = {x = 0, y = 0}
    coord.ptext = {x = 0, y = 0, rad = 0}
    coord.gmode = {x = 0, y = 0}

    -- default matrix
    for row=1,board[2] do
        table.insert(matrix, {})
        for _col=1,board[1] do
            table.insert(matrix[row], {value=0, flag=0, open=0})
        end
    end

    -- default particles
    for _p=1,90 do
        table.insert( particles, {x=0, y=0, size=10, color=color_empty_cell} )
    end

    -- load saved file
    local data = nil
    local status, err = pcall( function()
        if love.filesystem.getInfo("data") then
            local file = love.filesystem.read("data")
            if file then data = lume.deserialize(file) end
        end
    end )

    if status and data then
        local ok, msg = pcall( function()
            if not (data.is_game_over == true or data.is_game_over == false) then error("Incorrect save data!")
            else is_game_over = data.is_game_over end

            if not (data.is_new_game == true or data.is_new_game == false) then error("Incorrect save data!")
            else is_new_game = data.is_new_game end

            if not (data.is_anim == true or data.is_anim == false) then error("Incorrect save data!")
            else is_anim = data.is_anim end

            if not (data.is_sound == true or data.is_sound == false) then error("Incorrect save data!")
            else is_sound = data.is_sound end

            if not (data.game_lang == "en" or data.game_lang == "ru") then error("Incorrect save data!")
            else
                game_lang = data.game_lang
                s:set_namespace(game_lang)
            end

            if not (data.action == "pick" or data.action == "flag") then error("Incorrect save data!")
            else action = data.action end

            if not (data.game_mode == "easy" or data.game_mode == "normal" or data.game_mode == "hard" or data.game_mode == "random") then error("Incorrect save data!")
            else game_mode = data.game_mode end

            if not (data.result == "lose" or data.result == "win") then error("Incorrect save data!")
            elseif data.result == "lose" then image_game_over = image_lose end

            if not (data.board[1] >= 8 and data.board[1] <= 16 and data.board[2] == 8 and data.board[3] >= 10 and data.board[3] <= 32) then
                error("Incorrect save data!")
            else
                board = {data.board[1], data.board[2], data.board[3]}
            end

            if not (data.count_cell >= board[3] and data.count_cell <= board[1] * board[2]) then
                error("Incorrect save data!")
            else
                count_cell = data.count_cell
            end

            local temp_matrix = {}
            for row=1,board[2] do
                table.insert(temp_matrix, {})
                for col=1,board[1] do
                    if not (data.matrix[row][col].value >= -1 and data.matrix[row][col].value <= 8 and (data.matrix[row][col].flag == 0 or data.matrix[row][col].flag == 1) and (data.matrix[row][col].open == 0 or data.matrix[row][col].open == 1)) then error("Incorrect save data!")
                    else table.insert(temp_matrix[row], {value=data.matrix[row][col].value, flag=data.matrix[row][col].flag, open=data.matrix[row][col].open}) end
                end
            end
            matrix = temp_matrix
        end )

        if not ok then
            love.window.showMessageBox("Message", "Error reading saved data!\n" .. (msg or "..."), "error")
            new_game()
        end
    else
        --love.window.showMessageBox("Message", "Saved data was not found!\n" .. (err or "..."), "info")
        new_game()
    end

    resize()
end


function love.update(dt)
    group:update(dt)
    if is_anim then
        -- BOOM
        k_anim = k_anim + vector_anim * dt
        if k_anim >= 1 then
            vector_anim = -1
        elseif k_anim <= 0.5 then
            vector_anim = 1
        end

        -- particles
        for p=1,#particles do
            particles[p].y = particles[p].y + particles[p].size * dt * 6
            if particles[p].y > love.graphics.getHeight() then
                local particles_colors = { {66/255, 173/255, 226/255}, {237/255, 76/255, 92/255}, {255/255, 135/255, 54/255}, {194/255, 143/255, 239/255} }
                local particles_alpha = {0.3, 0.6}
                particles[p].size = love.math.random( math.floor(cell_size/10), math.ceil(cell_size/5) )
                particles[p].x = love.math.random( 0, love.graphics.getWidth() - particles[p].size )
                particles[p].y = love.math.random( 0, -particles[p].size )
                local c = love.math.random( 1, 4 )
                local a = love.math.random( 1, 2 )
                local pc = particles_colors[c]
                pc[4] = particles_alpha[a]
                particles[p].color = pc
            end
        end
    end
end


function love.draw()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- background image
    love.graphics.setColor(1, 1, 1, 1)
    for y = 0, H, 800 do
        for x = 0, W, 800 do
            love.graphics.draw(image_paper, x, y)
        end
    end

    -- particles
    for p=1,#particles do
        love.graphics.setColor(particles[p].color)
        love.graphics.rectangle("fill", particles[p].x, particles[p].y, particles[p].size, particles[p].size)
    end

    local i_w = 1
    local i_h = 2
    local o_x = offset + cell_size * 2
    local o_y = 0
    if H >= W then
        i_w = 2
        i_h = 1
        o_x = 0
        o_y = offset + cell_size * 2
    end
    local b_x = o_x + (W - o_x) / 2 - (board[i_w] * cell_size) / 2
    local b_y = o_y + (H - o_y) / 2 - (board[i_h] * cell_size) / 2
    local m_x = b_x + (board[i_w] * cell_size) / 2 - cell_size * 4
    local m_y = b_y + (board[i_h] * cell_size) / 2 - cell_size * 4

    -- game board
    --love.graphics.rectangle("fill", b_x, b_y, board[i_w] * cell_size, board[i_h] * cell_size)
    if not is_show_menu and not is_show_info then
        for row=1,board[i_h] do
            for col=1,board[i_w] do
                local i = row
                local j = col
                if H >= W then
                    i = board[2] - (col - 1)
                    j = row
                end

                -- cell field
                if row == press_cell[1] and col == press_cell[2] then
                    love.graphics.setColor(color_press_cell)
                else
                    if matrix[i][j].open == 1 then
                        if matrix[i][j].value == -1 then love.graphics.setColor(color_mine_open) else love.graphics.setColor(color_empty_cell) end
                    else
                        if is_game_over and matrix[i][j].value == -1 then love.graphics.setColor(color_mine) else love.graphics.setColor(color_cell) end
                    end
                end
                love.graphics.draw(image_cell, b_x + cell_size * (col - 1), b_y + cell_size * (row - 1), 0, k_scale, k_scale)

                -- cell content
                if matrix[i][j].open == 1 then
                    if matrix[i][j].value > 0 then
                        love.graphics.setColor(color_fg)
                        love.graphics.printf(matrix[i][j].value, b_x + cell_size * (col - 1), b_y + cell_size * (row - 1) + cell_size * 0.15, cell_size, "center")
                    elseif matrix[i][j].value == -1 then  -- BOOM
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(image_collision, b_x + cell_size * (col - 1) + cell_size * 0.5, b_y + cell_size * (row - 1) + cell_size * 0.5, 0, k_scale * k_anim, k_scale * k_anim, image_collision:getWidth() * 0.5, image_collision:getHeight() * 0.5)
                    end
                else
                    if matrix[i][j].flag == 1 then
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(image_flag, b_x + cell_size * (col - 1), b_y + cell_size * (row - 1), 0, k_scale, k_scale)
                    end
                end
            end
        end
    end

    -- panel (menu, action)
    if press_button == "menu" then love.graphics.setColor(color_bg) else love.graphics.setColor(1, 1, 1, 1) end
    if not is_show_menu then love.graphics.draw(image_menu, coord.menu.x, coord.menu.y, 0, k_scale * 2, k_scale * 2) else love.graphics.draw(image_back, coord.menu.x, coord.menu.y, 0, k_scale * 2, k_scale * 2) end
    if press_button == "action" then love.graphics.setColor(color_bg) else love.graphics.setColor(1, 1, 1, 1) end
    if not is_show_menu and not is_show_info then
        if not is_game_over then
            if action == "pick" then
                love.graphics.draw(image_action_pick, coord.action.x, coord.action.y, 0, k_scale * 2, k_scale * 2)
            else
                love.graphics.draw(image_action_flag, coord.action.x, coord.action.y, 0, k_scale * 2, k_scale * 2)
            end
        else
            love.graphics.draw(image_game_over, coord.action.x, coord.action.y, 0, k_scale * 2, k_scale * 2)
        end

        love.graphics.setColor(color_fg)
        game_font:setLineHeight( 1.0 )
        love.graphics.printf(board[1] .. "x" .. board[2] .. "\n" .. board[3] .. "/" .. count_cell, coord.ptext.x, coord.ptext.y, cell_size * 2, "left", coord.ptext.rad)

        love.graphics.setColor(1, 1, 1, 1)
        if game_mode == "easy" then
            love.graphics.draw(image_easy, coord.gmode.x, coord.gmode.y, 0, k_scale * 2, k_scale * 2)
        elseif game_mode == "normal" then
            love.graphics.draw(image_normal, coord.gmode.x, coord.gmode.y, 0, k_scale * 2, k_scale * 2)
        elseif game_mode == "hard" then
            love.graphics.draw(image_hard, coord.gmode.x, coord.gmode.y, 0, k_scale * 2, k_scale * 2)
        elseif game_mode == "random" then
            love.graphics.draw(image_random, coord.gmode.x, coord.gmode.y, 0, k_scale * 2, k_scale * 2)
        end
    elseif is_show_menu then
        love.graphics.draw(image_info, coord.action.x, coord.action.y, 0, k_scale * 2, k_scale * 2)
    elseif is_show_info then
        love.graphics.draw(image_back, coord.action.x, coord.action.y, 0, k_scale * 2, k_scale * 2)
    end

    -- menu (hard, normal, easy, random, lang, about, anim, sound, exit)
    if is_show_menu then
        --love.graphics.rectangle("fill", m_x, m_y, 8 * cell_size, 8 * cell_size)
        if press_button == "hard" then love.graphics.setColor(color_bg) else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.draw(image_hard_mode, m_x, m_y, 0, k_scale * 2.7, k_scale * 2.7)
        if press_button == "normal" then love.graphics.setColor(color_bg) else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.draw(image_normal_mode, m_x + cell_size * 2.7, m_y, 0, k_scale * 2.7, k_scale * 2.7)
        if press_button == "easy" then love.graphics.setColor(color_bg) else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.draw(image_easy_mode, m_x + cell_size * 5.4, m_y, 0, k_scale * 2.7, k_scale * 2.7)

        if press_button == "random" then love.graphics.setColor(color_bg) else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.draw(image_random_mode, m_x, m_y + cell_size * 2.7, 0, k_scale * 2.7, k_scale * 2.7)
        if press_button == "lang" then love.graphics.setColor(color_bg) else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.draw(image_lang, m_x + cell_size * 2.7, m_y + cell_size * 2.7, 0, k_scale * 2.7, k_scale * 2.7)
        love.graphics.setColor(color_fg)
        love.graphics.printf(game_lang, m_x + cell_size * 3.2, m_y + cell_size * 4.3, cell_size)
        if press_button == "about" then love.graphics.setColor(color_bg) else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.draw(image_about, m_x + cell_size * 5.4, m_y + cell_size * 2.7, 0, k_scale * 2.7, k_scale * 2.7)

        if press_button == "anim" then love.graphics.setColor(color_bg) else love.graphics.setColor(1, 1, 1, 1) end
        if is_anim then love.graphics.draw(image_move, m_x, m_y + cell_size * 5.4, 0, k_scale * 2.7, k_scale * 2.7) else love.graphics.draw(image_stop, m_x, m_y + cell_size * 5.4, 0, k_scale * 2.7, k_scale * 2.7) end
        if press_button == "sound" then love.graphics.setColor(color_bg) else love.graphics.setColor(1, 1, 1, 1) end
        if is_sound then love.graphics.draw(image_sound, m_x + cell_size * 2.7, m_y + cell_size * 5.4, 0, k_scale * 2.7, k_scale * 2.7) else love.graphics.draw(image_mute, m_x + cell_size * 2.7, m_y + cell_size * 5.4, 0, k_scale * 2.7, k_scale * 2.7) end
        if press_button == "exit" then love.graphics.setColor(color_bg) else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.draw(image_exit, m_x + cell_size * 5.4, m_y + cell_size * 5.4, 0, k_scale * 2.7, k_scale * 2.7)
    end

    -- info
    if is_show_info then
        love.graphics.setColor(color_fg)
        game_font:setLineHeight( 0.8 )
        local ty = 0
        if info_text == "About text" then ty = cell_size * 0.3 end
        love.graphics.printf(s(info_text), m_x, m_y + ty, cell_size * 8, "center")
    end
end


function love.resize(w, h)
    --print(("Window resized to width: %d and height: %d."):format(w, h))
    group:delay(function() resize() end, 0.150)
end


local function is_collide(point_x, point_y, rect_x, rect_y, rect_w, rect_h)  -- пересечение точки с прямоугольником
    return point_x >= rect_x and point_x <= rect_x + rect_w and point_y >= rect_y and point_y <= rect_y + rect_h
end


local function cascad_open(i, j)
    local i_r = i
    local i_c = j - 1
    if i_c > 0 then
        open_cell(i_r, i_c)
        i_r = i - 1
        if i_r > 0 then open_cell(i_r, i_c) end
        i_r = i + 1
        if i_r <= board[2] then open_cell(i_r, i_c) end
    end

    i_r = i
    i_c = j + 1
    if i_c <= board[1] then
        open_cell(i_r, i_c)
        i_r = i - 1
        if i_r > 0 then open_cell(i_r, i_c) end
        i_r = i + 1
        if i_r <= board[2] then open_cell(i_r, i_c) end
    end

    i_r = i - 1
    i_c = j
    if i_r > 0 then open_cell(i_r, i_c) end

    i_r = i + 1
    i_c = j
    if i_r <= board[2] then open_cell(i_r, i_c) end
end


---@diagnostic disable-next-line: lowercase-global
function open_cell(i, j)
    if matrix[i][j].open == 0 and matrix[i][j].flag ~= 1 then
        matrix[i][j].open = 1
        count_cell = count_cell - 1

        if is_new_game then  -- растановка мин
            is_new_game = false

            local temp_matrix = {}
            for row=1,board[2] do
                for col=1,board[1] do
                    if row ~= i and col ~= j then table.insert(temp_matrix, {row, col}) end
                end
            end

            temp_matrix = lume.shuffle(temp_matrix)
            for m=1,board[3] do
                matrix[ temp_matrix[m][1] ][ temp_matrix[m][2] ].value = -1
            end

            for r=1,board[2] do
                for c=1,board[1] do
                    if matrix[r][c].value ~= -1 then
                        local i_r = r
                        local i_c = c - 1
                        if i_c > 0 then
                            if matrix[i_r][i_c].value == -1 then matrix[r][c].value = matrix[r][c].value + 1 end
                            i_r = r - 1
                            if i_r > 0 then
                                if matrix[i_r][i_c].value == -1 then matrix[r][c].value = matrix[r][c].value + 1 end
                            end
                            i_r = r + 1
                            if i_r <= board[2] then
                                if matrix[i_r][i_c].value == -1 then matrix[r][c].value = matrix[r][c].value + 1 end
                            end
                        end

                        i_r = r
                        i_c = c + 1
                        if i_c <= board[1] then
                            if matrix[i_r][i_c].value == -1 then matrix[r][c].value = matrix[r][c].value + 1 end
                            i_r = r - 1
                            if i_r > 0 then
                                if matrix[i_r][i_c].value == -1 then matrix[r][c].value = matrix[r][c].value + 1 end
                            end
                            i_r = r + 1
                            if i_r <= board[2] then
                                if matrix[i_r][i_c].value == -1 then matrix[r][c].value = matrix[r][c].value + 1 end
                            end
                        end

                        i_r = r - 1
                        i_c = c
                        if i_r > 0 then
                            if matrix[i_r][i_c].value == -1 then matrix[r][c].value = matrix[r][c].value + 1 end
                        end

                        i_r = r + 1
                        i_c = c
                        if i_r <= board[2] then
                            if matrix[i_r][i_c].value == -1 then matrix[r][c].value = matrix[r][c].value + 1 end
                        end
                    end
                end
            end
        end

        if matrix[i][j].value == -1 then
            is_game_over = true
            image_game_over = image_lose
            if is_sound then sound_lose:play() end
            love.system.vibrate(0.150)
        elseif count_cell == board[3] then
            is_game_over = true
            image_game_over = image_win
            if is_sound then sound_win:play() end
        end

        if matrix[i][j].value == 0 then  -- каскад
            group:delay(function() cascad_open(i, j) end, 0.050)
        end
    end
end


local function count_close_and_flag(i, j)
    local count_close = 0
    local count_flag = 0

    if matrix[i][j].open == 0 then
        count_close = 1
        if matrix[i][j].flag == 1 then count_flag = 1 end
    end

    return count_close, count_flag
end


local function accord(i, j, val)
    local count_close = 0
    local count_flag = 0
    local cc = 0
    local cf = 0
    local close_list = {}

    local i_r = i
    local i_c = j - 1
    if i_c > 0 then
        cc, cf = count_close_and_flag(i_r, i_c)
        if cc == 1 then table.insert(close_list, {i_r, i_c}) end
        count_close = count_close + cc
        count_flag = count_flag + cf
        i_r = i - 1
        if i_r > 0 then
            cc, cf = count_close_and_flag(i_r, i_c)
            if cc == 1 then table.insert(close_list, {i_r, i_c}) end
            count_close = count_close + cc
            count_flag = count_flag + cf
        end
        i_r = i + 1
        if i_r <= board[2] then
            cc, cf = count_close_and_flag(i_r, i_c)
            if cc == 1 then table.insert(close_list, {i_r, i_c}) end
            count_close = count_close + cc
            count_flag = count_flag + cf
        end
    end

    i_r = i
    i_c = j + 1
    if i_c <= board[1] then
        cc, cf = count_close_and_flag(i_r, i_c)
        if cc == 1 then table.insert(close_list, {i_r, i_c}) end
        count_close = count_close + cc
        count_flag = count_flag + cf
        i_r = i - 1
        if i_r > 0 then
            cc, cf = count_close_and_flag(i_r, i_c)
            if cc == 1 then table.insert(close_list, {i_r, i_c}) end
            count_close = count_close + cc
            count_flag = count_flag + cf
        end
        i_r = i + 1
        if i_r <= board[2] then
            cc, cf = count_close_and_flag(i_r, i_c)
            if cc == 1 then table.insert(close_list, {i_r, i_c}) end
            count_close = count_close + cc
            count_flag = count_flag + cf
        end
    end

    i_r = i - 1
    i_c = j
    if i_r > 0 then
        cc, cf = count_close_and_flag(i_r, i_c)
        if cc == 1 then table.insert(close_list, {i_r, i_c}) end
        count_close = count_close + cc
        count_flag = count_flag + cf
    end

    i_r = i + 1
    i_c = j
    if i_r <= board[2] then
        cc, cf = count_close_and_flag(i_r, i_c)
        if cc == 1 then table.insert(close_list, {i_r, i_c}) end
        count_close = count_close + cc
        count_flag = count_flag + cf
    end

    if count_close == val then
        if is_sound then sound_click:play() end
        for _k, v in pairs(close_list) do
            matrix[v[1]][v[2]].flag = 1
        end
    elseif count_flag == val then
        if is_sound then sound_open:play() end
        for _k, v in pairs(close_list) do
            if matrix[v[1]][v[2]].flag ~= 1 then open_cell(v[1], v[2]) end
        end
    end
end


local function click_cell(i, j)
    if matrix[i][j].open == 0 and action == "pick" and matrix[i][j].flag ~= 1 then
        if is_sound then sound_open:play() end
        open_cell(i, j)
    elseif matrix[i][j].open == 0 and action == "flag" then
        if is_sound then sound_click:play() end
        if matrix[i][j].flag == 0 then matrix[i][j].flag = 1 else matrix[i][j].flag = 0 end
    elseif matrix[i][j].open == 1 and matrix[i][j].value > 0 then
        accord(i, j, matrix[i][j].value)
    else
        if is_sound then sound_error:play() end
    end
end


function love.keypressed(key, scancode, isrepeat)  -- love.keyreleased( key, scancode )
    if key == "escape" then
        if is_sound then sound_click:play() end
        is_show_menu = not is_show_menu
        is_show_info = false
    end
end


function love.mousepressed( x, y, button, istouch, presses )
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    local i_w = 1
    local i_h = 2
    local o_x = offset + cell_size * 2
    local o_y = 0
    if H >= W then
        i_w = 2
        i_h = 1
        o_x = 0
        o_y = offset + cell_size * 2
    end
    local b_x = o_x + (W - o_x) / 2 - (board[i_w] * cell_size) / 2
    local b_y = o_y + (H - o_y) / 2 - (board[i_h] * cell_size) / 2
    local m_x = b_x + (board[i_w] * cell_size) / 2 - cell_size * 4
    local m_y = b_y + (board[i_h] * cell_size) / 2 - cell_size * 4

    if not is_show_menu and not is_show_info then
        -- game board
        if not is_game_over and is_collide(x, y, b_x, b_y, board[i_w] * cell_size, board[i_h] * cell_size) then
            for row=1,board[i_h] do
                for col=1,board[i_w] do
                    if is_collide(x, y, b_x + cell_size * (col - 1), b_y + cell_size * (row - 1), cell_size, cell_size) then
                        press_cell = {row, col}
                        break
                    end
                end
            end
        end
    end

    -- panel (menu, action)
    if is_collide(x, y, coord.menu.x, coord.menu.y, cell_size * 2, cell_size * 2) then
        press_button = "menu"
    elseif is_collide(x, y, coord.action.x, coord.action.y, cell_size * 2, cell_size * 2) then
        press_button = "action"
    end

    -- menu (hard, normal, easy, random, lang, about, anim, sound, exit)
    if is_show_menu then
        if is_collide(x, y, m_x, m_y, cell_size * 2.7, cell_size * 2.7) then
            press_button = "hard"
        elseif is_collide(x, y, m_x + cell_size * 2.7, m_y, cell_size * 2.7, cell_size * 2.7) then
            press_button = "normal"
        elseif is_collide(x, y, m_x + cell_size * 5.4, m_y, cell_size * 2.7, cell_size * 2.7) then
            press_button = "easy"

        elseif is_collide(x, y, m_x, m_y + cell_size * 2.7, cell_size * 2.7, cell_size * 2.7) then
            press_button = "random"
        elseif is_collide(x, y, m_x + cell_size * 2.7, m_y + cell_size * 2.7, cell_size * 2.7, cell_size * 2.7) then
            press_button = "lang"
        elseif is_collide(x, y, m_x + cell_size * 5.4, m_y + cell_size * 2.7, cell_size * 2.7, cell_size * 2.7) then
            press_button = "about"

        elseif is_collide(x, y, m_x, m_y + cell_size * 5.4, cell_size * 2.7, cell_size * 2.7) then
            press_button = "anim"
        elseif is_collide(x, y, m_x + cell_size * 2.7, m_y + cell_size * 5.4, cell_size * 2.7, cell_size * 2.7) then
            press_button = "sound"
        elseif is_collide(x, y, m_x + cell_size * 5.4, m_y + cell_size * 5.4, cell_size * 2.7, cell_size * 2.7) then
            press_button = "exit"
        end
    end
end


function love.mousereleased( x, y, button, istouch, presses )
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    local i_w = 1
    local i_h = 2
    local o_x = offset + cell_size * 2
    local o_y = 0
    if H >= W then
        i_w = 2
        i_h = 1
        o_x = 0
        o_y = offset + cell_size * 2
    end
    local b_x = o_x + (W - o_x) / 2 - (board[i_w] * cell_size) / 2
    local b_y = o_y + (H - o_y) / 2 - (board[i_h] * cell_size) / 2
    local m_x = b_x + (board[i_w] * cell_size) / 2 - cell_size * 4
    local m_y = b_y + (board[i_h] * cell_size) / 2 - cell_size * 4

    if not is_show_menu and not is_show_info then
        -- game board
        if not is_game_over and is_collide(x, y, b_x, b_y, board[i_w] * cell_size, board[i_h] * cell_size) then
            for row=1,board[i_h] do
                for col=1,board[i_w] do
                    if is_collide(x, y, b_x + cell_size * (col - 1), b_y + cell_size * (row - 1), cell_size, cell_size)
                    and row == press_cell[1] and col == press_cell[2] then
                        local i = row
                        local j = col
                        if H >= W then
                            i = board[2] - (col - 1)
                            j = row
                        end
                        click_cell(i, j)
                    end
                end
            end
        end
    end

    -- panel (menu, action)
    if is_collide(x, y, coord.menu.x, coord.menu.y, cell_size * 2, cell_size * 2) and press_button == "menu" then
        if is_sound then sound_click:play() end
        is_show_menu = not is_show_menu
        is_show_info = false
    elseif is_collide(x, y, coord.action.x, coord.action.y, cell_size * 2, cell_size * 2) and press_button == "action" then
        if is_sound then sound_click:play() end
        if not is_show_menu and not is_show_info then
            if not is_game_over then
                if action == "pick" then action = "flag" else action = "pick" end
            else
                new_game(board[1], board[2], board[3], game_mode)
            end
        elseif is_show_menu then  -- info
            info_text = "Info text"
            is_show_menu = false
            is_show_info = true
        elseif is_show_info then
            is_show_info = false
        end
    end

    -- menu (hard, normal, easy, random, lang, about, anim, sound, exit)
    if is_show_menu then
        if is_collide(x, y, m_x, m_y, cell_size * 2.7, cell_size * 2.7) and press_button == "hard" then
            if is_sound then sound_click:play() end
            new_game(16, 8, 30, "hard")
            is_show_menu = false
        elseif is_collide(x, y, m_x + cell_size * 2.7, m_y, cell_size * 2.7, cell_size * 2.7) and press_button == "normal" then
            if is_sound then sound_click:play() end
            new_game(16, 8, 20, "normal")
            is_show_menu = false
        elseif is_collide(x, y, m_x + cell_size * 5.4, m_y, cell_size * 2.7, cell_size * 2.7) and press_button == "easy" then
            if is_sound then sound_click:play() end
            new_game(8, 8, 10, "easy")
            is_show_menu = false

        elseif is_collide(x, y, m_x, m_y + cell_size * 2.7, cell_size * 2.7, cell_size * 2.7) and press_button == "random" then
            if is_sound then sound_click:play() end
            local r_w = love.math.random( 8, 16 )
            local r_m = love.math.random( math.floor(r_w * 8 / 6.4), math.ceil(r_w * 8 / 4) )
            new_game(r_w, 8, r_m, "random")
            is_show_menu = false
        elseif is_collide(x, y, m_x + cell_size * 2.7, m_y + cell_size * 2.7, cell_size * 2.7, cell_size * 2.7) and press_button == "lang" then
            if is_sound then sound_click:play() end
            if game_lang == "en" then game_lang = "ru" else game_lang = "en" end
            s:set_namespace(game_lang)
        elseif is_collide(x, y, m_x + cell_size * 5.4, m_y + cell_size * 2.7, cell_size * 2.7, cell_size * 2.7) and press_button == "about" then
            if is_sound then sound_click:play() end
            info_text = "About text"
            is_show_menu = false
            is_show_info = true

        elseif is_collide(x, y, m_x, m_y + cell_size * 5.4, cell_size * 2.7, cell_size * 2.7) and press_button == "anim" then
            if is_sound then sound_click:play() end
            is_anim = not is_anim
            k_anim = 1
            vector_anim = -1
        elseif is_collide(x, y, m_x + cell_size * 2.7, m_y + cell_size * 5.4, cell_size * 2.7, cell_size * 2.7) and press_button == "sound" then
            if is_sound then sound_click:play() end
            is_sound = not is_sound
        elseif is_collide(x, y, m_x + cell_size * 5.4, m_y + cell_size * 5.4, cell_size * 2.7, cell_size * 2.7) and press_button == "exit" then
            if is_sound then sound_click:play() end
            group:delay(function() love.event.quit(0) end, 0.300)
        end
    end

    press_cell = {0, 0}
    press_button = ""
end


function love.focus(f)
  if not f then  -- Window is not focused
    save_game()
  end
end


function love.quit()
    save_game()
    return false
end

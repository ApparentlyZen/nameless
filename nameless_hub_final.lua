if getgenv().loaded then
    getgenv().library:unload_menu()
end

getgenv().loaded = true

local uis = game:GetService("UserInputService")
local players = game:GetService("Players")
local ws = game:GetService("Workspace")
local http_service = game:GetService("HttpService")
local gui_service = game:GetService("GuiService")
local run = game:GetService("RunService")
local stats = game:GetService("Stats")
local coregui = game:GetService("CoreGui")
local tween_service = game:GetService("TweenService")

local vec2 = Vector2.new
local dim2 = UDim2.new
local dim = UDim.new
local dim_offset = UDim2.fromOffset
local rgb = Color3.fromRGB
local hex = Color3.fromHex
local rgbseq = ColorSequence.new
local rgbkey = ColorSequenceKeypoint.new
local numseq = NumberSequence.new
local numkey = NumberSequenceKeypoint.new

local camera = ws.CurrentCamera
local lp = players.LocalPlayer
local gui_offset = gui_service:GetGuiInset().Y

local floor = math.floor
local random = math.random
local clamp = math.clamp

local insert = table.insert
local find = table.find
local remove = table.remove
local concat = table.concat

getgenv().library = {
    flags = {},
    config_flags = {},
    connections = {},
    gui,
    sgui,
}

local themes = {
    preset = {
        inline = rgb(35, 35, 35),
        text_outline = rgb(0, 0, 0),
        ["1"] = hex("#245771"),
        ["2"] = hex("#215D63"),
        ["3"] = hex("#1E6453"),
    },
    utility = {
        inline = { BackgroundColor3 = {} },
        text = { TextColor3 = {} },
        text_outline = { Color = {} },
        ["1"] = { BackgroundColor3 = {}, TextColor3 = {}, ImageColor3 = {}, ScrollBarImageColor3 = {} },
        ["2"] = { BackgroundColor3 = {}, TextColor3 = {}, ImageColor3 = {}, ScrollBarImageColor3 = {} },
        ["3"] = { BackgroundColor3 = {}, TextColor3 = {}, ImageColor3 = {}, ScrollBarImageColor3 = {} },
    }
}

library.__index = library

local flags = library.flags
local config_flags = library.config_flags

-- FIX : fonts natives Roblox, pas de getcustomasset/writefile
local fonts = {
    ["TahomaBold"]  = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
    ["ProggyClean"] = Font.new("rbxasset://fonts/families/Inconsolata.json"),
}

function library:apply_theme(instance, theme, property)
    insert(themes.utility[theme][property], instance)
end

function library:apply_stroke(parent)
    local s = Instance.new("UIStroke")
    s.Parent = parent
    s.Color = themes.preset.text_outline
    s.LineJoinMode = Enum.LineJoinMode.Miter
    library:apply_theme(s, "text_outline", "Color")
end

function library:create(instance, options)
    local ins = Instance.new(instance)
    for prop, value in next, options do
        ins[prop] = value
    end
    if instance == "TextLabel" or instance == "TextButton" or instance == "TextBox" then
        library:apply_theme(ins, "text", "TextColor3")
        library:apply_stroke(ins)
    end
    return ins
end

function library:connection(signal, callback)
    local c = signal:Connect(callback)
    insert(library.connections, c)
    return c
end

function library:round(number, float)
    local m = 1 / (float or 1)
    return floor(number * m + 0.5) / m
end

function library:convert(str)
    local values = {}
    for value in string.gmatch(str, "[^,]+") do
        insert(values, tonumber(value))
    end
    if #values == 4 then return unpack(values) end
end

function library:convert_enum(enum)
    local parts = {}
    for p in string.gmatch(enum, "[%w_]+") do insert(parts, p) end
    local t = Enum
    for i = 2, #parts do t = t[parts[i]] end
    return t
end

function library:mouse_in_frame(obj)
    local pos = uis:GetMouseLocation()
    return obj.AbsolutePosition.X <= pos.X and pos.X <= obj.AbsolutePosition.X + obj.AbsoluteSize.X
       and obj.AbsolutePosition.Y <= pos.Y and pos.Y <= obj.AbsolutePosition.Y + obj.AbsoluteSize.Y
end

-- FIX : draggify supporte Touch
function library:draggify(frame)
    local dragging, start, startPos = false, nil, nil
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            start = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    library:connection(uis.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local vx, vy = camera.ViewportSize.X, camera.ViewportSize.Y
            frame.Position = dim2(
                0, clamp(startPos.X.Offset + (input.Position.X - start.X), 0, vx - frame.Size.X.Offset),
                0, clamp(startPos.Y.Offset + (input.Position.Y - start.Y), 0, vy - frame.Size.Y.Offset)
            )
        end
    end)
end

function library:unload_menu()
    if library.gui then library.gui:Destroy() end
    if library.sgui then library.sgui:Destroy() end
    for _, c in next, library.connections do c:Disconnect() end
    library = nil
end

-- Notifications
local notifications = { notifs = {} }

-- FIX : gethui avec fallback coregui
library.sgui = library:create("ScreenGui", {
    Name = "sgui",
    Parent = (gethui and gethui()) or coregui,
    IgnoreGuiInset = true,
})

function notifications:create_notification(options)
    local name = options.name or "notification"
    local outline = library:create("Frame", {
        Parent = library.sgui,
        Position = dim_offset(-200, 50 + (#notifications.notifs * 30)),
        BorderColor3 = rgb(0,0,0),
        Size = dim2(0, 0, 0, 24),
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = rgb(255,255,255),
    })
    local dark = library:create("Frame", {
        Parent = outline,
        BackgroundTransparency = 0.6,
        Position = dim2(0,2,0,2),
        BorderColor3 = rgb(0,0,0),
        Size = dim2(1,-4,1,-4),
        BorderSizePixel = 0,
        BackgroundColor3 = rgb(0,0,0),
    })
    library:create("UIPadding", { Parent = dark, PaddingTop = dim(0,7), PaddingBottom = dim(0,6), PaddingLeft = dim(0,4), PaddingRight = dim(0,7) })
    library:create("TextLabel", {
        FontFace = fonts["ProggyClean"], TextColor3 = rgb(255,255,255),
        BorderColor3 = rgb(0,0,0), Text = name, Parent = dark,
        Size = dim2(0,0,1,0), Position = dim2(0,1,0,-1),
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X, TextSize = 12,
        BackgroundColor3 = rgb(255,255,255),
    })
    library:create("UIGradient", {
        Color = rgbseq{rgbkey(0, themes.preset["1"]), rgbkey(0.5, themes.preset["2"]), rgbkey(1, themes.preset["3"])},
        Parent = outline,
    })
    local index = #notifications.notifs + 1
    notifications.notifs[index] = outline
    for i, v in notifications.notifs do
        tween_service:Create(v, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Position = dim_offset(50, 50 + (i * 30)) }):Play()
    end
    task.spawn(function()
        task.wait(3)
        notifications.notifs[index] = nil
        tween_service:Create(outline, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
        task.wait(0.6)
        outline:Destroy()
    end)
end

-- Watermark
function library:watermark(options)
    local cfg = { name = options.name or "nameless client" }
    local outline = library:create("Frame", {
        Parent = library.sgui,
        Position = dim2(0, 50, 0, 10),
        BorderColor3 = rgb(0,0,0),
        Size = dim2(0,0,0,24),
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = rgb(255,255,255),
    })
    library:draggify(outline)
    local dark = library:create("Frame", {
        Parent = outline, BackgroundTransparency = 0.6,
        Position = dim2(0,2,0,2), BorderColor3 = rgb(0,0,0),
        Size = dim2(1,-4,1,-4), BorderSizePixel = 0,
        BackgroundColor3 = rgb(0,0,0),
    })
    library:create("UIPadding", { Parent = dark, PaddingTop = dim(0,7), PaddingBottom = dim(0,6), PaddingLeft = dim(0,4), PaddingRight = dim(0,7) })
    local title = library:create("TextLabel", {
        FontFace = fonts["ProggyClean"], TextColor3 = rgb(255,255,255),
        BorderColor3 = rgb(0,0,0), Text = cfg.name, Parent = dark,
        Size = dim2(0,0,1,0), Position = dim2(0,1,0,-1),
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X, TextSize = 12,
        BackgroundColor3 = rgb(255,255,255),
    })
    library:create("UIGradient", {
        Color = rgbseq{rgbkey(0, themes.preset["1"]), rgbkey(0.5, themes.preset["2"]), rgbkey(1, themes.preset["3"])},
        Parent = outline,
    })
    function cfg.update_text(t) title.Text = t end
    return setmetatable(cfg, library)
end

local wm = library:watermark({ name = "nameless client" })
local fps_count, wm_tick = 0, tick()
run.RenderStepped:Connect(function()
    fps_count += 1
    if tick() - wm_tick > 1 then
        wm_tick = tick()
        local ping = math.floor(stats.PerformanceStats.Ping:GetValue())
        wm.update_text(string.format("nameless client | fps: %d | ping: %dms", fps_count, ping))
        fps_count = 0
    end
end)

-- Window
function library:window(properties)
    local cfg = {
        name = properties.name or "nameless",
        size = properties.size or dim2(0, 460, 0, 362),
        selected_tab,
    }
    library.gui = library:create("ScreenGui", {
        Parent = coregui, Name = "\0", Enabled = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
    })
    local win = library:create("Frame", {
        Parent = library.gui,
        Position = dim2(0.5, -230, 0.5, -181),
        BorderColor3 = rgb(0,0,0),
        Size = cfg.size,
        BorderSizePixel = 0,
        BackgroundColor3 = rgb(255,255,255),
    })
    -- FIX : position correcte (X et Y)
    win.Position = dim2(0, win.AbsolutePosition.X, 0, win.AbsolutePosition.Y)
    cfg.main_outline = win
    library:draggify(win)

    local title_bar = library:create("Frame", {
        Parent = win, BackgroundTransparency = 0.8,
        Position = dim2(0,2,0,2), BorderColor3 = rgb(0,0,0),
        Size = dim2(1,-4,0,20), BorderSizePixel = 0,
        BackgroundColor3 = rgb(0,0,0),
    })
    library:create("TextLabel", {
        FontFace = fonts["TahomaBold"], TextColor3 = rgb(255,255,255),
        BorderColor3 = rgb(0,0,0), Text = cfg.name, Parent = title_bar,
        BackgroundTransparency = 1, Size = dim2(1,0,1,0),
        BorderSizePixel = 0, TextSize = 12,
        BackgroundColor3 = rgb(255,255,255),
    })
    library.gradient = library:create("UIGradient", {
        Color = rgbseq{rgbkey(0, themes.preset["1"]), rgbkey(0.5, themes.preset["2"]), rgbkey(1, themes.preset["3"])},
        Parent = win,
    })
    -- tab_button_holder invisible (pas de tabs)
    local tbh = library:create("Frame", {
        AnchorPoint = vec2(0,1), Parent = win,
        BackgroundTransparency = 1,
        Position = dim2(0,2,1,-2), BorderColor3 = rgb(0,0,0),
        Size = dim2(1,-4,0,0), BorderSizePixel = 0,
        BackgroundColor3 = rgb(0,0,0),
    })
    cfg.tab_button_holder = tbh
    return setmetatable(cfg, library)
end

function library:tab(properties)
    local cfg = { name = properties.name or "main", count = 0 }
    -- bouton tab invisible
    local tab_button = library:create("TextButton", {
        FontFace = fonts["ProggyClean"], TextColor3 = rgb(170,170,170),
        BorderColor3 = rgb(0,0,0), Text = cfg.name,
        Parent = self.tab_button_holder,
        BackgroundTransparency = 1, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.XY, TextSize = 12,
        BackgroundColor3 = rgb(255,255,255), Visible = false,
    })
    local Page = library:create("Frame", {
        Parent = self.main_outline, BackgroundTransparency = 0.6,
        Position = dim2(0,2,0,24), BorderColor3 = rgb(0,0,0),
        -- FIX : taille pleine hauteur (pas de tab bar)
        Size = dim2(1,-4,1,-26),
        BorderSizePixel = 0, BackgroundColor3 = rgb(0,0,0),
        Visible = false,
    })
    cfg.page = Page
    library:create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,
        Parent = Page, Padding = dim(0,2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalFlex = Enum.UIFlexAlignment.Fill,
    })
    library:create("UIPadding", {
        PaddingTop = dim(0,2), PaddingBottom = dim(0,2),
        Parent = Page, PaddingRight = dim(0,2), PaddingLeft = dim(0,2),
    })
    function cfg.open_tab()
        if self.selected_tab then
            self.selected_tab[1].Visible = false
        end
        Page.Visible = true
        self.selected_tab = { Page, tab_button }
    end
    if not self.selected_tab then cfg.open_tab() end
    return setmetatable(cfg, library)
end

function library:column(properties)
    self.count += 1
    local cfg = { color = library.gradient.Color.Keypoints[self.count].Value, count = self.count }
    local sf = library:create("ScrollingFrame", {
        ScrollBarImageColor3 = rgb(0,0,0), Active = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0,
        Parent = self.page, LayoutOrder = -1, BackgroundTransparency = 1,
        ScrollBarImageTransparency = 1, BorderColor3 = rgb(0,0,0),
        BackgroundColor3 = rgb(0,0,0), BorderSizePixel = 0,
        CanvasSize = dim2(0,0,0,0),
    })
    cfg.column = sf
    library:create("UIListLayout", { Parent = sf, Padding = dim(0,5), SortOrder = Enum.SortOrder.LayoutOrder })
    return setmetatable(cfg, library)
end

function library:section(properties)
    local cfg = {
        name = properties.name or "section",
        size = properties.size or 1,
        autofill = properties.auto_fill or false,
        count = self.count,
        color = self.color,
    }
    -- FIX : accent au lieu de fill (variable inexistante)
    local accent = library:create("Frame", {
        Parent = self.column, ClipsDescendants = true,
        BorderColor3 = rgb(0,0,0), BorderSizePixel = 0,
        BackgroundColor3 = self.color,
    })
    library:apply_theme(accent, tostring(self.count), "BackgroundColor3")

    local dark = library:create("Frame", {
        Parent = accent, BackgroundTransparency = 0.6,
        Position = dim2(0,2,0,16), BorderColor3 = rgb(0,0,0),
        Size = dim2(1,-4,1,-18), BorderSizePixel = 0,
        BackgroundColor3 = rgb(0,0,0),
    })
    local elements = library:create("Frame", {
        Parent = dark, Position = dim2(0,4,0,5),
        BorderColor3 = rgb(0,0,0), Size = dim2(1,-8,0,0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        BackgroundColor3 = rgb(255,255,255),
    })
    cfg.elements = elements
    if not cfg.autofill then
        elements.AutomaticSize = Enum.AutomaticSize.Y
        accent.AutomaticSize = Enum.AutomaticSize.Y
        accent.Size = dim2(1,0,0,0)
        library:create("UIPadding", { Parent = elements, PaddingBottom = dim(0,7) })
    else
        accent.Size = dim2(1,0,cfg.size,0)
    end
    library:create("UIListLayout", { Parent = elements, Padding = dim(0,6), SortOrder = Enum.SortOrder.LayoutOrder })
    library:create("TextLabel", {
        FontFace = fonts["TahomaBold"], TextColor3 = rgb(255,255,255),
        BorderColor3 = rgb(0,0,0), Text = cfg.name, Parent = accent,
        Size = dim2(1,0,0,0), Position = dim2(0,4,0,2),
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y,
        TextSize = 12, BackgroundColor3 = rgb(255,255,255),
    })
    -- FIX : suppression UIListLayout Parent=ScrollingFrame (variable inconnue)
    return setmetatable(cfg, library)
end

function library:toggle(options)
    local cfg = {
        enabled = false,
        name = options.name or "toggle",
        flag = options.flag or tostring(random(1,9999999)),
        default = options.default or false,
        callback = options.callback or function() end,
        color = self.color, count = self.count,
    }
    local toggle = library:create("TextButton", {
        Parent = self.elements, BackgroundTransparency = 1, Text = "",
        BorderColor3 = rgb(0,0,0), Size = dim2(1,0,0,12),
        BorderSizePixel = 0, BackgroundColor3 = rgb(255,255,255),
    })
    library:create("TextLabel", {
        FontFace = fonts["ProggyClean"], TextColor3 = rgb(255,255,255),
        BorderColor3 = rgb(0,0,0), Text = cfg.name, Parent = toggle,
        Size = dim2(1,0,1,0), Position = dim2(0,1,0,-1),
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X,
        TextSize = 12, BackgroundColor3 = rgb(255,255,255),
    })
    local accent = library:create("Frame", {
        AnchorPoint = vec2(1,0), Parent = toggle,
        Position = dim2(1,0,0,0), BorderColor3 = rgb(0,0,0),
        Size = dim2(0,12,0,12), BorderSizePixel = 0,
        BackgroundColor3 = self.color,
    })
    library:apply_theme(accent, tostring(self.count), "BackgroundColor3")
    local fill = library:create("Frame", {
        Parent = accent, Position = dim2(0,1,0,1),
        BorderColor3 = rgb(0,0,0), Size = dim2(1,-2,1,-2),
        BorderSizePixel = 0, BackgroundColor3 = self.color,
    })
    library:apply_theme(fill, tostring(self.count), "BackgroundColor3")
    -- FIX : suppression UIListLayout Parent=right_components (variable inconnue)
    function cfg.set(bool)
        fill.BackgroundColor3 = bool and themes.preset[tostring(self.count)] or themes.preset.inline
        flags[cfg.flag] = bool
        cfg.enabled = bool
        cfg.callback(bool)
    end
    cfg.set(cfg.default)
    config_flags[cfg.flag] = cfg.set
    toggle.MouseButton1Click:Connect(function()
        cfg.set(not cfg.enabled)
    end)
    return setmetatable(cfg, library)
end

function library:slider(options)
    local cfg = {
        name = options.name or "slider",
        suffix = options.suffix or "",
        flag = options.flag or tostring(random(1,9999999)),
        callback = options.callback or function() end,
        min = options.min or 0,
        max = options.max or 100,
        intervals = options.interval or options.decimal or 1,
        default = options.default or 10,
        value = options.default or 10,
        dragging = false,
    }
    local slider = library:create("Frame", {
        Parent = self.elements, BackgroundTransparency = 1,
        BorderColor3 = rgb(0,0,0), Size = dim2(1,0,0,25),
        BorderSizePixel = 0, BackgroundColor3 = rgb(255,255,255),
    })
    local label = library:create("TextLabel", {
        FontFace = fonts["ProggyClean"], TextColor3 = rgb(255,255,255),
        RichText = true, BorderColor3 = rgb(0,0,0), Text = cfg.name,
        Parent = slider, Size = dim2(1,0,0,0), Position = dim2(0,1,0,-2),
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.XY, TextSize = 12,
        BackgroundColor3 = rgb(255,255,255),
    })
    local outline = library:create("TextButton", {
        Parent = slider, Text = "", AutoButtonColor = false,
        Position = dim2(0,0,0,13), BorderColor3 = rgb(0,0,0),
        Size = dim2(1,0,0,12), BorderSizePixel = 0,
        BackgroundColor3 = self.color,
    })
    library:apply_theme(outline, tostring(self.count), "BackgroundColor3")
    local inl = library:create("Frame", {
        Parent = outline, Position = dim2(0,1,0,1),
        BorderColor3 = rgb(0,0,0), Size = dim2(1,-2,1,-2),
        BorderSizePixel = 0, BackgroundColor3 = themes.preset.inline,
    })
    local bar = library:create("Frame", {
        Parent = inl, BorderColor3 = rgb(0,0,0),
        Size = dim2(0.5,0,1,0), BorderSizePixel = 0,
        BackgroundColor3 = self.color,
    })
    library:apply_theme(bar, tostring(self.count), "BackgroundColor3")
    function cfg.set(value)
        local v = tonumber(value)
        if not v then return end
        cfg.value = clamp(library:round(v, cfg.intervals), cfg.min, cfg.max)
        bar.Size = dim2((cfg.value - cfg.min) / (cfg.max - cfg.min), 0, 1, 0)
        label.Text = cfg.name .. "<font color='#AAAAAA'> - " .. tostring(cfg.value) .. cfg.suffix .. "</font>"
        flags[cfg.flag] = cfg.value
        cfg.callback(cfg.value)
    end
    cfg.set(cfg.default)
    config_flags[cfg.flag] = cfg.set
    outline.MouseButton1Down:Connect(function() cfg.dragging = true end)
    -- FIX : support Touch mobile
    outline.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then cfg.dragging = true end
    end)
    library:connection(uis.InputChanged, function(input)
        if cfg.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local sx = (input.Position.X - inl.AbsolutePosition.X) / inl.AbsoluteSize.X
            cfg.set(((cfg.max - cfg.min) * sx) + cfg.min)
        end
    end)
    library:connection(uis.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            cfg.dragging = false
        end
    end)
    return setmetatable(cfg, library)
end

function library:dropdown(options)
    local cfg = {
        name = options.name or "dropdown",
        flag = options.flag or tostring(random(1,9999999)),
        items = options.items or {""},
        callback = options.callback or function() end,
        multi = options.multi or false,
        open = false,
        option_instances = {},
        multi_items = {},
    }
    cfg.default = options.default or cfg.items[1] or "None"
    flags[cfg.flag] = {}
    local dd = library:create("Frame", {
        Parent = self.elements, BackgroundTransparency = 1,
        BorderColor3 = rgb(0,0,0), Size = dim2(1,0,0,16),
        BorderSizePixel = 0, BackgroundColor3 = rgb(255,255,255),
    })
    local holder = library:create("TextButton", {
        AnchorPoint = vec2(1,0), AutoButtonColor = false, Text = "",
        Parent = dd, Position = dim2(1,0,0,0),
        BorderColor3 = rgb(0,0,0), Size = dim2(0.5,0,0,16),
        BorderSizePixel = 0, BackgroundColor3 = self.color,
    })
    library:apply_theme(holder, tostring(self.count), "BackgroundColor3")
    local hinl = library:create("Frame", {
        Parent = holder, Position = dim2(0,1,0,1),
        BorderColor3 = rgb(0,0,0), Size = dim2(1,-2,1,-2),
        BorderSizePixel = 0, BackgroundColor3 = rgb(35,35,35),
    })
    local text = library:create("TextLabel", {
        FontFace = fonts["ProggyClean"], TextColor3 = rgb(255,255,255),
        BorderColor3 = rgb(0,0,0), Text = cfg.default, Parent = hinl,
        Size = dim2(1,0,1,0), BackgroundTransparency = 1,
        Position = dim2(0,0,0,1), BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X, TextSize = 12,
        BackgroundColor3 = rgb(255,255,255),
    })
    library:create("TextLabel", {
        FontFace = fonts["ProggyClean"], TextColor3 = rgb(255,255,255),
        BorderColor3 = rgb(0,0,0), Text = cfg.name, Parent = dd,
        Size = dim2(0.5,0,1,0), Position = dim2(0,1,0,0),
        BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.X, TextSize = 12,
        BackgroundColor3 = rgb(255,255,255),
    })
    local popup = library:create("Frame", {
        Parent = library.gui, Size = dim2(0,100,0,20),
        Position = dim2(0,500,0,100), BorderColor3 = rgb(0,0,0),
        BorderSizePixel = 0, Visible = false,
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = self.color,
    })
    library:apply_theme(popup, tostring(self.count), "BackgroundColor3")
    local pinl = library:create("Frame", {
        Parent = popup, Size = dim2(1,-2,1,-2), Position = dim2(0,1,0,1),
        BorderColor3 = rgb(0,0,0), BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = themes.preset.inline,
    })
    library:apply_theme(pinl, "inline", "BackgroundColor3")
    library:create("UIListLayout", { Parent = pinl, Padding = dim(0,6), SortOrder = Enum.SortOrder.LayoutOrder })
    library:create("UIPadding", { Parent = pinl, PaddingTop = dim(0,5), PaddingBottom = dim(0,2), PaddingRight = dim(0,6), PaddingLeft = dim(0,6) })
    library:create("UIPadding", { Parent = popup, PaddingBottom = dim(0,2) })

    function cfg.set_visible(bool) popup.Visible = bool end
    function cfg.set(value)
        if value == nil then return end
        local selected = {}
        local isT = type(value) == "table"
        for _, opt in next, cfg.option_instances do
            if opt.Text == value or (isT and find(value, opt.Text)) then
                insert(selected, opt.Text)
                opt.TextColor3 = rgb(255,255,255)
            else
                opt.TextColor3 = rgb(170,170,170)
            end
        end
        text.Text = isT and concat(selected,", ") or (selected[1] or "")
        flags[cfg.flag] = isT and selected or selected[1]
        cfg.callback(flags[cfg.flag])
    end
    function cfg.refresh_options(list)
        for _, o in next, cfg.option_instances do o:Destroy() end
        cfg.option_instances = {}
        for _, opt in next, list do
            local btn = library:create("TextButton", {
                FontFace = fonts["ProggyClean"], AutoButtonColor = false,
                TextColor3 = rgb(170,170,170), BorderColor3 = rgb(0,0,0),
                Text = opt, Parent = pinl, Size = dim2(1,0,0,0),
                BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
                BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y,
                TextSize = 12, BackgroundColor3 = rgb(255,255,255),
            })
            insert(cfg.option_instances, btn)
            btn.MouseButton1Down:Connect(function()
                if cfg.multi then
                    local i = find(cfg.multi_items, btn.Text)
                    if i then remove(cfg.multi_items, i) else insert(cfg.multi_items, btn.Text) end
                    cfg.set(cfg.multi_items)
                else
                    cfg.set_visible(false)
                    cfg.open = false
                    cfg.set(btn.Text)
                end
            end)
        end
    end
    cfg.refresh_options(cfg.items)
    cfg.set(cfg.default)
    config_flags[cfg.flag] = cfg.set
    holder.MouseButton1Click:Connect(function()
        cfg.open = not cfg.open
        popup.Size = dim2(0, holder.AbsoluteSize.X, 0, popup.Size.Y.Offset)
        popup.Position = dim2(0, holder.AbsolutePosition.X, 0, holder.AbsolutePosition.Y + holder.AbsoluteSize.Y + 2)
        cfg.set_visible(cfg.open)
    end)
    uis.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if not (library:mouse_in_frame(popup) or library:mouse_in_frame(dd)) then
                cfg.open = false
                cfg.set_visible(false)
            end
        end
    end)
    return setmetatable(cfg, library)
end

function library:button(options)
    local cfg = {
        name = options.name or "button",
        callback = options.callback or function() end,
    }
    local frame = library:create("TextButton", {
        AnchorPoint = vec2(1,0), Text = "", AutoButtonColor = false,
        Parent = self.elements, Position = dim2(1,0,0,0),
        BorderColor3 = rgb(0,0,0), Size = dim2(1,0,0,16),
        BorderSizePixel = 0, BackgroundColor3 = self.color,
    })
    library:apply_theme(frame, tostring(self.count), "BackgroundColor3")
    local finl = library:create("Frame", {
        Parent = frame, Position = dim2(0,1,0,1),
        BorderColor3 = rgb(0,0,0), Size = dim2(1,-2,1,-2),
        BorderSizePixel = 0, BackgroundColor3 = themes.preset.inline,
    })
    library:apply_theme(finl, "inline", "BackgroundColor3")
    library:create("TextLabel", {
        FontFace = fonts["ProggyClean"], TextColor3 = rgb(255,255,255),
        BorderColor3 = rgb(0,0,0), Text = cfg.name, Parent = frame,
        Size = dim2(1,0,1,0), BackgroundTransparency = 1,
        Position = dim2(0,1,0,1), BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X, TextSize = 12,
        BackgroundColor3 = rgb(255,255,255),
    })
    frame.MouseButton1Click:Connect(function() cfg.callback() end)
    return setmetatable(cfg, library)
end

-- ============================================================
-- NAMELESS CLIENT
-- ============================================================
local window = library:window({ name = "Nameless Client" })
notifications:create_notification({ name = "loading nameless client..." })

local main = window:tab({ name = "main" })
local col1 = main:column({})
local col2 = main:column({})

local combat = col1:section({ name = "combat", auto_fill = false })
local player = col2:section({ name = "player", auto_fill = false })

combat:toggle({ name = "silent aim",  flag = "silent_aim",  callback = function(v) end })
combat:toggle({ name = "auto parry",  flag = "auto_parry",  callback = function(v) end })
combat:slider({ name = "fov", flag = "aim_fov", min = 10, max = 500, default = 150, interval = 1, suffix = "", callback = function(v) end })
combat:dropdown({ name = "target part", flag = "aim_part", items = {"Head","HumanoidRootPart","Torso"}, default = "HumanoidRootPart", callback = function(v) end })

player:slider({ name = "walkspeed", flag = "ws", min = 16, max = 500, default = 16, interval = 1, suffix = "",
    callback = function(v)
        local c = lp.Character
        if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = v end
    end
})
player:slider({ name = "jumppower", flag = "jp", min = 7, max = 300, default = 7, interval = 1, suffix = "",
    callback = function(v)
        local c = lp.Character
        if c and c:FindFirstChild("Humanoid") then c.Humanoid.JumpPower = v end
    end
})
player:toggle({ name = "infinite jump", flag = "inf_jump", callback = function(v) end })
player:toggle({ name = "fly",           flag = "fly",      callback = function(v) end })
player:toggle({ name = "anti afk",      flag = "anti_afk", callback = function(v) end })

-- ============================================================
-- BOUTON CARRÉ HIDE/SHOW — draggable PC + Mobile
-- ============================================================
local BtnGui = Instance.new("ScreenGui")
BtnGui.Name = "NamelessToggle"
BtnGui.ResetOnSpawn = false
BtnGui.IgnoreGuiInset = true
BtnGui.DisplayOrder = 999
BtnGui.Parent = coregui

local Btn = Instance.new("ImageButton")
Btn.Image = "rbxassetid://12868878587"
Btn.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Btn.BackgroundTransparency = 0.2
Btn.BorderSizePixel = 0
Btn.Active = true
Btn.Size = UDim2.new(0, 38, 0, 38)
Btn.Position = UDim2.new(0, 8, 0, 8)

if uis.TouchEnabled and not uis.KeyboardEnabled then
    Btn.Size = UDim2.new(0, 54, 0, 54)
    Btn.Position = UDim2.new(0, 16, 1, -76)
end

Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
local Stroke = Instance.new("UIStroke", Btn)
Stroke.Color = Color3.fromRGB(90, 90, 130)
Stroke.Thickness = 1
Stroke.Transparency = 0.5
Btn.Parent = BtnGui

local dragging, dragStart, btnStart = false, nil, nil
Btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        btnStart = Btn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
Btn.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        Btn.Position = UDim2.new(btnStart.X.Scale, btnStart.X.Offset + d.X, btnStart.Y.Scale, btnStart.Y.Offset + d.Y)
    end
end)

local menuVisible = true
Btn.MouseButton1Click:Connect(function()
    menuVisible = not menuVisible
    library.gui.Enabled = menuVisible
    tween_service:Create(Btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Rotation = menuVisible and 0 or 45
    }):Play()
end)

notifications:create_notification({ name = "nameless client loaded!" })

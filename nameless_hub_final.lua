-- =====================================================================
-- GOTCHA.EXE | Obsidian UI + Silent Aim Full
-- By HimselfZen
-- =====================================================================

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library     = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

-- =====================================================================
-- SERVICES
-- =====================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local RS               = game:GetService("ReplicatedStorage")
local player           = Players.LocalPlayer
local camera           = workspace.CurrentCamera
local MouseModule      = RS:FindFirstChild("Mouse")

-- =====================================================================
-- VARIABLES SILENT AIM
-- =====================================================================
local SilentAimPlayersEnabled = false
local SilentAimNPCsEnabled    = false
local UserWantsPlayerAim      = false
local UserWantsNPCAim         = false
local PredictionEnabled       = false
local PredictionAmount        = 0.1
local HighlightEnabled        = false
local ZSkillorM1              = false
local AutoKen                 = false
local autoKenRunning          = false
local maxRange                = 1000

local PlayersPosition   = nil
local NPCPosition       = nil
local renderConnection  = nil
local currentTool       = nil
local Selectedplayer    = nil
local currentHighlight  = nil
local currentTargetType = nil
local MiniPlayerState   = nil
local MiniNpcState      = nil
local MiniPlayerCreated = false
local MiniNpcCreated    = false
local MiniPlayerGui, MiniNpcGui = nil, nil
local characterConnections = {}

-- ZSkill Godhuman
local ZSkillsEnabled  = false
local godhumanZActive = false
local aimlockActive   = false
local aimRenderConn   = nil
local aimTimeoutTask  = nil
local nearestZTarget  = nil

-- TAP whitelisté = Portal jamais redirigé
local Booms  = {}

-- =====================================================================
-- TEAM / ALLY CHECK
-- =====================================================================
local function isAllyWithMe(targetPlayer)
    local myGui = player:FindFirstChild("PlayerGui")
    if not myGui then return false end
    local scrolling = myGui:FindFirstChild("Main")
        and myGui.Main:FindFirstChild("Allies")
        and myGui.Main.Allies:FindFirstChild("Container")
        and myGui.Main.Allies.Container:FindFirstChild("Allies")
        and myGui.Main.Allies.Container.Allies:FindFirstChild("ScrollingFrame")
    if scrolling then
        for _, frame in pairs(scrolling:GetDescendants()) do
            if frame:IsA("ImageButton") and frame.Name == targetPlayer.Name then return true end
        end
    end
    return false
end

local function isEnemy(targetPlayer)
    if not targetPlayer or targetPlayer == player then return false end
    local myTeam = player.Team
    local targetTeam = targetPlayer.Team
    if myTeam and targetTeam then
        if myTeam.Name == "Pirates" and targetTeam.Name == "Marines" then return true end
        if myTeam.Name == "Marines" and targetTeam.Name == "Pirates" then return true end
        if myTeam.Name == "Pirates" and targetTeam.Name == "Pirates" then
            return not isAllyWithMe(targetPlayer)
        end
        if myTeam.Name == "Marines" and targetTeam.Name == "Marines" then return false end
    end
    return true
end

-- =====================================================================
-- CLOSEST TARGETS
-- =====================================================================
local function getHRP(model)
    if not model or not model:FindFirstChild("HumanoidRootPart") then return nil end
    return model.HumanoidRootPart
end

local function getClosestPlayer(lpHRP)
    if not lpHRP then return nil end
    if Selectedplayer and Selectedplayer.Character then
        local hrp = getHRP(Selectedplayer.Character)
        if hrp then return Selectedplayer end
    end
    local closest, closestDist = nil, maxRange
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= player and isEnemy(pl) and pl.Character then
            local hum = pl.Character:FindFirstChildWhichIsA("Humanoid")
            local hrp = getHRP(pl.Character)
            if hum and hum.Health > 0 and hrp then
                local dist = (hrp.Position - lpHRP.Position).Magnitude
                if dist < closestDist then closestDist = dist closest = pl end
            end
        end
    end
    return closest
end

local function getClosestNPC(lpHRP)
    if not lpHRP then return nil end
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end
    local closest, closestDist = nil, maxRange
    for _, npc in ipairs(enemiesFolder:GetChildren()) do
        if npc:IsA("Model") then
            local hum = npc:FindFirstChildWhichIsA("Humanoid")
            local hrp = getHRP(npc)
            if hum and hum.Health > 0 and hrp then
                local dist = (hrp.Position - lpHRP.Position).Magnitude
                if dist < closestDist then closestDist = dist closest = npc end
            end
        end
    end
    return closest
end

-- =====================================================================
-- PREDICTION
-- =====================================================================
local function getPredictedPosition(hrp)
    if not hrp then return nil end
    if not PredictionEnabled then return hrp.Position end
    local hum = hrp.Parent:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed >= 5 then return hrp.Position + (hrp.Velocity * PredictionAmount) end
    return hrp.Position
end

-- =====================================================================
-- HIGHLIGHT
-- =====================================================================
local function clearHighlight()
    if currentHighlight then currentHighlight:Destroy() currentHighlight = nil currentTargetType = nil end
end

local function applyHighlight(targetModel, targetType)
    if not HighlightEnabled or not targetModel then return end
    if currentHighlight and currentHighlight.Adornee == targetModel then return end
    clearHighlight()
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255,255,0) hl.OutlineColor = Color3.fromRGB(255,255,0)
    hl.FillTransparency = 0.5 hl.OutlineTransparency = 0
    hl.Adornee = targetModel hl.Parent = targetModel
    currentHighlight = hl currentTargetType = targetType
end

-- =====================================================================
-- MINI TOGGLES
-- =====================================================================
local function createMiniToggle(name, position, stateVarRef, realVarSetter)
    local playerGui = player:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild(name.."MiniToggleGuiS") then playerGui[name.."MiniToggleGuiS"]:Destroy() end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = name.."MiniToggleGuiS" screenGui.ResetOnSpawn = false screenGui.Parent = playerGui
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0,70,0,40) button.Position = position
    button.Text = name..(stateVarRef.value and " ON" or " OFF")
    button.TextScaled = true button.TextColor3 = Color3.fromRGB(255,255,255)
    button.BackgroundColor3 = Color3.fromRGB(30,30,30) button.BorderSizePixel = 0 button.Parent = screenGui
    Instance.new("UICorner",button).CornerRadius = UDim.new(0,8)
    local gradient = Instance.new("UIGradient") gradient.Rotation = 45 gradient.Parent = button
    local function updateUI(state)
        button.Text = name..(state and " ON" or " OFF")
        gradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, state and Color3.fromRGB(50,200,50) or Color3.fromRGB(255,100,50)),
            ColorSequenceKeypoint.new(1, state and Color3.fromRGB(50,255,50) or Color3.fromRGB(255,200,50)),
        }
    end
    button.MouseButton1Click:Connect(function() stateVarRef.value = not stateVarRef.value realVarSetter(stateVarRef.value) updateUI(stateVarRef.value) end)
    local dragging, dragStart, startPos = false, nil, nil
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true dragStart = input.Position startPos = button.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    button.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(0, math.clamp(startPos.X.Offset+delta.X,0,camera.ViewportSize.X-button.AbsoluteSize.X), 0, math.clamp(startPos.Y.Offset+delta.Y,0,camera.ViewportSize.Y-button.AbsoluteSize.Y))
        end
    end)
    updateUI(stateVarRef.value)
    return screenGui
end

-- =====================================================================
-- SKILL COOLDOWN CHECK
-- =====================================================================
local function isSkillReadyForTool(toolName)
    if not toolName then return false end
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    local skillsFolder = playerGui:FindFirstChild("Main") and playerGui.Main:FindFirstChild("Skills")
    if not skillsFolder then return false end
    local toolFrame = skillsFolder:FindFirstChild(toolName)
    if not toolFrame then return false end
    for _, skillKey in ipairs({"Z","X","C","V"}) do
        local skill = toolFrame:FindFirstChild(skillKey)
        if skill and skill:FindFirstChild("Cooldown") and skill.Cooldown:IsA("Frame") then
            if skill.Cooldown.Size.X.Scale == 1.0 then return true end
        end
    end
    return false
end

local function isNotValidCondition()
    return (currentTool and currentTool.Name == "Lightning-Lightning")
        or (currentTool and currentTool.Name == "Portal-Portal")
end

-- =====================================================================
-- RENDER LOOP
-- =====================================================================
local function startRenderLoop()
    if renderConnection then return end
    renderConnection = RunService.RenderStepped:Connect(function()
        local lpChar = player.Character
        if not lpChar then return end
        local lpHRP = lpChar:FindFirstChild("HumanoidRootPart")
        if not lpHRP then return end
        if not SilentAimPlayersEnabled and not SilentAimNPCsEnabled then return end

        local targetModel, lookTargetPos = nil, nil

        if SilentAimPlayersEnabled then
            local targetPlayer = getClosestPlayer(lpHRP)
            if targetPlayer and targetPlayer.Character then
                local hrp = getHRP(targetPlayer.Character)
                PlayersPosition = getPredictedPosition(hrp)
                lookTargetPos = PlayersPosition
                targetModel = targetPlayer.Character
                applyHighlight(targetModel, "player")
            else PlayersPosition = nil end
        elseif currentTargetType == "player" then PlayersPosition = nil clearHighlight() end

        if SilentAimNPCsEnabled then
            local npc = getClosestNPC(lpHRP)
            if npc then
                local hrp = getHRP(npc)
                NPCPosition = getPredictedPosition(hrp)
                lookTargetPos = NPCPosition
                if not targetModel then targetModel = npc applyHighlight(targetModel, "NPC") end
            else NPCPosition = nil end
        elseif currentTargetType == "NPC" then NPCPosition = nil clearHighlight() end

        if currentTool and lookTargetPos and isSkillReadyForTool(currentTool.Name) then
            local lookVector = (Vector3.new(lookTargetPos.X, lpHRP.Position.Y, lookTargetPos.Z) - lpHRP.Position).Unit
            lpHRP.CFrame = CFrame.new(lpHRP.Position, lpHRP.Position + lookVector)
        end

        if not isNotValidCondition() and MouseModule and typeof(MouseModule) == "Instance" then
            local ok, MouseData = pcall(require, MouseModule)
            if ok and type(MouseData) == "table" then
                local targetPos = PlayersPosition or NPCPosition
                if targetPos then pcall(function() MouseData.Hit = CFrame.new(targetPos) MouseData.Target = nil end) end
            end
        end
    end)
end

local function stopRenderLoop()
    if renderConnection then renderConnection:Disconnect() renderConnection = nil end
    PlayersPosition = nil NPCPosition = nil
end

-- =====================================================================
-- ZSKILL GODHUMAN AIMLOCK
-- =====================================================================
local function stopAimlock()
    if not aimlockActive then return end
    aimlockActive = false nearestZTarget = nil godhumanZActive = false
    if aimRenderConn  then pcall(function() aimRenderConn:Disconnect() end)  aimRenderConn  = nil end
    if aimTimeoutTask then pcall(function() task.cancel(aimTimeoutTask) end) aimTimeoutTask = nil end
end

local function startAimlock()
    if not ZSkillsEnabled or aimlockActive then return end
    local char = player.Character
    local lpHRP = char and char:FindFirstChild("HumanoidRootPart")
    local target = getClosestPlayer(lpHRP)
    if not target then return end
    nearestZTarget = target.Character aimlockActive = true

    aimRenderConn = RunService.RenderStepped:Connect(function()
        if not ZSkillsEnabled then stopAimlock() return end
        if aimlockActive and nearestZTarget and nearestZTarget:FindFirstChild("HumanoidRootPart") then
            local cam = workspace.CurrentCamera
            if cam then cam.CFrame = CFrame.lookAt(cam.CFrame.Position, nearestZTarget.HumanoidRootPart.Position) end
        else stopAimlock() end
    end)
    aimTimeoutTask = task.delay(1, function() if aimlockActive then stopAimlock() end end)
end

UserInputService.TouchEnded:Connect(function(touch)
    if not ZSkillsEnabled then return end
    local cam = workspace.CurrentCamera
    if not cam or not touch or not touch.Position then return end
    if touch.Position.X > cam.ViewportSize.X / 2 then
        if currentTool and currentTool.Name == "Godhuman" and godhumanZActive then
            if not aimlockActive then startAimlock() end
        end
    end
end)

-- =====================================================================
-- AUTO KEN
-- =====================================================================
local commE = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("CommE")
local function HasTag(tagName)
    local char = player.Character
    if not char then return false end
    return game:GetService("CollectionService"):HasTag(char, tagName)
end
local function startAutoKenLoop()
    if autoKenRunning then return end autoKenRunning = true
    task.spawn(function()
        while AutoKen do
            task.wait(0.1)
            if HasTag("Ken") then
                local playerGui = player:FindFirstChild("PlayerGui")
                if playerGui then
                    local kenButton = playerGui:FindFirstChild("MobileContextButtons")
                        and playerGui.MobileContextButtons.ContextButtonFrame
                        and playerGui.MobileContextButtons.ContextButtonFrame:FindFirstChild("BoundActionKen")
                    if kenButton and kenButton:GetAttribute("Selected") ~= true then kenButton:SetAttribute("Selected", true) end
                end
                local om = getrenv()._G.OM
                if om and not om.active then om.radius = 0 om:setActive(true) if commE then commE:FireServer("Ken", true) end end
            end
        end
        autoKenRunning = false
    end)
end

-- =====================================================================
-- ESP MODULE — Box, Lines, Name, Distance, Health Bar
-- Players + NPCs
-- =====================================================================
local ESPEnabled      = false
local ESPBox          = true
local ESPCornerBox    = false
local ESPFilledBox    = false
local ESPLines        = true
local ESPName         = true
local ESPDistance     = true
local ESPHealthBar    = true
local ESPHealthNum    = false
local ESPWeapon       = false
local ESPTeam         = false
local ESPBounty       = false
local ESPSkeleton     = false
local ESPHeadDot      = false
local ESPOffScreen    = false
local ESPChams        = false
local ESPNPCEnabled   = false

local espObjects      = {}
local espConnection   = nil
local chamsObjects    = {}  -- { [char] = {parts with original colors} }

local function worldToViewport(pos)
    local cam = workspace.CurrentCamera
    if not cam then return nil, false end
    local screenPos, onScreen = cam:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function getCharBounds(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local cam = workspace.CurrentCamera
    -- Projeter tête et pieds
    local head = char:FindFirstChild("Head")
    local topPos = head and head.Position + Vector3.new(0, head.Size.Y/2 + 0.2, 0) or hrp.Position + Vector3.new(0, 3, 0)
    local botPos = hrp.Position - Vector3.new(0, 3, 0)

    local topScreen, topOn, topZ = worldToViewport(topPos)
    local botScreen, botOn       = worldToViewport(botPos)

    if not topOn and not botOn then return nil end

    local h = math.abs(topScreen.Y - botScreen.Y)
    local w = h * 0.6
    local cx = topScreen.X

    return {
        top    = topScreen,
        bot    = botScreen,
        cx     = cx,
        w      = w,
        h      = h,
        depth  = topZ,
        onScreen = topOn or botOn,
    }
end

local function createDrawings(key)
    local d = {}
    -- Box classique
    d.boxTop    = Drawing.new("Line")
    d.boxBot    = Drawing.new("Line")
    d.boxLeft   = Drawing.new("Line")
    d.boxRight  = Drawing.new("Line")
    -- Corner box (8 lignes = 4 coins)
    d.cTL1 = Drawing.new("Line") d.cTL2 = Drawing.new("Line")
    d.cTR1 = Drawing.new("Line") d.cTR2 = Drawing.new("Line")
    d.cBL1 = Drawing.new("Line") d.cBL2 = Drawing.new("Line")
    d.cBR1 = Drawing.new("Line") d.cBR2 = Drawing.new("Line")
    -- Filled box
    d.filled    = Drawing.new("Square")
    -- Line depuis haut milieu écran
    d.line      = Drawing.new("Line")
    -- Name
    d.name      = Drawing.new("Text")
    -- Distance
    d.dist      = Drawing.new("Text")
    -- Health bar (bg + fill)
    d.hpBg      = Drawing.new("Line")
    d.hpFill    = Drawing.new("Line")
    -- Health number
    d.hpNum     = Drawing.new("Text")
    -- Weapon
    d.weapon    = Drawing.new("Text")
    -- Team
    d.team      = Drawing.new("Text")
    -- Bounty
    d.bounty    = Drawing.new("Text")
    -- Head dot
    d.headDot   = Drawing.new("Circle")
    -- Skeleton (12 lignes)
    d.sk = {}
    for i = 1, 12 do d.sk[i] = Drawing.new("Line") end
    -- Off-screen arrow
    d.arrow     = Drawing.new("Triangle")

    for _, obj in pairs(d) do
        if type(obj) ~= "table" then obj.Visible = false end
    end
    for _, obj in ipairs(d.sk) do obj.Visible = false end

    -- Épaisseurs
    for _, b in ipairs({d.boxTop,d.boxBot,d.boxLeft,d.boxRight,
        d.cTL1,d.cTL2,d.cTR1,d.cTR2,d.cBL1,d.cBL2,d.cBR1,d.cBR2}) do
        b.Thickness = 1
    end
    d.line.Thickness = 1
    d.hpBg.Thickness = 4 d.hpFill.Thickness = 4
    for _, s in ipairs(d.sk) do s.Thickness = 1 s.Transparency = 0.3 end

    -- Text styles
    for _, t in ipairs({d.name, d.dist, d.hpNum, d.weapon, d.team, d.bounty}) do
        t.Size = 12 t.Center = true t.Outline = true t.Font = 2
    end
    d.name.Size  = 13
    d.dist.Color = Color3.fromRGB(200,200,200)
    d.hpNum.Color = Color3.fromRGB(255,255,255)
    d.weapon.Color = Color3.fromRGB(255,220,100)
    d.team.Color   = Color3.fromRGB(100,200,255)
    d.bounty.Color = Color3.fromRGB(255,180,50)

    -- Head dot
    d.headDot.Radius = 4 d.headDot.Thickness = 1 d.headDot.Filled = true

    -- Filled box
    d.filled.Transparency = 0.7

    -- Arrow
    d.arrow.Thickness = 1 d.arrow.Filled = true

    espObjects[key] = d
    return d
end

local function hideDrawings(d)
    if not d then return end
    for _, obj in pairs(d) do obj.Visible = false end
end

local function removeDrawings(key)
    local d = espObjects[key]
    if d then
        for _, obj in pairs(d) do pcall(function() obj:Remove() end) end
        espObjects[key] = nil
    end
end

-- ========== CHAMS ==========
local function applyChams(char, col)
    if not char then return end
    local key = tostring(char)
    if chamsObjects[key] then return end
    chamsObjects[key] = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local orig = part.Color
            part.Color = col
            table.insert(chamsObjects[key], {part=part, orig=orig})
        end
    end
end

local function removeChams(char)
    if not char then return end
    local key = tostring(char)
    if not chamsObjects[key] then return end
    for _, data in ipairs(chamsObjects[key]) do
        pcall(function() data.part.Color = data.orig end)
    end
    chamsObjects[key] = nil
end

-- ========== SKELETON ==========
local skBones = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},
}

local function updateESP(target, key, isNPC)
    local char = isNPC and target or (target.Character)
    if not char then hideDrawings(espObjects[key]) return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then hideDrawings(espObjects[key]) return end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local bounds = getCharBounds(char)
    local d = espObjects[key] or createDrawings(key)

    -- Couleur
    local col = Color3.fromRGB(255, 50, 50)
    if not isNPC then
        local pl = Players:FindFirstChild(char.Name)
        if pl and not isEnemy(pl) then col = Color3.fromRGB(50, 255, 50) end
    else
        col = Color3.fromRGB(255, 165, 0)
    end

    -- Distance
    local myChar = player.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local dist   = myHRP and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0

    -- ===== OFF-SCREEN ARROW =====
    local screenPos2, onScreen2 = worldToViewport(hrp.Position)
    if not onScreen2 and ESPOffScreen then
        local screenCenter = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local dir = (screenPos2 - screenCenter).Unit
        local angle = math.atan2(dir.Y, dir.X)
        local arrowDist = 80
        local arrowPos = screenCenter + dir * arrowDist
        local sz = 10
        local p1 = arrowPos + Vector2.new(math.cos(angle)*sz, math.sin(angle)*sz)
        local p2 = arrowPos + Vector2.new(math.cos(angle+2.4)*sz*0.5, math.sin(angle+2.4)*sz*0.5)
        local p3 = arrowPos + Vector2.new(math.cos(angle-2.4)*sz*0.5, math.sin(angle-2.4)*sz*0.5)
        d.arrow.PointA = p1 d.arrow.PointB = p2 d.arrow.PointC = p3
        d.arrow.Color = col d.arrow.Visible = true
    else
        d.arrow.Visible = false
    end

    if not bounds or not bounds.onScreen then
        -- Cacher tous sauf arrow
        for k2, obj in pairs(d) do
            if k2 ~= "arrow" and k2 ~= "sk" then obj.Visible = false end
        end
        for _, s in ipairs(d.sk) do s.Visible = false end
        return
    end

    local cx   = bounds.cx
    local w2   = bounds.w / 2
    local topY = bounds.top.Y
    local botY = bounds.bot.Y
    local left  = cx - w2
    local right = cx + w2
    local cornerLen = bounds.w * 0.25

    -- ===== BOX classique =====
    d.boxTop.From=Vector2.new(left,topY)   d.boxTop.To=Vector2.new(right,topY)
    d.boxBot.From=Vector2.new(left,botY)   d.boxBot.To=Vector2.new(right,botY)
    d.boxLeft.From=Vector2.new(left,topY)  d.boxLeft.To=Vector2.new(left,botY)
    d.boxRight.From=Vector2.new(right,topY) d.boxRight.To=Vector2.new(right,botY)
    for _, b in ipairs({d.boxTop,d.boxBot,d.boxLeft,d.boxRight}) do b.Color=col b.Visible=ESPBox end

    -- ===== CORNER BOX =====
    local cl = cornerLen
    -- Top-Left
    d.cTL1.From=Vector2.new(left,topY)     d.cTL1.To=Vector2.new(left+cl,topY)
    d.cTL2.From=Vector2.new(left,topY)     d.cTL2.To=Vector2.new(left,topY+cl)
    -- Top-Right
    d.cTR1.From=Vector2.new(right,topY)    d.cTR1.To=Vector2.new(right-cl,topY)
    d.cTR2.From=Vector2.new(right,topY)    d.cTR2.To=Vector2.new(right,topY+cl)
    -- Bot-Left
    d.cBL1.From=Vector2.new(left,botY)     d.cBL1.To=Vector2.new(left+cl,botY)
    d.cBL2.From=Vector2.new(left,botY)     d.cBL2.To=Vector2.new(left,botY-cl)
    -- Bot-Right
    d.cBR1.From=Vector2.new(right,botY)    d.cBR1.To=Vector2.new(right-cl,botY)
    d.cBR2.From=Vector2.new(right,botY)    d.cBR2.To=Vector2.new(right,botY-cl)
    for _, b in ipairs({d.cTL1,d.cTL2,d.cTR1,d.cTR2,d.cBL1,d.cBL2,d.cBR1,d.cBR2}) do
        b.Color=col b.Visible=ESPCornerBox
    end

    -- ===== FILLED BOX =====
    d.filled.Position = Vector2.new(left, topY)
    d.filled.Size     = Vector2.new(bounds.w, bounds.h)
    d.filled.Color    = col d.filled.Visible = ESPFilledBox

    -- ===== LINE depuis haut milieu =====
    local midTop = Vector2.new(cam.ViewportSize.X/2, 0)
    d.line.From=midTop d.line.To=Vector2.new(cx,topY) d.line.Color=col d.line.Visible=ESPLines

    -- ===== NAME =====
    local nameStr = isNPC and char.Name or char.Name
    d.name.Text=nameStr d.name.Position=Vector2.new(cx,topY-16) d.name.Color=col d.name.Visible=ESPName

    -- ===== DISTANCE =====
    d.dist.Text=dist.."m" d.dist.Position=Vector2.new(cx,botY+2) d.dist.Visible=ESPDistance

    -- ===== HEALTH BAR =====
    local hpRatio = math.clamp(hum.Health/hum.MaxHealth,0,1)
    local barX = left - 6
    local hpColor = Color3.fromRGB(math.floor(255*(1-hpRatio)), math.floor(255*hpRatio), 0)
    d.hpBg.From=Vector2.new(barX,topY) d.hpBg.To=Vector2.new(barX,botY)
    d.hpBg.Color=Color3.fromRGB(40,40,40) d.hpBg.Visible=ESPHealthBar
    local fillY = botY-(botY-topY)*hpRatio
    d.hpFill.From=Vector2.new(barX,fillY) d.hpFill.To=Vector2.new(barX,botY)
    d.hpFill.Color=hpColor d.hpFill.Visible=ESPHealthBar

    -- ===== HEALTH NUMBER =====
    d.hpNum.Text=math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
    d.hpNum.Position=Vector2.new(barX-2,topY+bounds.h/2-6)
    d.hpNum.Visible=ESPHealthNum

    -- ===== WEAPON =====
    local weaponStr = ""
    if ESPWeapon then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then weaponStr = child.Name break end
        end
    end
    d.weapon.Text=weaponStr d.weapon.Position=Vector2.new(cx,topY-28) d.weapon.Visible=ESPWeapon

    -- ===== TEAM =====
    local teamStr = ""
    if not isNPC then
        local pl = Players:FindFirstChild(char.Name)
        teamStr = pl and pl.Team and pl.Team.Name or ""
    end
    d.team.Text=teamStr d.team.Position=Vector2.new(cx,botY+13) d.team.Visible=ESPTeam

    -- ===== BOUNTY =====
    local bountyStr = ""
    if ESPBounty and not isNPC then
        local pl = Players:FindFirstChild(char.Name)
        if pl then
            local leaderstats = pl:FindFirstChild("leaderstats")
            local bounty = leaderstats and (leaderstats:FindFirstChild("Bounty") or leaderstats:FindFirstChild("Beli"))
            bountyStr = bounty and ("$"..tostring(bounty.Value)) or ""
        end
    end
    d.bounty.Text=bountyStr d.bounty.Position=Vector2.new(cx,botY+24) d.bounty.Visible=ESPBounty

    -- ===== HEAD DOT =====
    local head = char:FindFirstChild("Head")
    if head and ESPHeadDot then
        local headScreen, headOn = worldToViewport(head.Position)
        if headOn then
            d.headDot.Position=headScreen d.headDot.Color=col d.headDot.Visible=true
        else d.headDot.Visible=false end
    else d.headDot.Visible=false end

    -- ===== SKELETON =====
    for i, bone in ipairs(skBones) do
        local p1 = char:FindFirstChild(bone[1])
        local p2 = char:FindFirstChild(bone[2])
        local s = d.sk[i]
        if p1 and p2 and ESPSkeleton then
            local sp1, on1 = worldToViewport(p1.Position)
            local sp2, on2 = worldToViewport(p2.Position)
            if on1 or on2 then
                s.From=sp1 s.To=sp2 s.Color=col s.Visible=true
            else s.Visible=false end
        else s.Visible=false end
    end

    -- ===== CHAMS =====
    if ESPChams then
        applyChams(char, col)
    else
        removeChams(char)
    end
end

local function startESP()
    if espConnection then return end
    espConnection = RunService.RenderStepped:Connect(function()
        local tracked = {}

        -- Players
        if ESPEnabled then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= player then
                    local key = "player_" .. pl.UserId
                    tracked[key] = true
                    updateESP(pl, key, false)
                end
            end
        end

        -- NPCs
        if ESPNPCEnabled then
            local enemiesFolder = workspace:FindFirstChild("Enemies")
            if enemiesFolder then
                for _, npc in ipairs(enemiesFolder:GetChildren()) do
                    if npc:IsA("Model") then
                        local key = "npc_" .. npc.Name .. tostring(npc)
                        tracked[key] = true
                        updateESP(npc, key, true)
                    end
                end
            end
        end

        -- Nettoyer les objets des targets qui ne sont plus là
        for key, _ in pairs(espObjects) do
            if not tracked[key] then
                removeDrawings(key)
            end
        end
    end)
end

local function stopESP()
    if espConnection then espConnection:Disconnect() espConnection = nil end
    for key, _ in pairs(espObjects) do removeDrawings(key) end
end

-- =====================================================================
-- PLAYER FEATURES — Fake Items, Stretched, Jump, Speed, Fly
-- =====================================================================
local Mouse = player:GetMouse()

-- Fake Korblox
local fakeKorbloxEnabled  = false
local fakeKorbloxVersion  = "V1"
local korbloxMeshes       = {}

local function applyFakeKorblox()
    local char = player.Character if not char then return end
    local rl  = char:FindFirstChild("RightUpperLeg")
    local rl2 = char:FindFirstChild("RightLowerLeg")
    local rf  = char:FindFirstChild("RightFoot")
    if rl then
        rl.Transparency = 1
        for _, c in pairs(rl:GetChildren()) do if c:IsA("SpecialMesh") then c:Destroy() end end
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshId = "rbxassetid://139607718"
        mesh.TextureId = "rbxassetid://139607673"
        mesh.Scale = Vector3.new(1,1,1) mesh.Parent = rl
        table.insert(korbloxMeshes, mesh)
    end
    if rl2 then rl2.Transparency = 1 end
    if rf  then rf.Transparency  = 1 end
    if fakeKorbloxVersion == "V2" then
        for _, n in pairs({"LeftUpperLeg","LeftLowerLeg","LeftFoot"}) do
            local p = char:FindFirstChild(n) if p then p.Transparency = 1 end
        end
    end
end

local function removeFakeKorblox()
    for _, m in pairs(korbloxMeshes) do pcall(function() m:Destroy() end) end
    korbloxMeshes = {}
    local char = player.Character if not char then return end
    for _, n in pairs({"RightUpperLeg","RightLowerLeg","RightFoot","LeftUpperLeg","LeftLowerLeg","LeftFoot"}) do
        local p = char:FindFirstChild(n) if p then p.Transparency = 0 end
    end
end

-- Fake Headless
local fakeHeadlessEnabled = false
local fakeHeadlessVersion = "V1"
local hiddenHairAcc       = {}

local function applyFakeHeadless()
    local char = player.Character if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 1
        local face = head:FindFirstChild("face")
        if face then face.Transparency = 1 end
    end
    if fakeHeadlessVersion == "V2" then
        hiddenHairAcc = {}
        for _, obj in pairs(char:GetChildren()) do
            if obj:IsA("Accessory") then
                local handle = obj:FindFirstChild("Handle")
                if handle then handle.Transparency = 1 table.insert(hiddenHairAcc, handle) end
            end
        end
    end
end

local function removeFakeHeadless()
    local char = player.Character if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 0
        local face = head:FindFirstChild("face")
        if face then face.Transparency = 0 end
    end
    for _, h in pairs(hiddenHairAcc) do pcall(function() h.Transparency = 0 end) end
    hiddenHairAcc = {}
end

-- Stretched Screen
local stretchedEnabled = false
local stretchedAmount  = 0.65
local stretchConn      = nil

local function applyStretched()
    if stretchConn then stretchConn:Disconnect() end
    local cam = workspace.CurrentCamera
    stretchConn = RunService.RenderStepped:Connect(function()
        if cam and stretchedEnabled then
            cam.CFrame = cam.CFrame * CFrame.new(0,0,0,1,0,0,0,stretchedAmount,0,0,0,1)
        end
    end)
end

local function removeStretched()
    if stretchConn then stretchConn:Disconnect() stretchConn = nil end
end

-- Jump Boost
local jumpEnabled = false
local jumpPower   = 100

local function applyJump()
    local char = player.Character if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.JumpPower = jumpPower end
end

local function resetJump()
    local char = player.Character if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.JumpPower = 50 end
end

-- Speed Hack
local speedEnabled = false
local speedValue   = 50

local function applySpeed()
    local char = player.Character if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = speedValue end
end

local function resetSpeed()
    local char = player.Character if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 end
end

-- Fly Normal
local flyEnabled  = false
local flyConn     = nil
local flyBodyVel  = nil
local flyBodyGyro = nil
local flySpeed    = 50

-- Mini toggle Fly
local flyMiniGui    = nil
local flyMiniActive = false

local function createFlyMiniToggle()
    local playerGui = player:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild("FlyMiniGui") then playerGui.FlyMiniGui:Destroy() end
    local sg = Instance.new("ScreenGui")
    sg.Name = "FlyMiniGui" sg.ResetOnSpawn = false sg.Parent = playerGui
    local btn = Instance.new("TextButton", sg)
    btn.Size = UDim2.new(0,80,0,40)
    btn.Position = UDim2.new(0,10,0.5,-20)
    btn.Text = "FLY: OFF" btn.TextScaled = true
    btn.BackgroundColor3 = Color3.fromRGB(30,30,30)
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.BorderSizePixel = 0
    Instance.new("UICorner",btn).CornerRadius = UDim.new(0,8)
    local grad = Instance.new("UIGradient",btn) grad.Rotation = 45
    local function updateBtn(state)
        btn.Text = "FLY: "..(state and "ON" or "OFF")
        grad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, state and Color3.fromRGB(50,200,50) or Color3.fromRGB(80,80,80)),
            ColorSequenceKeypoint.new(1, state and Color3.fromRGB(50,255,50) or Color3.fromRGB(50,50,50)),
        }
    end
    btn.MouseButton1Click:Connect(function()
        flyMiniActive = not flyMiniActive
        updateBtn(flyMiniActive)
        if flyMiniActive then
            local char = player.Character if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart") if not hrp then return end
            local hum = char:FindFirstChildOfClass("Humanoid") if not hum then return end
            hum.PlatformStand = true
            flyBodyGyro = Instance.new("BodyGyro",hrp)
            flyBodyGyro.MaxTorque = Vector3.new(9e9,9e9,9e9) flyBodyGyro.D=100 flyBodyGyro.P=1e5
            flyBodyVel = Instance.new("BodyVelocity",hrp)
            flyBodyVel.MaxForce = Vector3.new(9e9,9e9,9e9) flyBodyVel.Velocity = Vector3.new(0,0,0)
        else
            if flyBodyVel  then flyBodyVel:Destroy()  flyBodyVel  = nil end
            if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
            local char = player.Character if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum.PlatformStand = false end
        end
    end)
    -- Drag
    local dragging,dragStart,startPos = false,nil,nil
    btn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true dragStart=i.Position startPos=btn.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    btn.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then
            local d=i.Position-dragStart
            local vp=workspace.CurrentCamera.ViewportSize
            btn.Position=UDim2.new(0,math.clamp(startPos.X.Offset+d.X,0,vp.X-btn.AbsoluteSize.X),0,math.clamp(startPos.Y.Offset+d.Y,0,vp.Y-btn.AbsoluteSize.Y))
        end
    end)
    updateBtn(false)
    flyMiniGui = sg
end

local function startFly()
    createFlyMiniToggle()
    local cam = workspace.CurrentCamera
    flyConn = RunService.RenderStepped:Connect(function()
        if not flyEnabled or not flyMiniActive then return end
        local char = player.Character if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart") if not hrp then return end
        if not flyBodyVel or not flyBodyGyro then return end
        local moveDir = Vector3.new(0,0,0)
        local cf = cam.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)    then moveDir = moveDir + cf.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)  then moveDir = moveDir - cf.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)  then moveDir = moveDir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then moveDir = moveDir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then moveDir = moveDir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0,1,0) end
        flyBodyVel.Velocity = moveDir.Magnitude>0 and moveDir.Unit*flySpeed or Vector3.new(0,0,0)
        flyBodyGyro.CFrame  = cf
    end)
end

local function stopFly()
    if flyConn     then flyConn:Disconnect()     flyConn     = nil end
    if flyBodyVel  then flyBodyVel:Destroy()     flyBodyVel  = nil end
    if flyBodyGyro then flyBodyGyro:Destroy()    flyBodyGyro = nil end
    if flyMiniGui  then flyMiniGui:Destroy()     flyMiniGui  = nil end
    flyMiniActive = false
    local char = player.Character if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum.PlatformStand = false end
end

-- Fly Spin
local flySpinEnabled = false
local flySpinConn    = nil
local flySpinAngle   = 0
local flySpinSpeed   = 50
local flySpinHeight  = 20

-- Mini toggle FlySpin
local flySpinMiniGui    = nil
local flySpinMiniActive = false

local function createFlySpinMiniToggle()
    local playerGui = player:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild("FlySpinMiniGui") then playerGui.FlySpinMiniGui:Destroy() end
    local sg = Instance.new("ScreenGui")
    sg.Name = "FlySpinMiniGui" sg.ResetOnSpawn = false sg.Parent = playerGui
    local btn = Instance.new("TextButton", sg)
    btn.Size = UDim2.new(0,90,0,40)
    btn.Position = UDim2.new(0,10,0.5,30)
    btn.Text = "SPIN: OFF" btn.TextScaled = true
    btn.BackgroundColor3 = Color3.fromRGB(30,30,30)
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.BorderSizePixel = 0
    Instance.new("UICorner",btn).CornerRadius = UDim.new(0,8)
    local grad = Instance.new("UIGradient",btn) grad.Rotation = 45
    local function updateBtn(state)
        btn.Text = "SPIN: "..(state and "ON" or "OFF")
        grad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, state and Color3.fromRGB(165,100,255) or Color3.fromRGB(80,80,80)),
            ColorSequenceKeypoint.new(1, state and Color3.fromRGB(200,50,255)  or Color3.fromRGB(50,50,50)),
        }
    end
    btn.MouseButton1Click:Connect(function()
        flySpinMiniActive = not flySpinMiniActive
        updateBtn(flySpinMiniActive)
    end)
    -- Drag
    local dragging,dragStart,startPos = false,nil,nil
    btn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true dragStart=i.Position startPos=btn.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    btn.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then
            local d=i.Position-dragStart
            local vp=workspace.CurrentCamera.ViewportSize
            btn.Position=UDim2.new(0,math.clamp(startPos.X.Offset+d.X,0,vp.X-btn.AbsoluteSize.X),0,math.clamp(startPos.Y.Offset+d.Y,0,vp.Y-btn.AbsoluteSize.Y))
        end
    end)
    updateBtn(false)
    flySpinMiniGui = sg
end

local function startFlySpin()
    createFlySpinMiniToggle()
    local char = player.Character if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") if not hum then return end
    hum.PlatformStand = true

    flySpinConn = RunService.Heartbeat:Connect(function()
        if not flySpinEnabled or not flySpinMiniActive then return end
        local char2 = player.Character if not char2 then return end
        local hrp2 = char2:FindFirstChild("HumanoidRootPart") if not hrp2 then return end
        flySpinAngle = flySpinAngle + math.rad(flySpinSpeed/10)
        local radius = 5
        local newPos = hrp2.Position + Vector3.new(
            math.cos(flySpinAngle)*radius,
            flySpinHeight*0.01,
            math.sin(flySpinAngle)*radius
        )
        hrp2.CFrame = CFrame.new(newPos) * CFrame.Angles(0, flySpinAngle, 0)
    end)
end

local function stopFlySpin()
    if flySpinConn then flySpinConn:Disconnect() flySpinConn = nil end
    if flySpinMiniGui then flySpinMiniGui:Destroy() flySpinMiniGui = nil end
    flySpinMiniActive = false
    local char = player.Character if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum.PlatformStand = false end
    local hrp = char:FindFirstChild("HumanoidRootPart") if hrp then hrp.Anchored = false end
end

-- =====================================================================
-- GLITCH FEATURES — Sanguine Z + Diamond
-- =====================================================================
local multiEnabled    = false
local multiPower      = 1000
local multiDuration   = 0.6
local multiCharging   = false
local multiChargeStart = 0

local diamondEnabled         = false
local diamondPower           = 400
local diamondDuration        = 0.9
local diamondRequiredCharge  = 1.0
local diamondCharging        = false
local diamondChargeStart     = 0

local function MegaBoost()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    local targetPos = Mouse.Hit.p
    local direction = (targetPos - hrp.Position).Unit
    hum.PlatformStand = true
    local att = Instance.new("Attachment", hrp)
    local lv = Instance.new("LinearVelocity", hrp)
    lv.MaxForce = 9999999
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.VectorVelocity = direction * multiPower
    lv.Attachment0 = att
    task.wait(multiDuration)
    if lv  then lv:Destroy()  end
    if att then att:Destroy() end
    hum.PlatformStand = false
end

RunService.Heartbeat:Connect(function()
    if not multiEnabled then return end
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end
    local isGhoulCharging = false
    for _, anim in pairs(hum:GetPlayingAnimationTracks()) do
        if anim.Animation.AnimationId:find("14418367908") or anim.Name == "GhoulZCharge" then
            isGhoulCharging = true break
        end
    end
    if isGhoulCharging then
        if not multiCharging then multiCharging = true multiChargeStart = tick() end
    else
        if multiCharging then
            if (tick() - multiChargeStart) >= 3.0 then task.spawn(MegaBoost) end
            multiCharging = false multiChargeStart = 0
        end
    end
end)

local function DiamondBoost()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    local direction = (Mouse.Hit.p - hrp.Position).Unit
    hum.PlatformStand = true
    local att = Instance.new("Attachment", hrp)
    local lv = Instance.new("LinearVelocity", hrp)
    lv.MaxForce = 9999999
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    lv.VectorVelocity = direction * diamondPower
    lv.Attachment0 = att
    task.wait(diamondDuration)
    if lv  then lv:Destroy()  end
    if att then att:Destroy() end
    hum.PlatformStand = false
end

RunService.Heartbeat:Connect(function()
    if not diamondEnabled then return end
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum then return end
    local isCharging = false
    for _, anim in pairs(hum:GetPlayingAnimationTracks()) do
        if anim.Animation.AnimationId:find("14414815375") then
            isCharging = true break
        end
    end
    if isCharging then
        if not diamondCharging then diamondCharging = true diamondChargeStart = tick() end
    else
        if diamondCharging then
            if (tick() - diamondChargeStart) >= diamondRequiredCharge then
                task.spawn(DiamondBoost)
            end
            diamondCharging = false diamondChargeStart = 0
        end
    end
end)

-- =====================================================================
-- VSKILL MODULE — Pause/Restore pendant skills spéciaux
-- (Shark Anchor Z, Dough V, Cursed Dual Katana Z)
-- =====================================================================
local v_currentTool   = nil
local v_lastTool      = nil
local sharkZActive    = false
local vActive         = false
local cursedZActive   = false
local v_dmgConn       = nil
local v_charConns     = {}
local rightTouchActive = false

local function DisableSilentAimbot()
    SilentAimPlayersEnabled = false
    SilentAimNPCsEnabled    = false
end

local function EnableSilentAimbot()
    SilentAimPlayersEnabled = UserWantsPlayerAim
    SilentAimNPCsEnabled    = UserWantsNPCAim
end

local function isValidStopCondition()
    return (v_currentTool and v_currentTool.Name == "Shark Anchor" and sharkZActive)
        or (v_lastTool == "Dough-Dough" and vActive)
        or (v_currentTool and v_currentTool.Name == "Cursed Dual Katana" and cursedZActive)
end

local function clearVConnections()
    for _, c in ipairs(v_charConns) do pcall(function() c:Disconnect() end) end
    v_charConns = {}
end

local function hookVTool(tool)
    v_currentTool = tool
    v_lastTool    = tool.Name
    table.insert(v_charConns, tool.AncestryChanged:Connect(function(_, parent)
        if not parent then
            v_currentTool  = nil
            v_lastTool     = nil
            sharkZActive   = false
            vActive        = false
            cursedZActive  = false
            rightTouchActive = false
            EnableSilentAimbot()
        end
    end))
end

-- Touch droit : pause pendant le skill
UserInputService.TouchStarted:Connect(function(touch)
    local cam = workspace.CurrentCamera
    if not cam then return end
    if touch.Position.X > cam.ViewportSize.X / 2 then
        rightTouchActive = true
        if isValidStopCondition() then DisableSilentAimbot() end
    end
end)

UserInputService.TouchEnded:Connect(function(touch)
    local cam = workspace.CurrentCamera
    if not cam then return end
    if touch.Position.X > cam.ViewportSize.X / 2 then
        rightTouchActive = false
        EnableSilentAimbot()
        sharkZActive = false vActive = false cursedZActive = false
    end
end)

-- Watch DmgCounter pour restore après les dégâts
local function watchVDamageCounter()
    if v_dmgConn then pcall(function() v_dmgConn:Disconnect() end) v_dmgConn = nil end
    task.spawn(function()
        while true do
            local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("Main")
            if not gui then task.wait(1) continue end
            local dmgCounter = gui:FindFirstChild("DmgCounter")
            if not dmgCounter then task.wait(1) continue end
            local dmgLabel = dmgCounter:FindFirstChild("Text")
            if not dmgLabel then task.wait(1) continue end
            v_dmgConn = dmgLabel:GetPropertyChangedSignal("Text"):Connect(function()
                local dmgText = tonumber(dmgLabel.Text) or 0
                if dmgText > 0 and isValidStopCondition() and rightTouchActive then
                    DisableSilentAimbot()
                elseif not rightTouchActive then
                    EnableSilentAimbot()
                end
            end)
            table.insert(v_charConns, v_dmgConn)
            break
        end
    end)
end

-- Hook détection Shark Z / Dough V / Cursed Z
if not getgenv().VSkillHooked then
    getgenv().VSkillHooked = true
    local vOld
    vOld = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if method == "InvokeServer" or method == "FireServer" then
            local a1 = args[1]
            if typeof(a1) == "string" then
                if a1:upper() == "Z" then
                    if v_currentTool and v_currentTool.Name == "Shark Anchor" then sharkZActive = true end
                    if v_currentTool and v_currentTool.Name == "Cursed Dual Katana" then cursedZActive = true end
                end
                if a1:upper() == "V" then
                    if v_lastTool == "Dough-Dough" then vActive = true end
                end
            end
        end
        return vOld(self, ...)
    end)
end

-- Character handling VSkill
local function onVCharacterAdded(char)
    clearVConnections()
    sharkZActive = false vActive = false cursedZActive = false rightTouchActive = false
    EnableSilentAimbot()
    table.insert(v_charConns, char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then hookVTool(child) end
    end))
    table.insert(v_charConns, char.ChildRemoved:Connect(function(child)
        if child == v_currentTool then
            v_currentTool = nil v_lastTool = nil
            sharkZActive = false vActive = false cursedZActive = false
            rightTouchActive = false
            EnableSilentAimbot()
        end
    end))
    watchVDamageCounter()
end

player.CharacterAdded:Connect(onVCharacterAdded)
if player.Character then onVCharacterAdded(player.Character) end

-- =====================================================================
-- SORU AUTO AIM — Logique exacte + Ally check + Select Player
-- =====================================================================
local SoruAutoAimEnabled = false
local CurrentTarget      = nil
local SoruSelectedPlayer = nil  -- joueur sélectionné manuellement

local function isSoruAlly(targetPlayer)
    local myGui = player:FindFirstChild("PlayerGui")
    if not myGui then return false end
    local scrolling = myGui:FindFirstChild("Main")
        and myGui.Main:FindFirstChild("Allies")
        and myGui.Main.Allies:FindFirstChild("Container")
        and myGui.Main.Allies.Container:FindFirstChild("Allies")
        and myGui.Main.Allies.Container.Allies:FindFirstChild("ScrollingFrame")
    if scrolling then
        for _, frame in pairs(scrolling:GetDescendants()) do
            if frame:IsA("ImageButton") and frame.Name == targetPlayer.Name then return true end
        end
    end
    return false
end

local function isSoruEnemy(targetPlayer)
    if not targetPlayer or targetPlayer == player then return false end
    local myTeam     = player.Team
    local targetTeam = targetPlayer.Team
    if myTeam and targetTeam then
        if myTeam.Name == "Pirates"  and targetTeam.Name == "Marines" then return true end
        if myTeam.Name == "Marines"  and targetTeam.Name == "Pirates"  then return true end
        if myTeam.Name == "Pirates"  and targetTeam.Name == "Pirates"  then
            return not isSoruAlly(targetPlayer)
        end
        if myTeam.Name == "Marines"  and targetTeam.Name == "Marines"  then return false end
    end
    return true
end

getgenv().SoruAutoAim = false

task.spawn(function()
    while true do
        task.wait(0.1)
        if getgenv().SoruAutoAim then
            -- Si un joueur spécifique est sélectionné
            if SoruSelectedPlayer and SoruSelectedPlayer.Character and SoruSelectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
                CurrentTarget = SoruSelectedPlayer.Character.HumanoidRootPart
            else
                -- Sinon le plus proche qui est ennemi
                local closest, shortestDist = nil, 300
                local myPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if myPart then
                    for _, v in pairs(Players:GetPlayers()) do
                        if v ~= player and isSoruEnemy(v) and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                            local root = v.Character.HumanoidRootPart
                            local dist = (root.Position - myPart.Position).Magnitude
                            if dist < shortestDist then shortestDist = dist closest = root end
                        end
                    end
                end
                CurrentTarget = closest
            end
        else
            CurrentTarget = nil
        end
    end
end)

-- =====================================================================
-- HOOK __namecall
-- =====================================================================
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, V1, V2, ...)
    local method = getnamecallmethod():lower()
    if method == "fireserver" or method == "invokeserver" then

        -- ✅ WHITELIST TAP — Portal jamais redirigé
        if V1 == "TAP" then return oldNamecall(self, V1, V2, ...) end

        -- SORU AUTO AIM hook (InvokeServer depuis Humanoid)
        if getgenv().SoruAutoAim and CurrentTarget then
            local method2 = getnamecallmethod()
            if method2 == "InvokeServer" and self.Parent and tostring(self.Parent) == "Humanoid" then
                local newArgs = {V1, V2, ...}
                for i, arg in pairs(newArgs) do
                    if typeof(arg) == "Vector3" then newArgs[i] = CurrentTarget.Position end
                end
                return oldNamecall(self, table.unpack(newArgs))
            end
        end

        -- Godhuman Z detection
        if type(V1) == "string" and V1:upper() == "Z" then
            if currentTool and currentTool.Name == "Godhuman" then godhumanZActive = true end
        end

        -- FireServer V1 = Vector3
        if method == "fireserver" and typeof(V1) == "Vector3" then
            if SilentAimPlayersEnabled and PlayersPosition then return oldNamecall(self, PlayersPosition, V2, ...)
            elseif SilentAimNPCsEnabled and NPCPosition then return oldNamecall(self, NPCPosition, V2, ...) end
        end

        -- FireServer Booms (ZSkillorM1)
        if method == "fireserver" and type(V1) == "string" and table.find(Booms, V1) and ZSkillorM1 then
            if SilentAimPlayersEnabled and PlayersPosition then return oldNamecall(self, V1, PlayersPosition, nil, ...)
            elseif SilentAimNPCsEnabled and NPCPosition then return oldNamecall(self, V1, NPCPosition, nil, ...) end
        end


        -- InvokeServer V2 = Vector3
        -- Si V1 est un skill (X, Z...) et ZSkillorM1 est OFF → laisser passer sans modifier
        if method == "invokeserver" and typeof(V2) == "Vector3" then
            if type(V1) == "string" and table.find(Booms, V1) and not ZSkillorM1 then
                return oldNamecall(self, V1, V2, ...)
            end
            if SilentAimPlayersEnabled and PlayersPosition then return oldNamecall(self, V1, PlayersPosition, ...)
            elseif SilentAimNPCsEnabled and NPCPosition then return oldNamecall(self, V1, NPCPosition, ...) end
        end
    end
    return oldNamecall(self, V1, V2, ...)
end)

-- Hook Mouse.Hit pour Soru Auto Aim
local mt2 = getrawmetatable(game)
local oldIndex2 = mt2.__index
setreadonly(mt2, false)
mt2.__index = newcclosure(function(t, k)
    if getgenv().SoruAutoAim and t == Mouse and CurrentTarget then
        if k == "Hit"    then return CurrentTarget.CFrame end
        if k == "Target" then return CurrentTarget end
    end
    return oldIndex2(t, k)
end)
setreadonly(mt2, true)

-- =====================================================================
-- TOOL WATCHER
-- =====================================================================
local function clearConnections()
    for _, c in ipairs(characterConnections) do pcall(function() c:Disconnect() end) end
    characterConnections = {}
end
local function hookTool(tool)
    currentTool = tool
    table.insert(characterConnections, tool.AncestryChanged:Connect(function(_, parent)
        if not parent then currentTool = nil godhumanZActive = false aimlockActive = false end
    end))
end
local function onCharacterAdded(char)
    clearConnections() godhumanZActive = false stopAimlock()
    for _, child in ipairs(char:GetChildren()) do if child:IsA("Tool") then hookTool(child) end end
    table.insert(characterConnections, char.ChildAdded:Connect(function(child) if child:IsA("Tool") then hookTool(child) end end))
    table.insert(characterConnections, char.ChildRemoved:Connect(function(child)
        if child == currentTool then currentTool = nil godhumanZActive = false end
    end))
end
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

local function UpdateSilentAimState()
    SilentAimPlayersEnabled = MiniPlayerState and MiniPlayerState.value or false
    SilentAimNPCsEnabled    = MiniNpcState    and MiniNpcState.value    or false
    UserWantsPlayerAim = SilentAimPlayersEnabled UserWantsNPCAim = SilentAimNPCsEnabled
    if SilentAimPlayersEnabled or SilentAimNPCsEnabled then startRenderLoop()
    else stopRenderLoop() clearHighlight() end
end

-- =====================================================================
-- WINDOW OBSIDIAN
-- =====================================================================
local Window = Library:CreateWindow({
    Title = "gotcha.exe",
    Footer = "By HimselfZen",
    ShowCustomCursor = true,
    NotifySide = "Right",
})

local Tabs = {
    Main     = Window:AddTab("Main",     "home"),
    Legit    = Window:AddTab("Legit",    "crosshair"),
    Player   = Window:AddTab("Player",   "user"),
    Glitch   = Window:AddTab("Glitch",   "zap"),
    Visual   = Window:AddTab("Visual",   "eye"),
    Font     = Window:AddTab("Font",     "type"),
    Settings = Window:AddTab("Settings", "settings"),
}

-- =====================================================================
-- TAB MAIN — Soru Auto Aim
-- =====================================================================
local SoruBox = Tabs.Main:AddLeftGroupbox("Soru Auto Aim")

-- Récupérer les joueurs pour le select
local soruPlayerNames = {"None"}
for _, p in pairs(Players:GetPlayers()) do
    if p ~= player then table.insert(soruPlayerNames, p.Name) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= player then table.insert(soruPlayerNames, p.Name) end
end)

SoruBox:AddToggle("SoruAimToggle", {
    Text = "Soru Auto Aim", Default = false,
    Tooltip = "Redirige tes attaques vers l'ennemi le plus proche (ignore les alliés)",
    Callback = function(v)
        SoruAutoAimEnabled = v
        getgenv().SoruAutoAim = v
        if not v then CurrentTarget = nil end
    end,
})

SoruBox:AddDropdown("SoruSelectPlayer", {
    Values = soruPlayerNames, Default = 1,
    Text = "Select Target",
    Tooltip = "Lock sur un joueur spécifique (None = auto)",
    Callback = function(v)
        if v == "None" then
            SoruSelectedPlayer = nil
        else
            local found = Players:FindFirstChild(v)
            if found then SoruSelectedPlayer = found end
        end
    end,
})

-- =====================================================================
-- TAB LEGIT — Silent Aim
-- =====================================================================
local SAPlayersBox = Tabs.Legit:AddLeftGroupbox("Silent Aim — Players")
local SANPCBox     = Tabs.Legit:AddRightGroupbox("Silent Aim — NPC")

SAPlayersBox:AddToggle("SilentAimPlayers", {
    Text = "Silent Aim Players", Default = false,
    Tooltip = "Redirige tes attaques vers le joueur le plus proche",
    Callback = function(v)
        UserWantsPlayerAim = v SilentAimPlayersEnabled = v
        if v then startRenderLoop() else if not SilentAimNPCsEnabled then stopRenderLoop() end end
    end,
})

SAPlayersBox:AddToggle("SilentAimMiniPlayer", {
    Text = "Mini Toggle Players", Default = false,
    Tooltip = "Bouton draggable sur l'écran",
    Callback = function(v)
        if not MiniPlayerCreated and v then
            MiniPlayerState = { value = SilentAimPlayersEnabled }
            MiniPlayerGui = createMiniToggle("Player", UDim2.new(0,10,0,90), MiniPlayerState, function(val)
                MiniPlayerState.value = val UpdateSilentAimState()
            end)
            MiniPlayerCreated = true
        elseif MiniPlayerCreated and MiniPlayerGui then MiniPlayerGui.Enabled = v end
    end,
})

local playerNames = {"None"}
for _, p in pairs(Players:GetPlayers()) do
    if p ~= player then table.insert(playerNames, p.Name) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= player then table.insert(playerNames, p.Name) end
end)

SAPlayersBox:AddDropdown("SelectPlayer", {
    Values = playerNames, Default = 1,
    Text = "Select Target Player",
    Tooltip = "Lock sur un joueur spécifique",
    Callback = function(v)
        if v == "None" then Selectedplayer = nil
        else local found = Players:FindFirstChild(v) if found then Selectedplayer = found end end
    end,
})

SAPlayersBox:AddToggle("Highlight", {
    Text = "Highlight Target", Default = false,
    Callback = function(v) HighlightEnabled = v if not v then clearHighlight() end end,
})

SAPlayersBox:AddToggle("ZSkillorM1", {
    Text = "Z / M1 Skills Aim", Default = false,
    Tooltip = "Active le silent aim sur les skills Z et M1",
    Callback = function(v) ZSkillorM1 = v end,
})

SAPlayersBox:AddToggle("GodhumanZ", {
    Text = "Godhuman Z Aimlock", Default = false,
    Tooltip = "Aimlock caméra 1s après le Z de Godhuman",
    Callback = function(v) ZSkillsEnabled = v if not v then stopAimlock() end end,
})

SAPlayersBox:AddToggle("Prediction", {
    Text = "Prediction", Default = false,
    Callback = function(v) PredictionEnabled = v end,
})

SAPlayersBox:AddSlider("PredictionAmount", {
    Text = "Prediction Amount", Default = 1, Min = 1, Max = 4, Rounding = 0,
    Suffix = "00ms",
    Callback = function(v) PredictionAmount = v / 10 end,
})

SAPlayersBox:AddSlider("DistanceLimit", {
    Text = "Distance Limit", Default = 1000, Min = 100, Max = 3000, Rounding = 0,
    Suffix = "m",
    Callback = function(v) maxRange = v end,
})

SANPCBox:AddToggle("SilentAimNPC", {
    Text = "Silent Aim NPC", Default = false,
    Tooltip = "Redirige tes attaques vers le NPC le plus proche",
    Callback = function(v)
        UserWantsNPCAim = v SilentAimNPCsEnabled = v
        if v then startRenderLoop() else if not SilentAimPlayersEnabled then stopRenderLoop() end end
    end,
})

SANPCBox:AddToggle("SilentAimMiniNPC", {
    Text = "Mini Toggle NPC", Default = false,
    Callback = function(v)
        if not MiniNpcCreated and v then
            MiniNpcState = { value = SilentAimNPCsEnabled }
            MiniNpcGui = createMiniToggle("NPC", UDim2.new(0,10,0,50), MiniNpcState, function(val)
                MiniNpcState.value = val UpdateSilentAimState()
            end)
            MiniNpcCreated = true
        elseif MiniNpcCreated and MiniNpcGui then MiniNpcGui.Enabled = v end
    end,
})

-- =====================================================================
-- TAB PLAYER
-- =====================================================================
local FakeItemsBox  = Tabs.Player:AddLeftGroupbox("Fake Items")
local PlayerMoveBox = Tabs.Player:AddRightGroupbox("Movement")
local PlayerMiscBox = Tabs.Player:AddLeftGroupbox("Misc")

-- Fake Korblox
FakeItemsBox:AddDropdown("KorbloxVersion", {
    Values = {"V1","V2"}, Default = 1, Text = "Korblox Version",
    Callback = function(v)
        fakeKorbloxVersion = v
        if fakeKorbloxEnabled then removeFakeKorblox() applyFakeKorblox() end
    end,
})
FakeItemsBox:AddToggle("FakeKorblox", {
    Text = "Fake Korblox", Default = false,
    Callback = function(v) fakeKorbloxEnabled = v if v then applyFakeKorblox() else removeFakeKorblox() end end,
})
FakeItemsBox:AddDivider()
-- Fake Headless
FakeItemsBox:AddDropdown("HeadlessVersion", {
    Values = {"V1","V2"}, Default = 1, Text = "Headless Version",
    Callback = function(v)
        fakeHeadlessVersion = v
        if fakeHeadlessEnabled then removeFakeHeadless() applyFakeHeadless() end
    end,
})
FakeItemsBox:AddToggle("FakeHeadless", {
    Text = "Fake Headless", Default = false,
    Callback = function(v) fakeHeadlessEnabled = v if v then applyFakeHeadless() else removeFakeHeadless() end end,
})
FakeItemsBox:AddDivider()
-- Stretched Screen
FakeItemsBox:AddToggle("Stretched", {
    Text = "Stretched Screen", Default = false,
    Callback = function(v) stretchedEnabled = v if v then applyStretched() else removeStretched() end end,
})
FakeItemsBox:AddSlider("StretchAmount", {
    Text = "Stretch Amount", Default = 65, Min = 50, Max = 100, Rounding = 0, Suffix = "%",
    Callback = function(v) stretchedAmount = v/100 if stretchedEnabled then applyStretched() end end,
})

-- Movement
PlayerMoveBox:AddToggle("JumpBoost", {
    Text = "Jump Boost", Default = false,
    Callback = function(v) jumpEnabled = v if v then applyJump() else resetJump() end end,
})
PlayerMoveBox:AddSlider("JumpPower", {
    Text = "Jump Power", Default = 100, Min = 50, Max = 500, Rounding = 0,
    Callback = function(v) jumpPower = v if jumpEnabled then applyJump() end end,
})
PlayerMoveBox:AddDivider()
PlayerMoveBox:AddToggle("SpeedHack", {
    Text = "Speed Hack", Default = false,
    Callback = function(v) speedEnabled = v if v then applySpeed() else resetSpeed() end end,
})
PlayerMoveBox:AddSlider("SpeedValue", {
    Text = "Walk Speed", Default = 50, Min = 16, Max = 50000, Rounding = 0,
    Callback = function(v) speedValue = v if speedEnabled then applySpeed() end end,
})
PlayerMoveBox:AddDivider()
PlayerMoveBox:AddToggle("FlyNormal", {
    Text = "Fly", Default = false,
    Tooltip = "W/A/S/D + Space/Ctrl pour voler",
    Callback = function(v) flyEnabled = v if v then startFly() else stopFly() end end,
})
PlayerMoveBox:AddSlider("FlySpeed", {
    Text = "Fly Speed", Default = 50, Min = 10, Max = 300, Rounding = 0,
    Callback = function(v) flySpeed = v end,
})
PlayerMoveBox:AddDivider()
PlayerMoveBox:AddToggle("FlySpin", {
    Text = "Fly Spin", Default = false,
    Callback = function(v) flySpinEnabled = v if v then startFlySpin() else stopFlySpin() end end,
})
PlayerMoveBox:AddSlider("FlySpinSpeed", {
    Text = "Spin Speed", Default = 50, Min = 5, Max = 200, Rounding = 0,
    Callback = function(v) flySpinSpeed = v end,
})

-- Misc
PlayerMiscBox:AddToggle("AutoKen", {
    Text = "Auto Ken", Default = false,
    Callback = function(v) AutoKen = v if v then startAutoKenLoop() end end,
})

-- =====================================================================
-- TAB GLITCH
-- =====================================================================
local SanguineBox = Tabs.Glitch:AddLeftGroupbox("Sanguine Glitch")
local DiamondBox  = Tabs.Glitch:AddRightGroupbox("Diamond Glitch")

SanguineBox:AddToggle("SanguineGlitch", {
    Text = "Sanguine Z Boost", Default = false,
    Tooltip = "Détecte GhoulZCharge → propulsion vers ta visée",
    Callback = function(v) multiEnabled = v if not v then multiCharging = false multiChargeStart = 0 end end,
})
SanguineBox:AddSlider("SanguinePower", {
    Text = "Puissance", Default = 1000, Min = 100, Max = 5000, Rounding = 0, Suffix = " force",
    Callback = function(v) multiPower = v end,
})
SanguineBox:AddSlider("SanguineDuration", {
    Text = "Durée", Default = 60, Min = 10, Max = 200, Rounding = 0, Suffix = " cs",
    Callback = function(v) multiDuration = v/100 end,
})

DiamondBox:AddToggle("DiamondGlitch", {
    Text = "Diamond Glitch", Default = false,
    Tooltip = "Détecte CombatZ → propulsion vers ta visée",
    Callback = function(v) diamondEnabled = v if not v then diamondCharging = false diamondChargeStart = 0 end end,
})
DiamondBox:AddSlider("DiamondPower", {
    Text = "Puissance", Default = 400, Min = 100, Max = 5000, Rounding = 0, Suffix = " force",
    Callback = function(v) diamondPower = v end,
})
DiamondBox:AddSlider("DiamondDuration", {
    Text = "Durée", Default = 90, Min = 10, Max = 200, Rounding = 0, Suffix = " cs",
    Callback = function(v) diamondDuration = v/100 end,
})
DiamondBox:AddSlider("DiamondCharge", {
    Text = "Charge Min", Default = 10, Min = 1, Max = 50, Rounding = 0, Suffix = "00ms",
    Callback = function(v) diamondRequiredCharge = v/10 end,
})

-- =====================================================================
-- TAB VISUAL
-- =====================================================================
local ESPPlayersBox = Tabs.Visual:AddLeftGroupbox("ESP Players")
local ESPNPCBox     = Tabs.Visual:AddRightGroupbox("ESP NPC")

ESPPlayersBox:AddToggle("ESPPlayers", {
    Text = "ESP Players", Default = false,
    Callback = function(v) ESPEnabled = v
        if ESPEnabled or ESPNPCEnabled then startESP() else stopESP() end
    end,
})
ESPPlayersBox:AddDivider()
ESPPlayersBox:AddToggle("ESPBox",       { Text = "Box",              Default = true,  Callback = function(v) ESPBox       = v end })
ESPPlayersBox:AddToggle("ESPCornerBox", { Text = "Corner Box",       Default = false, Callback = function(v) ESPCornerBox = v end })
ESPPlayersBox:AddToggle("ESPFilledBox", { Text = "Filled Box",       Default = false, Callback = function(v) ESPFilledBox = v end })
ESPPlayersBox:AddToggle("ESPLines",     { Text = "Lines (haut milieu)", Default = true, Callback = function(v) ESPLines   = v end })
ESPPlayersBox:AddDivider()
ESPPlayersBox:AddToggle("ESPName",      { Text = "Name",             Default = true,  Callback = function(v) ESPName      = v end })
ESPPlayersBox:AddToggle("ESPDistance",  { Text = "Distance",         Default = true,  Callback = function(v) ESPDistance  = v end })
ESPPlayersBox:AddToggle("ESPTeam",      { Text = "Team",             Default = false, Callback = function(v) ESPTeam      = v end })
ESPPlayersBox:AddToggle("ESPBounty",    { Text = "Bounty",           Default = false, Callback = function(v) ESPBounty    = v end })
ESPPlayersBox:AddToggle("ESPWeapon",    { Text = "Weapon",           Default = false, Callback = function(v) ESPWeapon    = v end })
ESPPlayersBox:AddDivider()
ESPPlayersBox:AddToggle("ESPHealthBar", { Text = "Health Bar",       Default = true,  Callback = function(v) ESPHealthBar = v end })
ESPPlayersBox:AddToggle("ESPHealthNum", { Text = "Health Number",    Default = false, Callback = function(v) ESPHealthNum = v end })
ESPPlayersBox:AddDivider()
ESPPlayersBox:AddToggle("ESPSkeleton",  { Text = "Skeleton",         Default = false, Callback = function(v) ESPSkeleton  = v end })
ESPPlayersBox:AddToggle("ESPHeadDot",   { Text = "Head Dot",         Default = false, Callback = function(v) ESPHeadDot   = v end })
ESPPlayersBox:AddToggle("ESPOffScreen", { Text = "Off-Screen Arrows",Default = false, Callback = function(v) ESPOffScreen = v end })
ESPPlayersBox:AddToggle("ESPChams",     { Text = "Chams",            Default = false, Callback = function(v) ESPChams     = v end })

ESPNPCBox:AddToggle("ESPNPCs", {
    Text = "ESP NPCs", Default = false,
    Callback = function(v) ESPNPCEnabled = v
        if ESPEnabled or ESPNPCEnabled then startESP() else stopESP() end
    end,
})

-- =====================================================================
-- TAB FONT
-- =====================================================================
-- (vide pour l'instant)

-- =====================================================================
-- TAB SETTINGS
-- =====================================================================
local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift", NoUI = true, Text = "Menu keybind",
})
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("GotchaExe")
SaveManager:SetFolder("GotchaExe")

ThemeManager:ApplyToGroupbox(MenuGroup)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

Library:Notify({
    Title = "gotcha.exe",
    Description = "Silent Aim chargé ! By HimselfZen",
    Time = 5,
})

print("✅ gotcha.exe | Obsidian + Silent Aim Full | By HimselfZen")

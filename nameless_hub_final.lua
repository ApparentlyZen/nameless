-- =====================================================================
-- ✧ GOTCHA.EXE | ELITE EXTERNAL (SKEET/GAMESENSE STYLE) ✧
-- =====================================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer
local Mouse = player:GetMouse()

if CoreGui:FindFirstChild("GotchaElite") then CoreGui.GotchaElite:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GotchaElite"
ScreenGui.Parent = (cloneref and cloneref(CoreGui) or CoreGui)

local Theme = {
    Bg_Out = Color3.fromRGB(12, 12, 12),
    Bg_In  = Color3.fromRGB(20, 20, 20),
    Tab_Bg = Color3.fromRGB(16, 16, 16),
    Accent = Color3.fromRGB(165, 255, 0),
    Text   = Color3.fromRGB(240, 240, 240),
    Border = Color3.fromRGB(40, 40, 40),
    Font   = Enum.Font.Code
}

-- ========== VARIABLES ==========
local hitboxEnabled = false
local hitboxSize = 20
local noAnimationEnabled = false
local autoClickEnabled = false
local soruAutoAimEnabled = true
local fakeKorbloxEnabled = false
local fakeKorbloxVersion = "V1"
local fakeHeadlessEnabled = false
local fakeHeadlessVersion = "V1"
local stretchedEnabled = false
local stretchedAmount = 0.65
local removeGfxEnabled = false
local spinPlayerEnabled = false
local spinSpeed = 50
local skinStealerEnabled = false
local fontChangerEnabled = false
local fontPreset = "GothamSsm"
local targetPlayerName = ""
local hitboxParts = {}
local playerConnections = {}
local autoClickConnection, animationConnection, spinConnection = nil, nil, nil
local removeGfxConnection, stretchConnection = nil, nil
local korbloxMeshes = {}
local originalAppearance, stolenAccessories, hiddenHairAccessories = {}, {}, {}
local updatedFonts = {}
local fontConn, gfxWorkspaceConn, gfxPlayersConn = nil, nil, nil
local CurrentTarget = nil

-- Sanguine Glitch
local multiEnabled = false
local multiPower = 1000
local multiDuration = 0.6
local multiCharging = false
local multiChargeStart = 0

-- ========== SORU AUTO AIM ==========
getgenv().SoruAutoAim = true
task.spawn(function()
    while true do
        task.wait(0.2)
        if getgenv().SoruAutoAim then
            local closest, shortestDist = nil, 300
            local myPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if myPart then
                for _, v in pairs(Players:GetPlayers()) do
                    if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        local root = v.Character.HumanoidRootPart
                        local dist = (root.Position - myPart.Position).Magnitude
                        if dist < shortestDist then shortestDist = dist closest = root end
                    end
                end
            end
            CurrentTarget = closest
        else
            CurrentTarget = nil
        end
    end
end)

-- ========== HOOKS ==========
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
local oldIndex = mt.__index
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if method == "InvokeServer" and self.Parent and tostring(self.Parent) == "Humanoid" then
        if getgenv().SoruAutoAim and CurrentTarget then
            for i, arg in pairs(args) do
                if typeof(arg) == "Vector3" then args[i] = CurrentTarget.Position end
            end
        end
    end
    return oldNamecall(self, unpack(args))
end)
mt.__index = newcclosure(function(t, k)
    if getgenv().SoruAutoAim and t == Mouse and CurrentTarget then
        if k == "Hit" then return CurrentTarget.CFrame end
        if k == "Target" then return CurrentTarget end
    end
    return oldIndex(t, k)
end)
setreadonly(mt, true)

-- ========== HITBOX ==========
local function createInvisibleHitbox(character)
    if not character then return end
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end
    if hitboxParts[character] then pcall(function() hitboxParts[character]:Destroy() end) end
    local p = Instance.new("Part")
    p.Name = "ExpandedHitbox"
    p.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
    p.CFrame = hrp.CFrame p.Transparency = 1 p.CanCollide = false
    p.Anchored = false p.Massless = true p.CastShadow = false
    local w = Instance.new("WeldConstraint")
    w.Part0 = hrp w.Part1 = p w.Parent = p
    p.Parent = character
    hitboxParts[character] = p
end
local function removeHitbox(character)
    if hitboxParts[character] then pcall(function() hitboxParts[character]:Destroy() end) hitboxParts[character] = nil end
end
local function setupPlayer(op)
    if op == player then return end
    if playerConnections[op] then for _, c in pairs(playerConnections[op]) do pcall(function() c:Disconnect() end) end end
    playerConnections[op] = {}
    table.insert(playerConnections[op], op.CharacterAdded:Connect(function(char)
        task.wait(1) if hitboxEnabled then createInvisibleHitbox(char) end
    end))
    if op.Character then task.spawn(function() task.wait(1) if hitboxEnabled then createInvisibleHitbox(op.Character) end end) end
end

-- ========== NO ANIMATION ==========
local function disableAllAnimations()
    if animationConnection then animationConnection:Disconnect() end
    animationConnection = RunService.Heartbeat:Connect(function()
        if not noAnimationEnabled or not player.Character then return end
        pcall(function()
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local anim = hum:FindFirstChildOfClass("Animator")
            if anim then for _, t in pairs(anim:GetPlayingAnimationTracks()) do t:Stop() t:Destroy() end end
            local a = player.Character:FindFirstChild("Animate")
            if a then a:Destroy() end
        end)
    end)
end

-- ========== AUTO CLICK ==========
local function hasSwordEquipped()
    if not player.Character then return false end
    for _, t in pairs(player.Character:GetChildren()) do
        if t:IsA("Tool") then
            local n = t.Name:lower()
            if n:find("sword") or n:find("katana") or n:find("blade") or n:find("cutlass") then return true end
        end
    end
    return false
end
local function startAutoClick()
    if autoClickConnection then autoClickConnection:Disconnect() end
    autoClickConnection = RunService.Heartbeat:Connect(function()
        if not autoClickEnabled then return end
        if hasSwordEquipped() then
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                task.wait(0.01)
                vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
            task.wait(0.1)
        end
    end)
end

-- ========== FAKE KORBLOX ==========
local function applyFakeKorblox()
    if not player.Character then return end
    local rl = player.Character:FindFirstChild("RightUpperLeg")
    local rl2 = player.Character:FindFirstChild("RightLowerLeg")
    local rf = player.Character:FindFirstChild("RightFoot")
    if rl then
        rl.Transparency = 1
        for _, c in pairs(rl:GetChildren()) do if c:IsA("SpecialMesh") then c:Destroy() end end
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshId = "rbxassetid://139607718" mesh.TextureId = "rbxassetid://139607673"
        mesh.Scale = Vector3.new(1,1,1) mesh.Parent = rl
        table.insert(korbloxMeshes, mesh)
    end
    if rl2 then rl2.Transparency = 1 end
    if rf then rf.Transparency = 1 end
    if fakeKorbloxVersion == "V2" then
        for _, n in pairs({"LeftUpperLeg","LeftLowerLeg","LeftFoot"}) do
            local p = player.Character:FindFirstChild(n) if p then p.Transparency = 1 end
        end
    end
end
local function removeFakeKorblox()
    if not player.Character then return end
    for _, m in pairs(korbloxMeshes) do pcall(function() m:Destroy() end) end
    korbloxMeshes = {}
    for _, n in pairs({"RightUpperLeg","RightLowerLeg","RightFoot","LeftUpperLeg","LeftLowerLeg","LeftFoot"}) do
        local p = player.Character:FindFirstChild(n) if p then p.Transparency = 0 end
    end
end

-- ========== FAKE HEADLESS ==========
local function applyFakeHeadless()
    if not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if head then head.Transparency = 1 local face = head:FindFirstChild("face") if face then face.Transparency = 1 end end
    if fakeHeadlessVersion == "V2" then
        hiddenHairAccessories = {}
        for _, obj in pairs(player.Character:GetChildren()) do
            if obj:IsA("Accessory") then
                local handle = obj:FindFirstChild("Handle")
                if handle then handle.Transparency = 1 table.insert(hiddenHairAccessories, handle) end
            end
        end
    end
end
local function removeFakeHeadless()
    if not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if head then head.Transparency = 0 local face = head:FindFirstChild("face") if face then face.Transparency = 0 end end
    for _, h in pairs(hiddenHairAccessories) do pcall(function() h.Transparency = 0 end) end
    hiddenHairAccessories = {}
end

-- ========== STRETCHED ==========
local function applyStretched()
    if stretchConnection then stretchConnection:Disconnect() end
    local cam = workspace.CurrentCamera
    stretchConnection = RunService.RenderStepped:Connect(function()
        if cam and stretchedEnabled then cam.CFrame = cam.CFrame * CFrame.new(0,0,0,1,0,0,0,stretchedAmount,0,0,0,1) end
    end)
end
local function removeStretched()
    if stretchConnection then stretchConnection:Disconnect() stretchConnection = nil end
end

-- ========== SPIN ==========
local function applySpinPlayer()
    if spinConnection then spinConnection:Disconnect() end
    spinConnection = RunService.Heartbeat:Connect(function()
        if not spinPlayerEnabled or not player.Character then return end
        pcall(function()
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(spinSpeed / 10), 0) end
        end)
    end)
end
local function removeSpinPlayer()
    if spinConnection then spinConnection:Disconnect() spinConnection = nil end
end

-- ========== SKIN STEALER ==========
local function saveOriginalAppearance()
    if not player.Character then return end
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum:FindFirstChildOfClass("HumanoidDescription") then
        originalAppearance = hum:FindFirstChildOfClass("HumanoidDescription"):Clone()
    end
end
local function clearStolenAccessories()
    for _, a in pairs(stolenAccessories) do pcall(function() a:Destroy() end) end stolenAccessories = {}
end
local function stealSkin(targetName)
    if not player.Character then return end
    local tp = Players:FindFirstChild(targetName)
    if not tp or not tp.Character then return end
    clearStolenAccessories()
    local myChar, tChar = player.Character, tp.Character
    pcall(function()
        local myBC = myChar:FindFirstChild("Body Colors") local tBC = tChar:FindFirstChild("Body Colors")
        if myBC and tBC then
            myBC.HeadColor=tBC.HeadColor myBC.LeftArmColor=tBC.LeftArmColor myBC.RightArmColor=tBC.RightArmColor
            myBC.LeftLegColor=tBC.LeftLegColor myBC.RightLegColor=tBC.RightLegColor myBC.TorsoColor=tBC.TorsoColor
        end
    end)
    pcall(function()
        local s=myChar:FindFirstChildOfClass("Shirt") local ts=tChar:FindFirstChildOfClass("Shirt")
        if s then s:Destroy() end
        if ts then local ns=Instance.new("Shirt") ns.ShirtTemplate=ts.ShirtTemplate ns.Parent=myChar table.insert(stolenAccessories,ns) end
    end)
    pcall(function()
        local p=myChar:FindFirstChildOfClass("Pants") local tp2=tChar:FindFirstChildOfClass("Pants")
        if p then p:Destroy() end
        if tp2 then local np=Instance.new("Pants") np.PantsTemplate=tp2.PantsTemplate np.Parent=myChar table.insert(stolenAccessories,np) end
    end)
    pcall(function()
        for _, a in pairs(myChar:GetChildren()) do if a:IsA("Accessory") then a:Destroy() end end
        for _, a in pairs(tChar:GetChildren()) do
            if a:IsA("Accessory") then local na=a:Clone() na.Parent=myChar table.insert(stolenAccessories,na) end
        end
    end)
    pcall(function()
        local mh=myChar:FindFirstChild("Head") local th=tChar:FindFirstChild("Head")
        if mh and th then
            local mf=mh:FindFirstChildOfClass("Decal") local tf=th:FindFirstChildOfClass("Decal")
            if mf and tf then mf.Texture=tf.Texture elseif tf and not mf then tf:Clone().Parent=mh end
        end
    end)
end
local function restoreOriginalSkin()
    if not player.Character then return end
    clearStolenAccessories()
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    if hum and originalAppearance then hum:ApplyDescription(originalAppearance:Clone()) end
end
if player.Character then saveOriginalAppearance() end

-- ========== REMOVE GFX ==========
local function removeParticles(model)
    for _, c in ipairs(model:GetDescendants()) do
        if c:IsA("ParticleEmitter") then c.Rate=c.Rate*0.10 c.Speed=NumberRange.new(0)
        elseif c:IsA("Trail") then c.Enabled=false
        elseif c:IsA("Smoke") then c.RiseVelocity=0 c.Opacity=0.05
        elseif c:IsA("Beam") then c.LightEmission=0.2 c.LightInfluence=0.8 c.Transparency=NumberSequence.new(0.15)
        end
    end
end
local function cleanPlayersGfx()
    for _, p in pairs(Players:GetPlayers()) do if p ~= player and p.Character then removeParticles(p.Character) end end
end
local function applyRemoveGfx()
    for _, obj in ipairs(workspace:GetDescendants()) do if obj:IsA("BasePart") or obj:IsA("Model") then removeParticles(obj) end end
    cleanPlayersGfx()
    pcall(function()
        local L = game:GetService("Lighting")
        L.GlobalShadows=false L.FogEnd=100000
        for _, e in pairs(L:GetChildren()) do
            if e:IsA("BloomEffect") or e:IsA("BlurEffect")
            or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then e:Destroy() end
        end
    end)
    gfxWorkspaceConn = workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("ParticleEmitter") then obj.Rate=obj.Rate*0.10 obj.Speed=NumberRange.new(0)
        elseif obj:IsA("Trail") then obj.Enabled=false
        elseif obj:IsA("Smoke") then obj.RiseVelocity=0 obj.Opacity=0.05
        elseif obj:IsA("Beam") then obj.LightEmission=0.2 obj.LightInfluence=0.8 obj.Transparency=NumberSequence.new(0.15)
        end
    end)
    gfxPlayersConn = Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(removeParticles) end)
    removeGfxConnection = RunService.RenderStepped:Connect(function()
        if not removeGfxEnabled then return end cleanPlayersGfx()
    end)
end
local function stopRemoveGfx()
    if gfxWorkspaceConn then gfxWorkspaceConn:Disconnect() gfxWorkspaceConn=nil end
    if gfxPlayersConn then gfxPlayersConn:Disconnect() gfxPlayersConn=nil end
    if removeGfxConnection then removeGfxConnection:Disconnect() removeGfxConnection=nil end
    pcall(function() game:GetService("Lighting").GlobalShadows=true game:GetService("Lighting").FogEnd=10000 end)
end

-- ========== FONT CHANGER ==========
local function applyFontTo(inst)
    if not (inst.ClassName=="TextLabel" or inst.ClassName=="TextButton" or inst.ClassName=="TextBox") then return end
    local original = tostring(inst.Font):split(".")[3] or "GothamSsm"
    local conn = inst:GetPropertyChangedSignal("Font"):Connect(function() pcall(function() inst.Font=Enum.Font[fontPreset] end) end)
    table.insert(updatedFonts, {inst=inst, original=original, conn=conn})
    pcall(function() inst.Font=Enum.Font[fontPreset] end)
end
local function enableFonts()
    fontConn = game.DescendantAdded:Connect(function(v) pcall(applyFontTo, v) end)
    for _, v in game:GetDescendants() do pcall(applyFontTo, v) end
end
local function disableFonts()
    pcall(function() if fontConn then fontConn:Disconnect() end end)
    for _, e in updatedFonts do pcall(function() e.conn:Disconnect() e.inst.Font=Enum.Font[e.original] or Enum.Font.GothamSsm end) end
    table.clear(updatedFonts)
end

-- ========== SANGUINE GLITCH (GhoulZCharge) ==========
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
    if lv then lv:Destroy() end
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
        if not multiCharging then
            multiCharging = true
            multiChargeStart = tick()
        end
    else
        if multiCharging then
            local totalCharge = tick() - multiChargeStart
            if totalCharge >= 3.0 then
                task.spawn(MegaBoost)
            end
            multiCharging = false
            multiChargeStart = 0
        end
    end
end)

-- =====================================================================
-- [ AUDIO ]
-- =====================================================================
local function InjectSound()
    local s = Instance.new("Sound", game:GetService("SoundService"))
    s.SoundId = "rbxassetid://7145300164"
    s.Volume = 0.5; s.Pitch = 0.8; s.PlayOnRemove = true; s:Play()
end

-- =====================================================================
-- INTRO
-- =====================================================================
local function StartIntro(callback)
    local Frame = Instance.new("Frame", ScreenGui)
    Frame.Size = UDim2.fromOffset(280, 50)
    Frame.Position = UDim2.fromScale(0.5, 0.5); Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    Frame.BackgroundColor3 = Theme.Bg_Out
    Frame.BorderSizePixel = 0

    local ScanLine = Instance.new("Frame", Frame)
    ScanLine.Size = UDim2.new(0, 2, 1, 0)
    ScanLine.BackgroundColor3 = Theme.Accent
    ScanLine.BorderSizePixel = 0

    local Text = Instance.new("TextLabel", Frame)
    Text.Size = UDim2.fromScale(1, 1)
    Text.Text = "WAITING FOR INJECTION..."; Text.Font = Theme.Font
    Text.TextColor3 = Theme.Text; Text.TextSize = 14; Text.BackgroundTransparency = 1

    InjectSound()
    TweenService:Create(ScanLine, TweenInfo.new(1, Enum.EasingStyle.Linear), {Position = UDim2.new(1, 0, 0, 0)}):Play()
    task.wait(1.2)
    InjectSound()
    Text.Text = "INJECTED_GOTCHA.EXE"; Text.TextColor3 = Theme.Accent
    task.wait(0.6)
    Frame:Destroy()
    callback()
end

-- =====================================================================
-- MENU ELITE
-- =====================================================================
local function CreateMenu()
    local Main = Instance.new("Frame", ScreenGui)
    Main.Size = UDim2.fromOffset(700, 480)
    Main.Position = UDim2.fromScale(0.5, 0.5); Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.BackgroundColor3 = Theme.Bg_Out
    Main.BorderSizePixel = 0

    local OutStroke = Instance.new("UIStroke", Main)
    OutStroke.Thickness = 1; OutStroke.Color = Color3.new(0,0,0)
    local InStroke = Instance.new("UIStroke", Main)
    InStroke.Thickness = 2; InStroke.Color = Theme.Border; InStroke.Transparency = 0.5

    local Sidebar = Instance.new("Frame", Main)
    Sidebar.Size = UDim2.new(0, 60, 1, -6)
    Sidebar.Position = UDim2.new(0, 3, 0, 3)
    Sidebar.BackgroundColor3 = Theme.Tab_Bg
    Sidebar.BorderSizePixel = 0
    Instance.new("UIStroke", Sidebar).Color = Theme.Border

    local Content = Instance.new("Frame", Main)
    Content.Size = UDim2.new(1, -72, 1, -6)
    Content.Position = UDim2.new(0, 69, 0, 3)
    Content.BackgroundColor3 = Theme.Bg_In
    Content.BorderSizePixel = 0
    Instance.new("UIStroke", Content).Color = Theme.Border

    local Pages = {}
    local TabList = Instance.new("UIListLayout", Sidebar)
    TabList.HorizontalAlignment = "Center"; TabList.Padding = UDim.new(0, 5)

    -- ── Helpers UI ──────────────────────────────────────────────────
    local function AddTab(name, iconText, isFirst)
        local Page = Instance.new("ScrollingFrame", Content)
        Page.Size = UDim2.fromScale(1, 1); Page.BackgroundTransparency = 1; Page.Visible = isFirst
        Page.ScrollBarThickness = 3; Page.CanvasSize = UDim2.new(0,0,0,0)
        Pages[name] = Page

        local Layout = Instance.new("UIListLayout", Page)
        Layout.Padding = UDim.new(0, 8)
        Layout.SortOrder = "LayoutOrder"
        Layout.HorizontalAlignment = "Left"
        Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Page.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 10)
        end)
        Instance.new("UIPadding", Page).PaddingLeft = UDim.new(0, 10)

        local Btn = Instance.new("TextButton", Sidebar)
        Btn.Size = UDim2.fromOffset(50, 50)
        Btn.BackgroundColor3 = Color3.new(1,1,1); Btn.BackgroundTransparency = 0.98
        Btn.Text = iconText .. "\n" .. name; Btn.Font = Theme.Font
        Btn.TextSize = 11; Btn.TextColor3 = isFirst and Theme.Accent or Theme.Text
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 5)

        Btn.MouseButton1Click:Connect(function()
            for _, p in pairs(Pages) do p.Visible = false end
            for _, b in pairs(Sidebar:GetChildren()) do
                if b:IsA("TextButton") then b.TextColor3 = Theme.Text end
            end
            Page.Visible = true; Btn.TextColor3 = Theme.Accent
        end)
        return Page
    end

    local function AddSection(page, title)
        local lbl = Instance.new("TextLabel", page)
        lbl.Size = UDim2.new(1, -10, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.Text = "── " .. title:upper() .. " ──"
        lbl.Font = Theme.Font; lbl.TextSize = 11
        lbl.TextColor3 = Theme.Accent; lbl.TextXAlignment = "Left"
    end

    local function AddToggle(page, title, default, callback)
        local row = Instance.new("Frame", page)
        row.Size = UDim2.new(1, -10, 0, 26)
        row.BackgroundColor3 = Theme.Tab_Bg
        row.BorderSizePixel = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
        Instance.new("UIStroke", row).Color = Theme.Border

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(0.75, 0, 1, 0)
        lbl.Position = UDim2.fromOffset(8, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = title; lbl.Font = Theme.Font; lbl.TextSize = 12
        lbl.TextColor3 = Theme.Text; lbl.TextXAlignment = "Left"

        local state = default
        local dot = Instance.new("TextLabel", row)
        dot.Size = UDim2.fromOffset(12, 12)
        dot.Position = UDim2.new(1, -20, 0.5, -6)
        dot.BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(80,80,80)
        dot.Text = ""; dot.BorderSizePixel = 0
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        row.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                state = not state
                dot.BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(80,80,80)
                callback(state)
            end
        end)
    end

    local function AddSlider(page, title, default, min, max, callback)
        local row = Instance.new("Frame", page)
        row.Size = UDim2.new(1, -10, 0, 40)
        row.BackgroundColor3 = Theme.Tab_Bg
        row.BorderSizePixel = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
        Instance.new("UIStroke", row).Color = Theme.Border

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(0.7, 0, 0, 18)
        lbl.Position = UDim2.fromOffset(8, 2)
        lbl.BackgroundTransparency = 1
        lbl.Text = title; lbl.Font = Theme.Font; lbl.TextSize = 12
        lbl.TextColor3 = Theme.Text; lbl.TextXAlignment = "Left"

        local valLbl = Instance.new("TextLabel", row)
        valLbl.Size = UDim2.new(0.3, -8, 0, 18)
        valLbl.Position = UDim2.new(0.7, 0, 0, 2)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(default); valLbl.Font = Theme.Font; valLbl.TextSize = 12
        valLbl.TextColor3 = Theme.Accent; valLbl.TextXAlignment = "Right"

        local track = Instance.new("Frame", row)
        track.Size = UDim2.new(1, -16, 0, 4)
        track.Position = UDim2.new(0, 8, 1, -10)
        track.BackgroundColor3 = Theme.Border; track.BorderSizePixel = 0
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame", track)
        fill.Size = UDim2.new((default - min)/(max - min), 0, 1, 0)
        fill.BackgroundColor3 = Theme.Accent; fill.BorderSizePixel = 0
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local dragging = false
        local function update(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + rel * (max - min))
            fill.Size = UDim2.new(rel, 0, 1, 0)
            valLbl.Text = tostring(val)
            callback(val)
        end
        track.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true update(i.Position.X) end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then update(i.Position.X) end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
    end

    local function AddDropdown(page, title, values, default, callback)
        local row = Instance.new("Frame", page)
        row.Size = UDim2.new(1, -10, 0, 26)
        row.BackgroundColor3 = Theme.Tab_Bg
        row.BorderSizePixel = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
        Instance.new("UIStroke", row).Color = Theme.Border

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(0.55, 0, 1, 0)
        lbl.Position = UDim2.fromOffset(8, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = title; lbl.Font = Theme.Font; lbl.TextSize = 12
        lbl.TextColor3 = Theme.Text; lbl.TextXAlignment = "Left"

        local sel = Instance.new("TextButton", row)
        sel.Size = UDim2.new(0.4, -8, 0.8, 0)
        sel.Position = UDim2.new(0.58, 0, 0.1, 0)
        sel.BackgroundColor3 = Theme.Bg_Out
        sel.Text = values[default] or values[1]; sel.Font = Theme.Font; sel.TextSize = 11
        sel.TextColor3 = Theme.Accent; sel.BorderSizePixel = 0
        Instance.new("UICorner", sel).CornerRadius = UDim.new(0, 3)

        local idx = default
        sel.MouseButton1Click:Connect(function()
            idx = (idx % #values) + 1
            sel.Text = values[idx]
            callback(values[idx])
        end)
    end

    local function AddButton(page, title, callback)
        local btn = Instance.new("TextButton", page)
        btn.Size = UDim2.new(1, -10, 0, 26)
        btn.BackgroundColor3 = Theme.Accent
        btn.Text = title; btn.Font = Theme.Font; btn.TextSize = 12
        btn.TextColor3 = Theme.Bg_Out; btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(callback)
    end

    -- ── TABS ────────────────────────────────────────────────────────
    local pageAim     = AddTab("AIM",  "AIM", true)
    local pageMacro   = AddTab("MACRO","MCR", false)
    local pageGlitch  = AddTab("GLCH", "GLT", false)
    local pageVisuals = AddTab("VIS",  "VIS", false)
    local pageFonts   = AddTab("FONT", "FNT", false)

    -- ── AIM (Main) ──────────────────────────────────────────────────
    AddSection(pageAim, "Combat")
    AddToggle(pageAim, "Hitbox Expander", false, function(state)
        hitboxEnabled = state
        if state then
            for _, p in pairs(Players:GetPlayers()) do if p ~= player and p.Character then createInvisibleHitbox(p.Character) end end
        else
            for _, p in pairs(Players:GetPlayers()) do if p ~= player then removeHitbox(p.Character) end end
        end
    end)
    AddSlider(pageAim, "Hitbox Size", 20, 5, 50, function(v)
        hitboxSize = v
        if hitboxEnabled then
            for _, p in pairs(Players:GetPlayers()) do if p ~= player and p.Character then createInvisibleHitbox(p.Character) end end
        end
    end)
    AddToggle(pageAim, "No Animation", false, function(state)
        noAnimationEnabled = state
        if state then disableAllAnimations()
        else if animationConnection then animationConnection:Disconnect() animationConnection = nil end end
    end)
    AddToggle(pageAim, "Auto-Click Sword", false, function(state)
        autoClickEnabled = state
        if state then startAutoClick()
        else if autoClickConnection then autoClickConnection:Disconnect() autoClickConnection = nil end end
    end)
    AddSection(pageAim, "Utility")
    AddToggle(pageAim, "Remove GFX : FPS", false, function(state)
        removeGfxEnabled = state
        if state then applyRemoveGfx() else stopRemoveGfx() end
    end)

    -- ── MACRO ───────────────────────────────────────────────────────
    AddSection(pageMacro, "Soru & Utility")
    AddToggle(pageMacro, "Soru Auto Aim", true, function(state)
        soruAutoAimEnabled = state
        getgenv().SoruAutoAim = state
    end)

    -- ── GLITCH ──────────────────────────────────────────────────────
    AddSection(pageGlitch, "Sanguine Glitch")
    AddToggle(pageGlitch, "Sanguine Glitch (Auto GhoulZ)", false, function(state)
        multiEnabled = state
        if not state then multiCharging = false multiChargeStart = 0 end
    end)
    AddSlider(pageGlitch, "Vitesse Propulsion", 1000, 100, 5000, function(v) multiPower = v end)

    -- ── VISUALS ─────────────────────────────────────────────────────
    AddSection(pageVisuals, "Skin")
    local playerNames = {"None"}
    for _, p in pairs(Players:GetPlayers()) do if p ~= player then table.insert(playerNames, p.Name) end end
    AddDropdown(pageVisuals, "Skin Stealer Target", playerNames, 1, function(v)
        targetPlayerName = v
        if skinStealerEnabled and v ~= "None" then stealSkin(v) end
    end)
    AddToggle(pageVisuals, "Activate Skin Stealer", false, function(state)
        skinStealerEnabled = state
        if state and targetPlayerName ~= "" and targetPlayerName ~= "None" then stealSkin(targetPlayerName)
        elseif not state then restoreOriginalSkin() end
    end)

    AddSection(pageVisuals, "Fake Items")
    AddDropdown(pageVisuals, "Fake Korblox Version", {"V1","V2"}, 1, function(v)
        fakeKorbloxVersion = v
        if fakeKorbloxEnabled then removeFakeKorblox() applyFakeKorblox() end
    end)
    AddToggle(pageVisuals, "Fake Korblox", false, function(state)
        fakeKorbloxEnabled = state
        if state then applyFakeKorblox() else removeFakeKorblox() end
    end)
    AddDropdown(pageVisuals, "Fake Headless Version", {"V1","V2"}, 1, function(v)
        fakeHeadlessVersion = v
        if fakeHeadlessEnabled then removeFakeHeadless() applyFakeHeadless() end
    end)
    AddToggle(pageVisuals, "Fake Headless", false, function(state)
        fakeHeadlessEnabled = state
        if state then applyFakeHeadless() else removeFakeHeadless() end
    end)

    AddSection(pageVisuals, "Effects")
    AddToggle(pageVisuals, "Spin Player", false, function(state)
        spinPlayerEnabled = state
        if state then applySpinPlayer() else removeSpinPlayer() end
    end)
    AddSlider(pageVisuals, "Spin Speed", 50, 10, 100, function(v)
        spinSpeed = v
        if spinPlayerEnabled then applySpinPlayer() end
    end)
    AddToggle(pageVisuals, "Stretched Screen", false, function(state)
        stretchedEnabled = state
        if state then applyStretched() else removeStretched() end
    end)
    AddSlider(pageVisuals, "Stretch Amount", 65, 50, 100, function(v)
        stretchedAmount = v / 100
        if stretchedEnabled then applyStretched() end
    end)

    -- ── FONTS ───────────────────────────────────────────────────────
    AddSection(pageFonts, "Font Changer")
    local fontList = {}
    for _, v in Enum.Font:GetEnumItems() do table.insert(fontList, tostring(v):split(".")[3]) end
    AddDropdown(pageFonts, "Font Style", fontList, 1, function(v)
        fontPreset = v
        if fontChangerEnabled then disableFonts() enableFonts() end
    end)
    AddToggle(pageFonts, "Font Changer", false, function(state)
        fontChangerEnabled = state
        if state then enableFonts() else disableFonts() end
    end)
    AddButton(pageFonts, "Reset All Features", function()
        stopRemoveGfx() removeFakeKorblox() removeFakeHeadless() removeSpinPlayer() removeStretched() disableFonts() restoreOriginalSkin()
        if animationConnection then animationConnection:Disconnect() animationConnection=nil end
        if autoClickConnection then autoClickConnection:Disconnect() autoClickConnection=nil end
        hitboxEnabled=false noAnimationEnabled=false autoClickEnabled=false
        soruAutoAimEnabled=true getgenv().SoruAutoAim=true
        removeGfxEnabled=false fakeKorbloxEnabled=false
        fakeHeadlessEnabled=false spinPlayerEnabled=false stretchedEnabled=false
        fontChangerEnabled=false skinStealerEnabled=false
        for _, p in pairs(Players:GetPlayers()) do if p ~= player then removeHitbox(p.Character) end end
    end)

    -- ── DRAG ────────────────────────────────────────────────────────
    local dragging, dragStart, startPos
    Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = Main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            TweenService:Create(Main, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
                Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            }):Play()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

-- =====================================================================
-- INIT
-- =====================================================================
for _, p in pairs(Players:GetPlayers()) do setupPlayer(p) end
Players.PlayerAdded:Connect(setupPlayer)

player.CharacterAdded:Connect(function(character)
    character:WaitForChild("HumanoidRootPart", 10)
    character:WaitForChild("Humanoid", 10)
    task.wait(1)
    saveOriginalAppearance()
    if fakeKorbloxEnabled then applyFakeKorblox() end
    if fakeHeadlessEnabled then applyFakeHeadless() end
    if stretchedEnabled then applyStretched() end
    if spinPlayerEnabled then applySpinPlayer() end
    if skinStealerEnabled and targetPlayerName ~= "" and targetPlayerName ~= "None" then
        task.wait(2) stealSkin(targetPlayerName)
    end
end)

StartIntro(CreateMenu)

print("✅ GOTCHA.EXE ELITE | By HimselfZen")

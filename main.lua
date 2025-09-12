local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players        = game:GetService("Players")
local UIS            = game:GetService("UserInputService")
local RunService     = game:GetService("RunService")
local LP             = Players.LocalPlayer

local CFG = {
    walk       = 16,
    jump       = 50,
    fly        = false,
    flySpeed   = 20,
    antiFall   = true,
    flyKey     = Enum.KeyCode.F, -- toggle Fly
    uiToggle   = Enum.KeyCode.K, -- toggle UI Rayfield
}

local function getChar()
    return LP.Character or LP.CharacterAdded:Wait()
end

local function getHumanoid(char)
    char = char or getChar()
    return char:FindFirstChildOfClass("Humanoid")
        or char:FindFirstChild("Humanoid")
        or char:FindFirstChildWhichIsA("Humanoid", true)
end

local function getRoot(char)
    if not char then return nil end
    
    -- coba cari root langsung
    local root = char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("LowerTorso")
        or char:FindFirstChild("Torso")

    -- kalau belum ketemu, tunggu sebentar (max 5 detik)
    if not root then
        root = char:WaitForChild("HumanoidRootPart", 5)
            or char:FindFirstChild("LowerTorso")
            or char:FindFirstChild("Torso")
    end

    -- fallback terakhir: ambil BasePart apapun
    return root or char:FindFirstChildWhichIsA("BasePart")
end

local function applyMovement()
    local hum = getHumanoid()
    if hum then
        hum.UseJumpPower = true
        hum.WalkSpeed    = CFG.walk
        hum.JumpPower    = CFG.jump
    end
end

-- ====== Walk Speed ======
local walkSpeedValue = CFG.walk
local walkSpeedEnabled = false

-- ====== Infinite Jump ======
local InfJump = { enabled = false, conns = {} }

local function ij_unbind()
    for _,c in ipairs(InfJump.conns) do
        pcall(function() c:Disconnect() end)
    end
    InfJump.conns = {}
end

local function ij_doJump()
    local hum = getHumanoid()
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        hum.Jump = true
    end
end

local function ij_bind()
    table.insert(InfJump.conns, UIS.JumpRequest:Connect(function() ij_doJump() end))
    table.insert(InfJump.conns, UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Space then
            ij_doJump()
        end
    end))
    table.insert(InfJump.conns, LP.CharacterAdded:Connect(function()
        task.wait(0.2)
        if InfJump.enabled then
            ij_unbind()
            ij_bind()
        end
    end))
end

local function setInfiniteJump(on)
    if on == InfJump.enabled then return end
    InfJump.enabled = on
    ij_unbind()
    if on then ij_bind() end
    pcall(function()
        Rayfield:Notify({
            Title = "Infinite Jump",
            Content = on and "Enabled" or "Disabled",
            Duration = 1.25
        })
    end)
end


-- ====== Fly System ======
local Fly = {
    enabled       = false,
    speed         = CFG.flySpeed,
    verticalSpeed = CFG.flySpeed,
    conns         = {},
    bodyGyro      = nil,
    bodyVel       = nil,
    ascend        = false,
    descend       = false,
    lastJumpTime  = 0,
    dtapWindow    = 0.25,
    pulseTime     = 0.45
}

local function fly_unbind()
    for _, c in ipairs(Fly.conns) do
        pcall(function() c:Disconnect() end)
    end
    Fly.conns = {}
    if Fly.bodyGyro then Fly.bodyGyro:Destroy() end
    if Fly.bodyVel  then Fly.bodyVel:Destroy()  end
    Fly.bodyGyro, Fly.bodyVel = nil, nil
    Fly.ascend, Fly.descend = false, false
end

local function fly_bind()
    local char = getChar()
    local root = getRoot(char)
    if not root then return end

    Fly.bodyGyro = Instance.new("BodyGyro")
    Fly.bodyGyro.P = 9e4
    Fly.bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    Fly.bodyGyro.CFrame = root.CFrame
    Fly.bodyGyro.Parent = root

    Fly.bodyVel = Instance.new("BodyVelocity")
    Fly.bodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    Fly.bodyVel.Velocity = Vector3.zero
    Fly.bodyVel.Parent = root

    table.insert(Fly.conns, RunService.RenderStepped:Connect(function()
        local hum = getHumanoid()
        local r = getRoot()
        if not hum or not r or not Fly.bodyGyro or not Fly.bodyVel then return end

        local horizontal = hum.MoveDirection * Fly.speed
        local vertical = Vector3.zero

        if Fly.ascend then
            vertical = Vector3.new(0,  Fly.verticalSpeed, 0)
        elseif Fly.descend then
            vertical = Vector3.new(0, -Fly.verticalSpeed, 0)
        end

        local cam = workspace.CurrentCamera
        if cam then Fly.bodyGyro.CFrame = cam.CFrame end

        local vel = horizontal + vertical

        if CFG.antiFall and not Fly.ascend and not Fly.descend and horizontal.Magnitude < 1e-3 then
            vel = Vector3.new(0, 0.05, 0) -- biar ga jatuh
        end

        Fly.bodyVel.Velocity = vel
    end))

    local function handleJumpTap()
        local t = time() -- lebih aman daripada os.clock
        if (t - Fly.lastJumpTime) <= Fly.dtapWindow then
            Fly.lastJumpTime = 0
            Fly.ascend  = false
            Fly.descend = true
            task.delay(Fly.pulseTime, function()
                if Fly.descend then
                    Fly.descend = false
                end
            end)
            return
        end

        Fly.lastJumpTime = t
        Fly.descend = false
        Fly.ascend  = true
        task.delay(Fly.pulseTime, function()
            if Fly.ascend then
                Fly.ascend = false
            end
        end)
    end

    table.insert(Fly.conns, UIS.JumpRequest:Connect(function()
        if Fly.enabled then handleJumpTap() end
    end))

    table.insert(Fly.conns, LP.CharacterAdded:Connect(function()
        if Fly.enabled then
            task.wait(0.2)
            fly_unbind()
            fly_bind()
        end
    end))
end

function setFly(on)
    if on == Fly.enabled then return end
    Fly.enabled = on
    fly_unbind()
    if on then fly_bind() end
    pcall(function()
        Rayfield:Notify({
            Title = "Fly",
            Content = on and "Enabled" or "Disabled",
            Duration = 1.25
        })
    end)
end

-- ====== God Mode dengan Damage Patch ======
local God = {
    enabled = false,
    conns = {},
    maxHP = 9e9,
    hooks = {}
}

local function gm_disconnect()
    for _, c in ipairs(God.conns) do pcall(function() c:Disconnect() end) end
    God.conns = {}
    God.hooks = {}
end

local function gm_patchHumanoid(hum)
    if not hum then return end

    pcall(function()
        hum.BreakJointsOnDeath = false
        hum.MaxHealth = God.maxHP
        hum.Health = God.maxHP
    end)

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end)

    if hum.TakeDamage and not God.hooks["TakeDamage"] then
        pcall(function()
            God.hooks["TakeDamage"] = hookfunction(hum.TakeDamage, function(...)
                if God.enabled then
                    return
                end
                return God.hooks["TakeDamage"](...)
            end)
        end)
    end

    table.insert(God.conns, hum.StateChanged:Connect(function(_, new)
        if God.enabled and new == Enum.HumanoidStateType.Dead then
            task.defer(function()
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                    hum.Health = God.maxHP
                end)
            end)
        end
    end))

    table.insert(God.conns, hum.HealthChanged:Connect(function(hp)
        if God.enabled and hp < God.maxHP then
            pcall(function()
                hum.MaxHealth = God.maxHP
                hum.Health = God.maxHP
            end)
        end
    end))
end

local function gm_bind()
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    gm_patchHumanoid(hum)

    table.insert(God.conns, LP.CharacterAdded:Connect(function(nc)
        gm_disconnect()
        if God.enabled then
            task.wait(0.2)
            local nh = nc:FindFirstChildOfClass("Humanoid") or nc:WaitForChild("Humanoid", 5)
            gm_patchHumanoid(nh)
        end
    end))
end

function setGodMode(on, hideHealthBar)
    if on == God.enabled then return end
    God.enabled = on
    gm_disconnect()

    pcall(function()
        game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Health, not hideHealthBar)
    end)

    if on then
        gm_bind()
        Rayfield:Notify({ Title="God Mode", Content="Enabled", Duration=1.25 })
    else
        Rayfield:Notify({ Title="God Mode", Content="Disabled", Duration=1.25 })
    end
end

-- ====== Show Coordinates ======
local coordGUI, coordFrame, coordLabel, copyButton
local coordConn

function setShowCoordinates(v)
    if v then
        -- kalau sudah ada, jangan buat ulang
        if coordGUI then 
            coordGUI.Enabled = true 
            return 
        end

        -- buat GUI baru
        coordGUI = Instance.new("ScreenGui")
        coordGUI.Name = "CoordGUI"
        coordGUI.ResetOnSpawn = false
        coordGUI.Parent = LP:WaitForChild("PlayerGui")

        coordFrame = Instance.new("Frame")
        coordFrame.Size = UDim2.new(0, 250, 0, 100)
        coordFrame.Position = UDim2.new(0, 20, 0, 100)
        coordFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        coordFrame.BackgroundTransparency = 0.2
        coordFrame.Parent = coordGUI

        coordLabel = Instance.new("TextLabel")
        coordLabel.Size = UDim2.new(1, -20, 0, 50)
        coordLabel.Position = UDim2.new(0, 10, 0, 10)
        coordLabel.BackgroundTransparency = 1
        coordLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        coordLabel.Font = Enum.Font.SourceSans
        coordLabel.TextSize = 20
        coordLabel.Text = "Koordinat: "
        coordLabel.TextXAlignment = Enum.TextXAlignment.Left
        coordLabel.Parent = coordFrame

        copyButton = Instance.new("TextButton")
        copyButton.Size = UDim2.new(0, 80, 0, 30)
        copyButton.Position = UDim2.new(0, 10, 0, 60)
        copyButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        copyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        copyButton.Font = Enum.Font.SourceSansBold
        copyButton.TextSize = 18
        copyButton.Text = "Copy"
        copyButton.Parent = coordFrame

        -- update label setiap frame
        coordConn = RunService.RenderStepped:Connect(function()
            local char = getChar()
            local root = getRoot(char)
            if root and coordLabel then
                local pos = root.Position
                coordLabel.Text = string.format("Koordinat: (%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z)
            end
        end)

        -- fungsi copy
        copyButton.MouseButton1Click:Connect(function()
            local char = getChar()
            local root = getRoot(char)
            if root then
                local pos = root.Position
                local coordString = string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
                if setclipboard then
                    setclipboard(coordString)
                    Rayfield:Notify({
                        Title = "Koordinat",
                        Content = "Berhasil dicopy: " .. coordString,
                        Duration = 1.25
                    })
                end
            end
        end)
    else
        if coordGUI then coordGUI.Enabled = false end
        if coordConn then coordConn:Disconnect() coordConn = nil end
    end
end

-- ===== Freecam =====
local Freecam = { enabled = false, conns = {}, speed = 1 }
local fcBodyGyro, fcBodyVel
local fcKeys = { forward = false, backward = false, left = false, right = false, up = false, down = false }
local fcSpeedSlider
local fcSpeed = 10
local fcSpeedInc = 5
local fcSpeedMin = 5
local fcSpeedMax = 100
local fcSpeedDefault = 10
local fcSpeedShiftMul = 3
local fcSpeedCtrlMul  = 0.33
local fcSpeedAltMul   = 0.5
local fcShiftDown = false
local fcCtrlDown  = false
local fcAltDown   = false
local function fc_unbind()
    for _, c in ipairs(Freecam.conns) do
        pcall(function() c:Disconnect() end)
    end
    Freecam.conns = {}
    if fcBodyGyro then fcBodyGyro:Destroy() end
    if fcBodyVel  then fcBodyVel:Destroy()  end
    fcBodyGyro, fcBodyVel = nil, nil
    fcKeys = { forward = false, backward = false, left = false, right = false, up = false, down = false }
    fcShiftDown, fcCtrlDown, fcAltDown = false, false, false
end
local function fc_bind()
    local char = getChar()
    local root = getRoot(char)
    if not root then return end

    fcBodyGyro = Instance.new("BodyGyro")
    fcBodyGyro.P = 9e4
    fcBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    fcBodyGyro.CFrame = root.CFrame
    fcBodyGyro.Parent = root

    fcBodyVel = Instance.new("BodyVelocity")
    fcBodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    fcBodyVel.Velocity = Vector3.zero
    fcBodyVel.Parent = root

    table.insert(Freecam.conns, RunService.RenderStepped:Connect(function()
        local hum = getHumanoid()
        local r = getRoot()
        if not hum or not r or not fcBodyGyro or not fcBodyVel then return end

        local cam = workspace.CurrentCamera
        if cam then fcBodyGyro.CFrame = cam.CFrame end

        local speedMul = 1
        if fcShiftDown then
            speedMul = speedMul * fcSpeedShiftMul
        end
        if fcCtrlDown then
            speedMul = speedMul * fcSpeedCtrlMul
        end
        if fcAltDown then
            speedMul = speedMul * fcSpeedAltMul
        end

        local speed = fcSpeed * speedMul

        local forwardVec = (cam and cam.CFrame.LookVector or Vector3.new(0,0,-1))
        forwardVec = Vector3.new(forwardVec.X, 0, forwardVec.Z)
        if forwardVec.Magnitude > 0 then
            forwardVec = forwardVec.Unit
        else
            forwardVec = Vector3.new(0,0,-1)
        end

        local rightVec = (cam and cam.CFrame.RightVector or Vector3.new(1,0,0))
        rightVec = Vector3.new(rightVec.X, 0, rightVec.Z)
        if rightVec.Magnitude > 0 then
            rightVec = rightVec.Unit
        else
            rightVec = Vector3.new(1,0,0)
        end

        local horizontal = Vector3.zero
        if fcKeys.forward   then horizontal = horizontal + forwardVec end
        if fcKeys.backward  then horizontal = horizontal - forwardVec end
        if fcKeys.right     then horizontal = horizontal + rightVec   end
        if fcKeys.left      then horizontal = horizontal - rightVec   end
        horizontal = (horizontal.Magnitude > 0) and horizontal.Unit * speed or Vector3.zero
        local vertical = Vector3.zero
        if fcKeys.up        then vertical = vertical + Vector3.new(0, 1, 0) end
        if fcKeys.down      then vertical = vertical - Vector3.new(0, 1, 0) end
        vertical = (vertical.Magnitude > 0) and vertical.Unit * speed or Vector3.zero
        local vel = horizontal + vertical
        fcBodyVel.Velocity = vel
    end))
    table.insert(Freecam.conns, UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.W then
            fcKeys.forward = true
        elseif input.KeyCode == Enum.KeyCode.S then
            fcKeys.backward = true
        elseif input.KeyCode == Enum.KeyCode.A then
            fcKeys.left = true
        elseif input.KeyCode == Enum.KeyCode.D then
            fcKeys.right = true
        elseif input.KeyCode == Enum.KeyCode.E then
            fcKeys.up = true
        elseif input.KeyCode == Enum.KeyCode.Q then
            fcKeys.down = true
        elseif input.KeyCode == Enum.KeyCode.LeftShift then
            fcShiftDown = true
        elseif input.KeyCode == Enum.KeyCode.LeftControl then
            fcCtrlDown = true
        elseif input.KeyCode == Enum.KeyCode.LeftAlt then
            fcAltDown = true
        end
    end))
    table.insert(Freecam.conns, UIS.InputEnded:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.W then
            fcKeys.forward = false
        elseif input.KeyCode == Enum.KeyCode.S then
            fcKeys.backward = false
        elseif input.KeyCode == Enum.KeyCode.A then
            fcKeys.left = false
        elseif input.KeyCode == Enum.KeyCode.D then
            fcKeys.right = false
        elseif input.KeyCode == Enum.KeyCode.E then
            fcKeys.up = false
        elseif input.KeyCode == Enum.KeyCode.Q then
            fcKeys.down = false
        elseif input.KeyCode == Enum.KeyCode.LeftShift then
            fcShiftDown = false
        elseif input.KeyCode == Enum.KeyCode.LeftControl then
            fcCtrlDown = false
        elseif input.KeyCode == Enum.KeyCode.LeftAlt then
            fcAltDown = false
        end
    end))
    table.insert(Freecam.conns, LP.CharacterAdded:Connect(function()
        if Freecam.enabled then
            task.wait(0.2)
            fc_unbind()
            fc_bind()
        end
    end))
end
function setFreecam(on)
    if on == Freecam.enabled then return end
    Freecam.enabled = on
    fc_unbind()
    if on then fc_bind() end
    pcall(function()
        Rayfield:Notify({
            Title = "Freecam",
            Content = on and "Enabled" or "Disabled",
            Duration = 1.25
        })
    end)
end

-- util teleport aman
local function tpTo(v3)
    local plr  = game.Players.LocalPlayer
    local char = plr.Character or plr.CharacterAdded:Wait()
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = getRoot(char)
    if not (hum and root) then return end

    pcall(function() hum.Sit = false end)
    root.CFrame = CFrame.new(v3 + Vector3.new(0, 5, 0))
end

-- teleport ke player
local function tpToPlayer(target)
    if not target or target == LP then return end
    local char = target.Character or target.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if root then
        tpTo(root.Position)
    else
        Rayfield:Notify({
            Title = "Teleport",
            Content = "Root " .. target.Name .. " tidak ditemukan.",
            Duration = 1.5
        })
    end
end


-- === koordinat Puncak ===
local POS_AKHIR_HOREG = Vector3.new(-1068.40857, 1044.99792, 487.82538)
local PUNCAK_HOREG    = Vector3.new(-1682.80188, 1081.27466, 522.91455)
local POS_AKHIR_ATIN = Vector3.new(623.3, 1798.3, 3433.2)
local PUNCAK_ATIN = Vector3.new(757.7, 2084.4, 3811.5)
local PUNCAK_LEMBAYANA = Vector3.new(-23468.3, 6334.9, -6930.8)
local PUNCAK_SIBUATAN = Vector3.new(5137, 7943, 2510)
local PUNCAK_SAKAHAYANG = Vector3.new(-984, 3120, 593)
local PUNCAK_YAREU = Vector3.new(-918, 762.5, 1925.5)
local PUNCAK_HAUK = Vector3.new(-2926.6, 1404.5, -359.5)
local PUNCAK_GALUNGGUNG = Vector3.new(-1241.5, 444.8, -3335.1)

-- ====== Windows ======
local Window = Rayfield:CreateWindow({
   Name = "JAWIR ACADEMY | MOUNT SC",
   Icon = 0,
   LoadingTitle = "JAWIR ACADEMY | MOUNT SC",
   LoadingSubtitle = "Made by JAWIR ACADEMY",
   ShowText = "JAWIR ACADEMY",
   Theme = "DarkBlue",
   ToggleUIKeybind = "K",
   DisableRayfieldPrompts = true,
   DisableBuildWarnings = true,
   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil,
      FileName = "JAWIR ACADEMY"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = false,
   KeySettings = {
      Title = "JAWIR ACADEMY | Key",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided",
      FileName = "Key",
      SaveKey = true,
      GrabKeyFromSite = false,
      Key = {"Hello"}
   }
})

local MainTab = Window:CreateTab("🏠 Main", nil)

local Section = MainTab:CreateSection("Walk And Jump Section")

local WalkSpeedSlider = MainTab:CreateSlider({
    Name = "Walk Speed Value",
    Range = {1, 100},
    Increment = 1,
    Suffix = "stud/s",
    CurrentValue = walkSpeedValue,
    Callback = function(v)
        walkSpeedValue = v
        if walkSpeedEnabled then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = walkSpeedValue end
        end
    end,
})

local ToggleWalkSpeed = MainTab:CreateToggle({
   Name = "Walk Speed",
   CurrentValue = false,
   Callback = function(v)
        walkSpeedEnabled = v
        local hum = getHumanoid()
        if hum then
            if v then
                hum.WalkSpeed = walkSpeedValue
            else
                hum.WalkSpeed = CFG.walk
            end
        end
   end,
})

local Toggle = MainTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Callback = function(v)
        setInfiniteJump(v)
    end,
})

local Section = MainTab:CreateSection("Fly Section")

local VerticalSlider = MainTab:CreateSlider({
    Name = "Jarak per Tap",
    Range = {1, 100},
    Increment = 1,
    Suffix = "stud/s",
    CurrentValue = Fly.verticalSpeed,
    Callback = function(v)
        Fly.verticalSpeed = v
        Rayfield:Notify({ Title = "Fly", Content = "Vertical Speed: "..tostring(v), Duration = 0.8 })
    end,
})

local PulseSlider = MainTab:CreateSlider({
    Name = "Durasi Tap",
    Range = {0.10, 1.50},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = Fly.pulseTime,
    Callback = function(v)
        Fly.pulseTime = v
        Rayfield:Notify({ Title = "Fly", Content = "Pulse Time: "..string.format("%.2f", v).."s", Duration = 0.8 })
    end,
})

local HSpeedSlider = MainTab:CreateSlider({
    Name = "Fly Speed",
    Range = {5, 100},
    Increment = 1,
    Suffix = "stud/s",
    CurrentValue = Fly.speed,
    Callback = function(v)
        Fly.speed = v
        CFG.flySpeed = v
        Rayfield:Notify({ Title = "Fly", Content = "Horizontal Speed: "..tostring(v), Duration = 0.8 })
    end,
})

local Toggle = MainTab:CreateToggle({
   Name = "Fly",
   CurrentValue = false,
   Callback = function(v)
        setFly(v)
    end,
})

local Section = MainTab:CreateSection("Cam & Coordinates Section")

local Toggle = MainTab:CreateToggle({
   Name = "Tampilkan Koordinat",
   CurrentValue = false,
   Callback = function(v)
        setShowCoordinates(v)
    end,
})

local FCSpeedSlider = MainTab:CreateSlider({
    Name = "Freecam Speed",
    Range = {fcSpeedMin, fcSpeedMax},
    Increment = 1,
    Suffix = "stud/s",
    CurrentValue = fcSpeed,
    Callback = function(v)
        fcSpeed = v
    end,
})

local Toggle = MainTab:CreateToggle({
   Name = "Freecam (WASDQE)",
   CurrentValue = false,
   Callback = function(v)
        setFreecam(v)
    end,
})

local Section = MainTab:CreateSection("Health Section")

local Toggle = MainTab:CreateToggle({
   Name = "God Mode",
   CurrentValue = false,
   Callback = function(v)
        setGodMode(v, true)
    end,
})

-- ====== Teleport Tab ======
local TeleTab = Window:CreateTab("🚀 Teleport", nil)
local Section = TeleTab:CreateSection(" Custom Teleport Section ")

-- ====== Teleport Manual XYZ ======
local tpX, tpY, tpZ = 0, 0, 0

local XInput = TeleTab:CreateInput({
    Name = "X Coordinate",
    PlaceholderText = "Masukkan X",
    RemoveTextAfterFocusLost = false,
    Callback = function(v)
        local num = tonumber(v)
        if num then tpX = num end
    end,
})

local YInput = TeleTab:CreateInput({
    Name = "Y Coordinate",
    PlaceholderText = "Masukkan Y",
    RemoveTextAfterFocusLost = false,
    Callback = function(v)
        local num = tonumber(v)
        if num then tpY = num end
    end,
})

local ZInput = TeleTab:CreateInput({
    Name = "Z Coordinate",
    PlaceholderText = "Masukkan Z",
    RemoveTextAfterFocusLost = false,
    Callback = function(v)
        local num = tonumber(v)
        if num then tpZ = num end
    end,
})

local Button = TeleTab:CreateButton({
    Name = "Teleport ke XYZ",
    Callback = function()
        if tpX and tpY and tpZ then
            tpTo(Vector3.new(tpX, tpY, tpZ))
            Rayfield:Notify({
                Title = "Teleport",
                Content = string.format("Teleport ke (%.2f, %.2f, %.2f)", tpX, tpY, tpZ),
                Duration = 1.5
            })
        else
            Rayfield:Notify({
                Title = "Teleport",
                Content = "Isi koordinat dengan benar dulu!",
                Duration = 1.5
            })
        end
    end,
})

-- ===== Teleport ke Lokasi Tertentu =====
local Section = TeleTab:CreateSection(" Mount Teleport Section ")

-- Horeg
local Button = TeleTab:CreateButton({
    Name = "Teleport Pos Akhir (Horeg)",
    Callback = function()
        tpTo(POS_AKHIR_HOREG)
    end,
})

local Button = TeleTab:CreateButton({
    Name = "Teleport Puncak (Horeg)",
    Callback = function()
        tpTo(PUNCAK_HOREG)
    end,
})

-- Atin
local Button = TeleTab:CreateButton({
    Name = "Teleport Pos Akhir (Atin)",
    Callback = function()
        tpTo(POS_AKHIR_ATIN)
    end,
})

local Button = TeleTab:CreateButton({
    Name = "Teleport Puncak (Atin)",
    Callback = function()
        tpTo(PUNCAK_ATIN)
    end,
})

-- Lokasi Lainnya
local Button = TeleTab:CreateButton({
    Name = "Teleport Puncak (Sakhayang)",
    Callback = function()
        tpTo(PUNCAK_SAKAHAYANG)
    end,
})

local Button = TeleTab:CreateButton({
    Name = "Teleport Puncak (Lembayana)",
    Callback = function()
        tpTo(PUNCAK_LEMBAYANA)
    end,
})

local Button = TeleTab:CreateButton({
    Name = "Teleport Puncak (Sibuatan)",
    Callback = function()
        tpTo(PUNCAK_SIBUATAN)
    end,
})

local Button = TeleTab:CreateButton({
    Name = "Teleport Puncak (Yareu)",
    Callback = function()
        tpTo(PUNCAK_YAREU)
    end,
})

local Button = TeleTab:CreateButton({
    Name = "Teleport Puncak (Hauk)",
    Callback = function()
        tpTo(PUNCAK_HAUK)
    end,
})

local Button = TeleTab:CreateButton({
    Name = "Teleport Puncak (Galunggung)",
    Callback = function()
        tpTo(PUNCAK_GALUNGGUNG)
    end,
})

-- ====== Players Tab ======
local PlayerTab = Window:CreateTab("👥 Players", nil)

local optionToPlayer = {}
local selectedLabel  = nil
local selectedPlayer = nil
local PlayerDropdown

-- helper ambil root
local function getRoot(char)
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
end

-- teleport ke player
local function tpToPlayer(target)
    if not target or target == LP then return end
    local char = target.Character or target.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if root then
        tpTo(root.Position)
    else
        Rayfield:Notify({
            Title = "Teleport",
            Content = "Root " .. target.Name .. " tidak ditemukan.",
            Duration = 1.5
        })
    end
end

-- bikin label untuk dropdown
local function makeLabel(p)
    if p == LP then
        return string.format("%s (You) [%d]", p.Name, p.UserId)
    else
        return string.format("%s [%d]", p.Name, p.UserId)
    end
end

-- build ulang list
local function buildOptions()
    optionToPlayer = {}
    local opts = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local label = makeLabel(p)
        optionToPlayer[label] = p
        table.insert(opts, label)
    end
    return opts
end

-- ambil player + langsung pastikan Character-nya
local function getSelected()
    if not selectedLabel then return nil end
    local p = optionToPlayer[selectedLabel]
    if not p then return nil end
    local char = p.Character or p.CharacterAdded:Wait()
    if char then
        selectedPlayer = p
        return p
    end
    return nil
end

-- rebuild dropdown (fallback kalau SetOptions gagal)
local function rebuildDropdown()
    local opts = buildOptions()
    if PlayerDropdown then
        PlayerDropdown:Destroy()
    end
    PlayerDropdown = PlayerTab:CreateDropdown({
        Name = "Pilih Player",
        Options = opts,
        CurrentOption = opts[1] or nil,
        Callback = function(label)
            if typeof(label) == "table" then label = label[1] end
            selectedLabel = label
            getSelected()
        end,
    })
end

-- coba refresh list (pakai SetOptions, fallback ke rebuild)
local function refreshDropdown()
    local opts = buildOptions()

    if not PlayerDropdown then
        rebuildDropdown()
        return
    end

    local ok = pcall(function()
        PlayerDropdown:SetOptions(opts)
    end)

    if not ok then
        rebuildDropdown()
        return
    end

    -- pastikan CurrentOption tetap valid
    if #opts > 0 then
        if not selectedLabel or not optionToPlayer[selectedLabel] then
            selectedLabel = opts[1]
        end
        getSelected()
    else
        selectedLabel = nil
        selectedPlayer = nil
    end
end

-- buat dropdown awal
rebuildDropdown()

-- tombol refresh manual
PlayerTab:CreateButton({
    Name = "Refresh List",
    Callback = refreshDropdown,
})

-- auto refresh saat join/leave (pakai delay biar data ready)
Players.PlayerAdded:Connect(function()
    task.delay(0.2, refreshDropdown)
end)

Players.PlayerRemoving:Connect(function()
    task.delay(0.2, refreshDropdown)
end)

-- tombol teleport
PlayerTab:CreateButton({
    Name = "Teleport To Player",
    Callback = function()
        local target = getSelected()
        if not target then
            Rayfield:Notify({
                Title="Teleport",
                Content="Belum ada target player valid.",
                Duration=1.5
            })
            return
        end
        tpToPlayer(target)
        Rayfield:Notify({
            Title="Teleport",
            Content="Teleport ke "..target.Name,
            Duration=1.5
        })
    end,
})

-- tombol spectate
PlayerTab:CreateButton({
    Name = "Spectate Player",
    Callback = function()
        local target = getSelected()
        if not target then
            Rayfield:Notify({
                Title="Spectate",
                Content="Belum ada target player valid.",
                Duration=1.5
            })
            return
        end
        local char = target.Character or target.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart", 5)
        if root then
            local cam = workspace.CurrentCamera
            if cam then
                cam.CameraSubject = target.Character:FindFirstChildOfClass("Humanoid") or root
                cam.CameraType = Enum.CameraType.Custom
                Rayfield:Notify({
                    Title="Spectate",
                    Content="Sedang spectate "..target.Name,
                    Duration=1.5
                })
            end
        else
            Rayfield:Notify({
                Title="Spectate",
                Content="Root "..target.Name.." tidak ditemukan.",
                Duration=1.5
            })
        end
    end,
})

-- ====== Midnight Chasers ======
local MidnightTab = Window:CreateTab("🚗 Midnight Chasers", nil)

local Section = MidnightTab:CreateSection("Main")

-- Variabel biar gampang ON/OFF
local npcRoot = workspace:FindFirstChild("NPCVehicles")
local vehiclesFolder = npcRoot and (npcRoot:FindFirstChild("Vehicles") or npcRoot)

local ghostConn, enforceConn

local function ghostifyInstance(inst)
    for _, obj in ipairs(inst:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.LocalTransparencyModifier = 1
            obj.Transparency = 1
            obj.CanCollide = false
            obj.CanTouch = false
            obj.CanQuery = false
            obj.Massless = true
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("Highlight") then
            obj.Enabled = false
        elseif obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("ParticleEmitter") then
            obj.Enabled = false
        elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
            obj.Enabled = false
        end
    end
end

local function ghostAll()
    if not vehiclesFolder then return end
    ghostifyInstance(vehiclesFolder)
    ghostConn = vehiclesFolder.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") then
            obj.LocalTransparencyModifier = 1
            obj.Transparency = 1
            obj.CanCollide = false
            obj.CanTouch = false
            obj.CanQuery = false
            obj.Massless = true
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("Highlight") then
            obj.Enabled = false
        elseif obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("ParticleEmitter") then
            obj.Enabled = false
        elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
            obj.Enabled = false
        end
    end)

    enforceConn = RunService.Heartbeat:Connect(function()
        for _, part in ipairs(vehiclesFolder:GetDescendants()) do
            if part:IsA("BasePart") then
                part.LocalTransparencyModifier = 1
                part.Transparency = 1
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
                part.Massless = true
            end
        end
    end)
end

local function unghostAll()
    if ghostConn then ghostConn:Disconnect() ghostConn = nil end
    if enforceConn then enforceConn:Disconnect() enforceConn = nil end
    if not vehiclesFolder then return end
    for _, obj in ipairs(vehiclesFolder:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.LocalTransparencyModifier = 0
            obj.Transparency = 0
            obj.CanCollide = true
            obj.CanTouch = true
            obj.CanQuery = true
            obj.Massless = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 0
        elseif obj:IsA("Highlight") then
            obj.Enabled = true
        elseif obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("ParticleEmitter") then
            obj.Enabled = true
        elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
            obj.Enabled = true
        end
    end
end

local Toggle = MidnightTab:CreateToggle({
   Name = "Hilangkan Mobil NPC",
   CurrentValue = false,
   Callback = function(v)
        if v then
            ghostAll()
            Rayfield:Notify({
                Title = "NPC Vehicles",
                Content = "Semua mobil NPC berhasil dihilangkan (ghosted).",
                Duration = 2
            })
        else
            unghostAll()
            Rayfield:Notify({
                Title = "NPC Vehicles",
                Content = "Semua mobil NPC berhasil ditampilkan kembali.",
                Duration = 2
            })
        end
    end,
})

-- ====== Variabel Car Speed ======
local carSpeedValue = 50 -- default slider
local carSpeedEnabled = false
local defaultCarSpeed = 50

-- fungsi ambil mobil player
local function getPlayerCar()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:find(LP.Name) and obj:FindFirstChildWhichIsA("VehicleSeat") then
            return obj
        end
    end
    return nil
end

-- fungsi apply speed (smooth, cek dulu biar ga bentrok)
local function applyCarSpeed()
    if not carSpeedEnabled then return end
    local car = getPlayerCar()
    if car then
        local seat = car:FindFirstChildWhichIsA("VehicleSeat")
        if seat then
            -- kalau beda baru update (biar ga spam nulis nilai yg sama -> bikin lag/patah2)
            if seat.MaxSpeed ~= carSpeedValue then
                seat.MaxSpeed = carSpeedValue
            end
        end
    end
end

-- Slider buat atur nilai speed
local CarSpeedSlider = MidnightTab:CreateSlider({
    Name = "Car Speed",
    Range = {5, 500}, -- diperbesar biar lebih fleksibel
    Increment = 1,
    Suffix = "stud/s",
    CurrentValue = carSpeedValue,
    Callback = function(v)
        carSpeedValue = v
        if carSpeedEnabled then
            applyCarSpeed()
            Rayfield:Notify({
                Title = "Car Speed",
                Content = "Kecepatan mobil diset ke " .. tostring(v),
                Duration = 1
            })
        end
    end,
})

-- Toggle buat aktif/nonaktif
local CarSpeedToggle = MidnightTab:CreateToggle({
   Name = "Car Speed Toggle",
   CurrentValue = false,
   Callback = function(v)
        carSpeedEnabled = v
        local car = getPlayerCar()
        if car then
            local seat = car:FindFirstChildWhichIsA("VehicleSeat")
            if seat then
                if v then
                    defaultCarSpeed = seat.MaxSpeed
                    seat.MaxSpeed = carSpeedValue
                    Rayfield:Notify({
                        Title = "Car Speed",
                        Content = "Custom Car Speed Aktif",
                        Duration = 1.25
                    })
                else
                    seat.MaxSpeed = defaultCarSpeed
                    Rayfield:Notify({
                        Title = "Car Speed",
                        Content = "Custom Car Speed Dimatikan",
                        Duration = 1.25
                    })
                end
            end
        else
            Rayfield:Notify({
                Title = "Car Speed",
                Content = "Mobilmu tidak ditemukan!",
                Duration = 2
            })
        end
   end,
})

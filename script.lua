--[[
    KEYLESS HUB
    Version 1.6
    Discord: https://discord.gg/VaNyVR2Zwk
    Standalone LocalScript

    AUTO SELECT BALL (BETA):  Finds the "Ball Hitbox" part for you.
    SELECT BALL:              Click SELECT, then click a ball manually.
    AUTO CONTROL ON RELEASE:  Hold + release Mouse Button 1 (anywhere on
                              screen, not on the UI) and the ball is
                              controlled automatically.
    INSTA GOAL:               When ON, hold + release Mouse Button 1 and the
                              ball shoots forward (where you're looking) at
                              high speed. The duration is editable in the
                              FORWARD TIME box (press Enter to apply).
    STOP:                     X or ESC, or the STOP button.
                              Control also stops by itself if the ball
                              gets attached (to a player/tool) or anchored.

    BODY:                     Your character is frozen in place while you
                              control the ball and released when you stop.

    CONTROLS:
        W          - Fly forward in the direction you're looking
        MOUSE      - Aim / turn (shiftlock style, mouse is locked)
        MOUSEWHEEL - Camera zoom
        (ball hovers in the air when you let go of W)

    UI:
        Drag the header to move the window.
        RightShift hides / shows the window.

    NOTE: Movement sets velocity from the client, so it only works
    when your client has network ownership of the ball.
]]

if _G.KeylessHub then return end
_G.KeylessHub = true

-- SERVICES

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-- SETTINGS

local Speed = 60
local MinSpeed, MaxSpeed, SpeedStep = 10, 250, 10

local InstaGoalSpeed = 170     -- ball speed during Insta Goal
local InstaGoalTime = 2        -- default seconds the Insta Goal push lasts (editable in the UI)
local MinDashTime, MaxDashTime = 0.1, 30

local FreezeBodyWhileControlling = true

local FlyAlongLook = true      -- true: W follows camera pitch too. false: W stays level.
local HoverGain = 20           -- how hard the ball holds its altitude
local CameraSensitivity = 0.0035
local CamDistance = 14
local MinZoom, MaxZoom = 4, 80
local StopKey = Enum.KeyCode.X
local ToggleUIKey = Enum.KeyCode.RightShift
local AutoStartWait = 2        -- seconds to wait for the ball to detach after releasing M1

-- STATE

local Alive = true

local SelectedBall = nil
local Controlling = false
local Selecting = false
local AutoControl = true
local InstaGoal = false
local AutoTracking = false
local Scanning = false
local Holding = false
local AutoStartToken = 0

local DashUntil = 0
local HoverY = 0
local Yaw, Pitch = 0, 0

local MovementConnection
local DiedConnection
local FrozenState
local Highlight

local SavedCameraSubject
local SavedCameraType
local SavedCameraCFrame
local SavedCameraFocus

local Keys = {}
local Connections = {}

local CAMERA_BIND = "KeylessHubCamera"

local function Connect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(Connections, conn)
    return conn
end

local DiscordLink = "https://discord.gg/VaNyVR2Zwk"
local IntroDone = false

-- Copies text to the clipboard when the executor supports it. Returns true on success.
local function CopyToClipboard(text)
    local setter = setclipboard or toclipboard
    if typeof(setter) ~= "function" then
        return false
    end
    return (pcall(setter, text))
end

-- COLORS

local Purple = Color3.fromRGB(145, 85, 255)
local Background = Color3.fromRGB(15, 15, 23)
local Panel = Color3.fromRGB(25, 25, 37)
local ButtonColor = Color3.fromRGB(39, 39, 54)
local HoverColor = Color3.fromRGB(57, 45, 82)
local StopColor = Color3.fromRGB(110, 45, 65)
local White = Color3.fromRGB(245, 245, 255)
local Muted = Color3.fromRGB(145, 145, 165)
local Green = Color3.fromRGB(90, 225, 145)
local Red = Color3.fromRGB(255, 100, 110)

-- GUI

local GUI = Instance.new("ScreenGui")
GUI.Name = "Keyless Hub"
GUI.ResetOnSpawn = false
GUI.IgnoreGuiInset = true
GUI.DisplayOrder = 100
GUI.Parent = Player:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(300, 496)
Main.Position = UDim2.new(0.5, -150, 0.5, -248)
Main.BackgroundColor3 = Background
Main.BorderSizePixel = 0
Main.Active = true -- sinks input so clicks on the window never reach the world
Main.Visible = false -- revealed after the intro
Main.Parent = GUI

local MainScale = Instance.new("UIScale")
MainScale.Scale = 1
MainScale.Parent = Main

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local Border = Instance.new("UIStroke")
Border.Color = Purple
Border.Thickness = 1.5
Border.Transparency = 0.25
Border.Parent = Main

-- HEADER (drag handle)

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 58)
Header.BackgroundColor3 = Panel
Header.BorderSizePixel = 0
Header.Parent = Main

Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.Position = UDim2.fromOffset(15, 7)
Title.Size = UDim2.new(1, -55, 0, 28)
Title.BackgroundTransparency = 1
Title.Text = "KEYLESS HUB"
Title.TextColor3 = White
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Position = UDim2.fromOffset(16, 34)
Subtitle.Size = UDim2.new(1, -55, 0, 14)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "BALL CONTROL  •  V1.6  •  DRAG TO MOVE"
Subtitle.TextColor3 = Purple
Subtitle.Font = Enum.Font.GothamBold
Subtitle.TextSize = 9
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

local CloseButton = Instance.new("TextButton")
CloseButton.Position = UDim2.new(1, -36, 0, 8)
CloseButton.Size = UDim2.fromOffset(26, 26)
CloseButton.BackgroundColor3 = ButtonColor
CloseButton.BorderSizePixel = 0
CloseButton.Text = "X"
CloseButton.TextColor3 = White
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 12
CloseButton.AutoButtonColor = false
CloseButton.Parent = Header

Instance.new("UICorner", CloseButton).CornerRadius = UDim.new(0, 6)

-- DRAGGING

local Dragging = false
local DragStartInput
local DragStartPos

local function ClampToScreen(x, y)
    local screen = GUI.AbsoluteSize
    local size = Main.AbsoluteSize

    local maxX = math.max(0, screen.X - size.X)
    local maxY = math.max(0, screen.Y - size.Y)

    return math.clamp(x, 0, maxX), math.clamp(y, 0, maxY)
end

local function BeginDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    Dragging = true
    DragStartInput = input.Position
    DragStartPos = Main.AbsolutePosition
end

for _, handle in ipairs({ Header, Title, Subtitle }) do
    Connect(handle.InputBegan, BeginDrag)
end

Connect(UIS.InputChanged, function(input)
    if not Dragging then return end

    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - DragStartInput
    local x, y = ClampToScreen(DragStartPos.X + delta.X, DragStartPos.Y + delta.Y)

    Main.Position = UDim2.fromOffset(x, y)
end)

Connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        Dragging = false
    end
end)

Connect(GUI:GetPropertyChangedSignal("AbsoluteSize"), function()
    local pos = Main.AbsolutePosition
    local x, y = ClampToScreen(pos.X, pos.Y)
    Main.Position = UDim2.fromOffset(x, y)
end)

-- CONTENT

local Content = Instance.new("Frame")
Content.Position = UDim2.fromOffset(14, 69)
Content.Size = UDim2.new(1, -28, 1, -80)
Content.BackgroundTransparency = 1
Content.Parent = Main

-- Buttons use an "Active" attribute so hover tweens never overwrite state colors.
local function RestColor(button)
    if button:GetAttribute("Active") then
        return button:GetAttribute("ActiveColor") or Purple
    end
    return ButtonColor
end

local function SetActive(button, active, color)
    button:SetAttribute("ActiveColor", color)
    button:SetAttribute("Active", active)
    button.BackgroundColor3 = RestColor(button)
end

local function StyleButton(button)
    button.BackgroundColor3 = ButtonColor
    button.BorderSizePixel = 0
    button.TextColor3 = White
    button.Font = Enum.Font.GothamBold
    button.AutoButtonColor = false

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

    Connect(button.MouseEnter, function()
        if button:GetAttribute("Active") then return end
        TweenService:Create(button, TweenInfo.new(.15), {
            BackgroundColor3 = HoverColor
        }):Play()
    end)

    Connect(button.MouseLeave, function()
        TweenService:Create(button, TweenInfo.new(.15), {
            BackgroundColor3 = RestColor(button)
        }):Play()
    end)
end

StyleButton(CloseButton)

local function MakeButton(name, text, y, height)
    local Button = Instance.new("TextButton")
    Button.Name = name
    Button.Position = UDim2.fromOffset(0, y)
    Button.Size = UDim2.new(1, 0, 0, height)
    Button.Text = text
    Button.TextSize = 12
    Button.Parent = Content
    StyleButton(Button)
    return Button
end

local AutoSelectButton = MakeButton("AutoSelectBall", "★   AUTO SELECT BALL (BETA)", 0, 36)
local SelectButton = MakeButton("SelectBall", "◈   SELECT BALL", 42, 36)
local StartButton = MakeButton("StartControl", "▶   START CONTROL", 84, 36)
local AutoControlButton = MakeButton("AutoControl", "⚡   AUTO CONTROL ON RELEASE: ON", 126, 36)
AutoControlButton.TextSize = 11
SetActive(AutoControlButton, true, Purple)

local InstaGoalButton = MakeButton("InstaGoal", "➤   INSTA GOAL: OFF", 168, 36)
InstaGoalButton.TextSize = 11

-- FORWARD TIME (editable)

local TimeLabel = Instance.new("TextLabel")
TimeLabel.Position = UDim2.fromOffset(0, 210)
TimeLabel.Size = UDim2.new(0.55, 0, 0, 30)
TimeLabel.BackgroundTransparency = 1
TimeLabel.Text = "FORWARD TIME (SEC)"
TimeLabel.TextColor3 = Muted
TimeLabel.Font = Enum.Font.GothamBold
TimeLabel.TextSize = 10
TimeLabel.TextXAlignment = Enum.TextXAlignment.Left
TimeLabel.Parent = Content

local TimeBox = Instance.new("TextBox")
TimeBox.Name = "ForwardTime"
TimeBox.Position = UDim2.new(0.55, 4, 0, 210)
TimeBox.Size = UDim2.new(0.45, -4, 0, 30)
TimeBox.BackgroundColor3 = ButtonColor
TimeBox.BorderSizePixel = 0
TimeBox.Text = tostring(InstaGoalTime)
TimeBox.PlaceholderText = "seconds"
TimeBox.PlaceholderColor3 = Muted
TimeBox.TextColor3 = White
TimeBox.Font = Enum.Font.GothamBold
TimeBox.TextSize = 13
TimeBox.ClearTextOnFocus = false
TimeBox.Parent = Content

Instance.new("UICorner", TimeBox).CornerRadius = UDim.new(0, 8)

local TimeStroke = Instance.new("UIStroke")
TimeStroke.Color = Purple
TimeStroke.Thickness = 1
TimeStroke.Transparency = 0.6
TimeStroke.Parent = TimeBox

-- SPEED

local SpeedTitle = Instance.new("TextLabel")
SpeedTitle.Position = UDim2.fromOffset(0, 250)
SpeedTitle.Size = UDim2.new(1, 0, 0, 18)
SpeedTitle.BackgroundTransparency = 1
SpeedTitle.Text = "MOVEMENT SPEED"
SpeedTitle.TextColor3 = Muted
SpeedTitle.Font = Enum.Font.GothamBold
SpeedTitle.TextSize = 10
SpeedTitle.TextXAlignment = Enum.TextXAlignment.Left
SpeedTitle.Parent = Content

local SpeedDown = Instance.new("TextButton")
SpeedDown.Position = UDim2.fromOffset(0, 270)
SpeedDown.Size = UDim2.new(0.3, -4, 0, 32)
SpeedDown.Text = "- SPEED"
SpeedDown.TextSize = 11
SpeedDown.Parent = Content
StyleButton(SpeedDown)

local SpeedValue = Instance.new("TextLabel")
SpeedValue.Position = UDim2.new(0.3, 0, 0, 270)
SpeedValue.Size = UDim2.new(0.4, 0, 0, 32)
SpeedValue.BackgroundTransparency = 1
SpeedValue.Text = tostring(Speed)
SpeedValue.TextColor3 = White
SpeedValue.Font = Enum.Font.GothamBold
SpeedValue.TextSize = 18
SpeedValue.Parent = Content

local SpeedUp = Instance.new("TextButton")
SpeedUp.Position = UDim2.new(0.7, 4, 0, 270)
SpeedUp.Size = UDim2.new(0.3, -4, 0, 32)
SpeedUp.Text = "+ SPEED"
SpeedUp.TextSize = 11
SpeedUp.Parent = Content
StyleButton(SpeedUp)

-- STATUS

local Status = Instance.new("TextLabel")
Status.Position = UDim2.fromOffset(0, 312)
Status.Size = UDim2.new(1, 0, 0, 19)
Status.BackgroundTransparency = 1
Status.Text = "●  NO BALL SELECTED"
Status.TextColor3 = Muted
Status.Font = Enum.Font.GothamBold
Status.TextSize = 10
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Content

local SelectedName = Instance.new("TextLabel")
SelectedName.Position = UDim2.fromOffset(0, 331)
SelectedName.Size = UDim2.new(1, 0, 0, 16)
SelectedName.BackgroundTransparency = 1
SelectedName.Text = "Selected: None"
SelectedName.TextColor3 = Muted
SelectedName.Font = Enum.Font.Gotham
SelectedName.TextSize = 10
SelectedName.TextXAlignment = Enum.TextXAlignment.Left
SelectedName.Parent = Content

local Hint = Instance.new("TextLabel")
Hint.Position = UDim2.fromOffset(0, 350)
Hint.Size = UDim2.new(1, 0, 0, 14)
Hint.BackgroundTransparency = 1
Hint.Text = "W = Move  •  Mouse = Aim  •  X / ESC = Stop"
Hint.TextColor3 = Muted
Hint.Font = Enum.Font.Gotham
Hint.TextSize = 9
Hint.TextXAlignment = Enum.TextXAlignment.Left
Hint.Parent = Content

local function SetStatus(text, color)
    Status.Text = "●  " .. text
    Status.TextColor3 = color
end

-- HIGHLIGHT

local function HighlightBall(ball)
    if Highlight then
        Highlight:Destroy()
        Highlight = nil
    end

    Highlight = Instance.new("Highlight")
    Highlight.Adornee = ball
    Highlight.FillColor = Purple
    Highlight.OutlineColor = Color3.fromRGB(210, 180, 255)
    Highlight.FillTransparency = .8
    Highlight.OutlineTransparency = 0
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Parent = GUI
end

-- VALIDATION / ATTACH DETECTION

-- True for any part that belongs to a character (players, NPCs, dummies).
local function IsCharacterPart(part)
    local current = part
    while current and current ~= workspace do
        if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
            return true
        end
        current = current.Parent
    end
    return false
end

local function IsValid()
    return SelectedBall ~= nil
        and SelectedBall.Parent ~= nil
        and SelectedBall:IsDescendantOf(workspace)
        and SelectedBall:IsA("BasePart")
end

-- Returns a status string if the ball can't be controlled right now, otherwise nil.
local function GetBlockReason(ball)
    if ball.Anchored then
        return "BALL ANCHORED"
    end

    local root = ball.AssemblyRootPart
    if root and root.Anchored then
        return "BALL ANCHORED"
    end

    if IsCharacterPart(ball) or ball:FindFirstAncestorOfClass("Tool") then
        return "BALL ATTACHED"
    end

    local ok, connected = pcall(ball.GetConnectedParts, ball, true)
    if ok then
        for _, part in ipairs(connected) do
            if part ~= ball
                and (IsCharacterPart(part) or part:FindFirstAncestorOfClass("Tool")) then
                return "BALL ATTACHED"
            end
        end
    end

    return nil
end

-- BODY FREEZE

local function FreezeBody()
    if not FreezeBodyWhileControlling then return end

    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    FrozenState = {
        Humanoid = hum,
        Root = root,
        WalkSpeed = hum.WalkSpeed,
        JumpPower = hum.JumpPower,
        JumpHeight = hum.JumpHeight,
        AutoRotate = hum.AutoRotate,
        Anchored = root.Anchored,
    }

    hum.WalkSpeed = 0
    hum.JumpPower = 0
    hum.JumpHeight = 0
    hum.AutoRotate = false

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.Anchored = true
end

local function UnfreezeBody()
    local state = FrozenState
    FrozenState = nil
    if not state then return end

    if state.Root and state.Root.Parent then
        state.Root.Anchored = state.Anchored
    end

    local hum = state.Humanoid
    if hum and hum.Parent then
        hum.WalkSpeed = state.WalkSpeed
        hum.JumpPower = state.JumpPower
        hum.JumpHeight = state.JumpHeight
        hum.AutoRotate = state.AutoRotate
    end
end

-- SELECTION

local function SelectBall(part)
    SelectedBall = part

    local label = part.Name
    if part.Parent and part.Parent ~= workspace then
        label = part.Parent.Name .. " / " .. part.Name
    end
    SelectedName.Text = "Selected: " .. label

    HighlightBall(part)
end

Connect(SelectButton.MouseButton1Click, function()
    if Controlling then return end

    Selecting = not Selecting

    SelectButton.Text = Selecting
        and "●   CLICK A BALL..."
        or "◈   SELECT BALL"

    SetActive(SelectButton, Selecting, Purple)

    if Selecting then
        SetStatus("SELECT A BALL IN THE WORLD", Green)
    else
        SetStatus("SELECTION CANCELLED", Muted)
    end
end)

local function ManualSelectClick()
    local Target = Mouse.Target
    if not Target or not Target:IsA("BasePart") then return end

    if IsCharacterPart(Target) then
        SetStatus("CAN'T SELECT A CHARACTER", Red)
        return
    end

    AutoTracking = false
    Selecting = false

    SelectButton.Text = "◈   SELECT BALL"
    SetActive(SelectButton, false)

    SelectBall(Target)
    SetStatus("BALL SELECTED", Green)
end

-- AUTO SELECT (BETA)

local function Normalize(text)
    return (string.lower(text):gsub("[%s_%-%.]", ""))
end

local function AncestorNameHas(inst, word)
    local current = inst.Parent
    while current and current ~= workspace do
        if string.find(Normalize(current.Name), word, 1, true) then
            return true
        end
        current = current.Parent
    end
    return false
end

local function ScoreCandidate(part)
    local name = Normalize(part.Name)

    if name == "ballhitbox" then
        return 4
    elseif string.find(name, "ball", 1, true) and string.find(name, "hitbox", 1, true) then
        return 3
    elseif string.find(name, "hitbox", 1, true) and AncestorNameHas(part, "ball") then
        return 2
    elseif name == "ball" then
        return 1
    end

    return 0
end

local function AutoSelectBall(silent)
    if Scanning then return end
    Scanning = true

    if not silent then
        SetStatus("SCANNING FOR BALL HITBOX...", Green)
    end

    task.spawn(function()
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")

        local best, bestScore, bestDistance = nil, 0, math.huge
        local count = 0

        for _, inst in ipairs(workspace:GetDescendants()) do
            count += 1
            if count % 3000 == 0 then
                task.wait() -- avoid freezing on huge maps
            end

            if inst:IsA("BasePart") then
                local score = ScoreCandidate(inst)

                if score > 0 and not IsCharacterPart(inst) then
                    local distance = root and (inst.Position - root.Position).Magnitude or 0

                    if score > bestScore or (score == bestScore and distance < bestDistance) then
                        best, bestScore, bestDistance = inst, score, distance
                    end
                end
            end
        end

        Scanning = false
        if not Alive then return end

        if best then
            AutoTracking = true
            Selecting = false
            SelectButton.Text = "◈   SELECT BALL"
            SetActive(SelectButton, false)

            SelectBall(best)
            SetStatus("BALL AUTO SELECTED", Green)
        elseif not silent then
            SetStatus("NO BALL FOUND - TRY MANUAL SELECT", Red)
        end
    end)
end

Connect(AutoSelectButton.MouseButton1Click, function()
    if Controlling then return end
    AutoSelectBall(false)
end)

-- Keeps the selection alive if the ball respawns (only after using Auto Select).
task.spawn(function()
    while Alive do
        task.wait(1.5)

        if Alive and AutoTracking and not Controlling and not Scanning then
            if not SelectedBall or not SelectedBall:IsDescendantOf(workspace) then
                AutoSelectBall(true)
            end
        end
    end
end)

-- CAMERA

local function SaveCamera()
    local Camera = workspace.CurrentCamera
    if not Camera then return false end

    SavedCameraSubject = Camera.CameraSubject
    SavedCameraType = Camera.CameraType
    SavedCameraCFrame = Camera.CFrame
    SavedCameraFocus = Camera.Focus

    return true
end

local function RestoreCamera()
    local Camera = workspace.CurrentCamera
    if not Camera then return end

    Camera.CameraType = Enum.CameraType.Scriptable

    if SavedCameraCFrame then
        Camera.CFrame = SavedCameraCFrame
    end

    if SavedCameraFocus then
        Camera.Focus = SavedCameraFocus
    end

    -- Fall back to the character's humanoid if the old subject is gone.
    local Subject = SavedCameraSubject
    if not Subject or not Subject.Parent then
        local Char = Player.Character
        Subject = Char and Char:FindFirstChildOfClass("Humanoid")
    end

    Camera.CameraSubject = Subject
    Camera.CameraType = SavedCameraType or Enum.CameraType.Custom

    SavedCameraSubject = nil
    SavedCameraType = nil
    SavedCameraCFrame = nil
    SavedCameraFocus = nil
end

-- Shiftlock-style camera: mouse is locked to the center and turns the view.
local function CameraStep()
    if not Controlling or not IsValid() then return end

    local Camera = workspace.CurrentCamera
    if not Camera then return end

    UIS.MouseBehavior = Enum.MouseBehavior.LockCenter

    local delta = UIS:GetMouseDelta()
    Yaw -= delta.X * CameraSensitivity
    Pitch = math.clamp(Pitch - delta.Y * CameraSensitivity, -1.3, 1.3)

    local focus = SelectedBall.Position

    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.CFrame = CFrame.new(focus)
        * CFrame.fromEulerAnglesYXZ(Pitch, Yaw, 0)
        * CFrame.new(0, 0, CamDistance)
    Camera.Focus = CFrame.new(focus)
end

Connect(UIS.InputChanged, function(input)
    if Controlling and input.UserInputType == Enum.UserInputType.MouseWheel then
        CamDistance = math.clamp(CamDistance - input.Position.Z * 2, MinZoom, MaxZoom)
    end
end)

-- STOP CONTROL

local function StopControl(message, color)
    if not Controlling then return end

    Controlling = false
    DashUntil = 0

    if MovementConnection then
        MovementConnection:Disconnect()
        MovementConnection = nil
    end

    if DiedConnection then
        DiedConnection:Disconnect()
        DiedConnection = nil
    end

    pcall(function()
        RunService:UnbindFromRenderStep(CAMERA_BIND)
    end)

    table.clear(Keys)

    UnfreezeBody()

    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true

    RestoreCamera()

    StartButton.Text = "▶   START CONTROL"
    SetActive(StartButton, false)

    SetStatus(message or "CONTROL STOPPED", color or Muted)
end

-- INSTA GOAL

local function StartDash()
    DashUntil = os.clock() + InstaGoalTime
    SetStatus("INSTA GOAL!", Green)
end

-- START CONTROL

local function StartControl()
    if Controlling then
        StopControl()
        return
    end

    if not IsValid() then
        SetStatus("SELECT A VALID BALL FIRST", Red)
        return
    end

    local reason = GetBlockReason(SelectedBall)
    if reason then
        SetStatus(reason, Red)
        return
    end

    if not SaveCamera() then return end

    Selecting = false
    SelectButton.Text = "◈   SELECT BALL"
    SetActive(SelectButton, false)

    local Camera = workspace.CurrentCamera

    -- Start the shiftlock camera facing the same way as the current view.
    local look = Camera.CFrame.LookVector
    Yaw = math.atan2(-look.X, -look.Z)
    Pitch = math.asin(math.clamp(look.Y, -1, 1))

    HoverY = SelectedBall.Position.Y
    DashUntil = 0
    Controlling = true

    TimeBox:ReleaseFocus() -- make sure typing doesn't swallow W while controlling

    -- Keep your body where it is while the ball is controlled.
    FreezeBody()

    local hum = FrozenState and FrozenState.Humanoid
    if hum then
        DiedConnection = hum.Died:Connect(function()
            StopControl("YOU DIED - CONTROL STOPPED", Red)
        end)
    end

    Camera.CameraType = Enum.CameraType.Scriptable
    UIS.MouseIconEnabled = false

    RunService:BindToRenderStep(CAMERA_BIND, Enum.RenderPriority.Camera.Value + 1, CameraStep)

    StartButton.Text = "■   STOP CONTROL"
    SetActive(StartButton, true, StopColor)

    SetStatus("CONTROLLING BALL", Green)

    local CheckTimer = 0

    -- Heartbeat runs alongside physics, unlike RenderStepped.
    MovementConnection = RunService.Heartbeat:Connect(function(dt)
        if not IsValid() then
            StopControl("BALL LOST", Red)
            return
        end

        -- Auto uncontrol when the ball gets attached or anchored.
        CheckTimer += dt
        if SelectedBall.Anchored or CheckTimer >= 0.05 then
            CheckTimer = 0

            local blocked = GetBlockReason(SelectedBall)
            if blocked then
                StopControl(blocked .. " - CONTROL STOPPED", Red)
                return
            end
        end

        local Cam = workspace.CurrentCamera
        if not Cam then return end

        local pos = SelectedBall.Position
        local vel = SelectedBall.AssemblyLinearVelocity

        -- Insta Goal: shoot straight ahead (where you're looking) at full speed.
        if os.clock() < DashUntil then
            HoverY = pos.Y
            SelectedBall.AssemblyLinearVelocity = Cam.CFrame.LookVector * InstaGoalSpeed
            return
        end

        if Keys.W then
            local lookVector = Cam.CFrame.LookVector

            if not FlyAlongLook then
                lookVector = Vector3.new(lookVector.X, 0, lookVector.Z)
                if lookVector.Magnitude > 0 then
                    lookVector = lookVector.Unit
                end
            end

            HoverY = pos.Y -- hover wherever you stop

            local alpha = 1 - math.exp(-dt * 14)
            SelectedBall.AssemblyLinearVelocity = vel:Lerp(lookVector * Speed, alpha)
        else
            -- Hover: brake horizontally and hold altitude.
            local alpha = 1 - math.exp(-dt * 14)
            local horizontal = Vector3.new(vel.X, 0, vel.Z):Lerp(Vector3.zero, alpha)
            local vertical = math.clamp((HoverY - pos.Y) * HoverGain, -60, 60)

            SelectedBall.AssemblyLinearVelocity =
                Vector3.new(horizontal.X, vertical, horizontal.Z)
        end
    end)
end

Connect(StartButton.MouseButton1Click, StartControl)

-- AUTO CONTROL / INSTA GOAL ON RELEASE

local function TryAutoStart(dash)
    if Controlling or not SelectedBall then return end
    if not AutoControl and not dash then return end

    AutoStartToken += 1
    local token = AutoStartToken

    task.spawn(function()
        local deadline = os.clock() + AutoStartWait
        local lastReason

        while os.clock() < deadline do
            if not Alive or token ~= AutoStartToken or Controlling then return end

            if not IsValid() then return end

            lastReason = GetBlockReason(SelectedBall)
            if not lastReason then
                StartControl()

                if dash and Controlling then
                    StartDash()
                end

                return
            end

            task.wait(0.05)
        end

        if Alive and not Controlling and token == AutoStartToken then
            SetStatus((lastReason or "BALL BLOCKED") .. " - NOT CONTROLLING", Red)
        end
    end)
end

Connect(AutoControlButton.MouseButton1Click, function()
    AutoControl = not AutoControl

    AutoControlButton.Text = AutoControl
        and "⚡   AUTO CONTROL ON RELEASE: ON"
        or "⚡   AUTO CONTROL ON RELEASE: OFF"

    SetActive(AutoControlButton, AutoControl, Purple)
    SetStatus(AutoControl and "AUTO CONTROL ENABLED" or "AUTO CONTROL DISABLED",
        AutoControl and Green or Muted)
end)

Connect(InstaGoalButton.MouseButton1Click, function()
    InstaGoal = not InstaGoal

    InstaGoalButton.Text = InstaGoal
        and "➤   INSTA GOAL: ON"
        or "➤   INSTA GOAL: OFF"

    SetActive(InstaGoalButton, InstaGoal, Purple)
    SetStatus(InstaGoal and "INSTA GOAL ENABLED" or "INSTA GOAL DISABLED",
        InstaGoal and Green or Muted)
end)

-- Copy the Discord invite from the main window.
local DiscordButton = MakeButton("Discord", "◆   COPY DISCORD INVITE", 372, 32)
DiscordButton.TextSize = 11

Connect(DiscordButton.MouseButton1Click, function()
    if CopyToClipboard(DiscordLink) then
        SetStatus("DISCORD LINK COPIED!", Green)
    else
        SetStatus("COPY FAILED: discord.gg/VaNyVR2Zwk", Red)
    end
end)

-- Edit how many seconds Insta Goal pushes the ball forward.
Connect(TimeBox.FocusLost, function()
    local value = tonumber(TimeBox.Text)

    if value then
        InstaGoalTime = math.clamp(value, MinDashTime, MaxDashTime)
        SetStatus("INSTA GOAL TIME: " .. tostring(InstaGoalTime) .. "s", Green)
    else
        SetStatus("INVALID TIME - USING " .. tostring(InstaGoalTime) .. "s", Red)
    end

    TimeBox.Text = tostring(InstaGoalTime)
end)

Connect(TimeBox.Focused, function()
    TimeStroke.Transparency = 0
end)

Connect(TimeBox.FocusLost, function()
    TimeStroke.Transparency = 0.6
end)

-- INPUT

Connect(UIS.InputBegan, function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if processed then return end -- clicks on the UI are ignored

        if Selecting and not Controlling then
            ManualSelectClick()
            return
        end

        Holding = true
        return
    end

    if input.KeyCode == Enum.KeyCode.Escape and Controlling then
        StopControl()
        return
    end

    if processed then return end

    if input.KeyCode == ToggleUIKey then
        if not IntroDone then return end
        Main.Visible = not Main.Visible
        Dragging = false
        return
    end

    if not Controlling then return end

    if input.KeyCode == StopKey then
        StopControl()
        return
    end

    if input.KeyCode == Enum.KeyCode.W then
        Keys.W = true
    end
end)

Connect(UIS.InputEnded, function(input)
    if input.KeyCode == Enum.KeyCode.W then
        Keys.W = false
    end

    -- Hold + release Mouse Button 1 anywhere on the screen.
    if input.UserInputType == Enum.UserInputType.MouseButton1 and Holding then
        Holding = false

        if Controlling then
            if InstaGoal then
                StartDash()
            end
        else
            TryAutoStart(InstaGoal)
        end
    end
end)

-- Clear stuck keys / drags if the window loses focus.
Connect(UIS.WindowFocusReleased, function()
    table.clear(Keys)
    Dragging = false
    Holding = false
end)

-- SPEED

local function UpdateSpeed(delta)
    Speed = math.clamp(Speed + delta, MinSpeed, MaxSpeed)
    SpeedValue.Text = tostring(Speed)
    SetStatus("SPEED: " .. Speed, Green)
end

Connect(SpeedUp.MouseButton1Click, function() UpdateSpeed(SpeedStep) end)
Connect(SpeedDown.MouseButton1Click, function() UpdateSpeed(-SpeedStep) end)

-- RESPAWN SAFETY

Connect(Player.CharacterAdded, function()
    if Controlling then
        StopControl()
    end
end)

-- CLOSE / CLEANUP

Connect(CloseButton.MouseButton1Click, function()
    GUI:Destroy()
end)

GUI.Destroying:Connect(function()
    Alive = false

    if Controlling then
        StopControl()
    end

    pcall(function()
        RunService:UnbindFromRenderStep(CAMERA_BIND)
    end)

    UIS.MouseBehavior = Enum.MouseBehavior.Default
    UIS.MouseIconEnabled = true

    if Highlight then
        Highlight:Destroy()
        Highlight = nil
    end

    for _, conn in ipairs(Connections) do
        conn:Disconnect()
    end
    table.clear(Connections)

    _G.KeylessHub = nil
end)

-- INTRO

local function RevealMain()
    if IntroDone then return end
    IntroDone = true

    Main.Visible = true
    MainScale.Scale = 0.85

    TweenService:Create(MainScale,
        TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }):Play()

    SetStatus("WELCOME - SELECT A BALL TO START", Green)
end

local function Tween(inst, time, props, style, direction)
    local tween = TweenService:Create(inst, TweenInfo.new(
        time,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out
    ), props)
    tween:Play()
    return tween
end

local function PlayIntro()
    local TitleText = "KEYLESS HUB"
    local LightPurple = Color3.fromRGB(190, 160, 255)

    -- Full-screen overlay (a CanvasGroup so the whole intro fades as one).
    local Intro = Instance.new("CanvasGroup")
    Intro.Name = "Intro"
    Intro.Size = UDim2.fromScale(1, 1)
    Intro.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
    Intro.BorderSizePixel = 0
    Intro.Active = true -- blocks clicks from reaching the game
    Intro.ZIndex = 50
    Intro.GroupTransparency = 1
    Intro.Parent = GUI

    -- Soft pulsing glow behind the title.
    local Glow = Instance.new("Frame")
    Glow.AnchorPoint = Vector2.new(0.5, 0.5)
    Glow.Position = UDim2.new(0.5, 0, 0.5, -90)
    Glow.Size = UDim2.fromOffset(340, 340)
    Glow.BackgroundColor3 = Purple
    Glow.BackgroundTransparency = 0.9
    Glow.BorderSizePixel = 0
    Glow.ZIndex = 1
    Glow.Parent = Intro
    Instance.new("UICorner", Glow).CornerRadius = UDim.new(1, 0)

    TweenService:Create(Glow, TweenInfo.new(2.2, Enum.EasingStyle.Sine,
        Enum.EasingDirection.InOut, -1, true), {
        Size = UDim2.fromOffset(420, 420),
        BackgroundTransparency = 0.95
    }):Play()

    -- Floating particles.
    local Particles = Instance.new("Frame")
    Particles.Size = UDim2.fromScale(1, 1)
    Particles.BackgroundTransparency = 1
    Particles.ClipsDescendants = true
    Particles.ZIndex = 1
    Particles.Parent = Intro

    for i = 1, 18 do
        task.spawn(function()
            local rng = Random.new(i * 977)

            local dot = Instance.new("Frame")
            local size = rng:NextInteger(3, 7)
            dot.Size = UDim2.fromOffset(size, size)
            dot.BackgroundColor3 = i % 3 == 0 and LightPurple or Purple
            dot.BackgroundTransparency = 1
            dot.BorderSizePixel = 0
            Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
            dot.Parent = Particles

            task.wait(rng:NextNumber(0, 2.5))

            while Alive and Intro.Parent ~= nil do
                local x = rng:NextNumber(0.02, 0.98)
                local duration = rng:NextNumber(4, 8)

                dot.Position = UDim2.new(x, 0, 1.05, 0)
                dot.BackgroundTransparency = 1

                Tween(dot, duration, {
                    Position = UDim2.new(x + rng:NextNumber(-0.06, 0.06), 0, -0.05, 0)
                }, Enum.EasingStyle.Linear)

                Tween(dot, duration * 0.2, { BackgroundTransparency = 0.4 },
                    Enum.EasingStyle.Sine)

                task.delay(duration * 0.75, function()
                    if dot.Parent then
                        Tween(dot, duration * 0.25, { BackgroundTransparency = 1 },
                            Enum.EasingStyle.Sine)
                    end
                end)

                task.wait(duration)
            end
        end)
    end

    -- Centered container, scaled to fit small screens.
    local Container = Instance.new("Frame")
    Container.AnchorPoint = Vector2.new(0.5, 0.5)
    Container.Position = UDim2.fromScale(0.5, 0.5)
    Container.Size = UDim2.fromOffset(420, 370)
    Container.BackgroundTransparency = 1
    Container.ZIndex = 2
    Container.Parent = Intro

    local ContainerScale = Instance.new("UIScale")
    ContainerScale.Parent = Container

    local function FitScale()
        local screen = GUI.AbsoluteSize
        ContainerScale.Scale = math.clamp(math.min(screen.X / 460, screen.Y / 420), 0.5, 1.15)
    end

    FitScale()
    local FitConnection = GUI:GetPropertyChangedSignal("AbsoluteSize"):Connect(FitScale)

    -- "WE PRESENT"
    local WePresent = Instance.new("TextLabel")
    WePresent.Position = UDim2.new(0, 0, 0, -10)
    WePresent.Size = UDim2.new(1, 0, 0, 18)
    WePresent.BackgroundTransparency = 1
    WePresent.Text = "W E   P R E S E N T"
    WePresent.TextColor3 = Muted
    WePresent.TextTransparency = 1
    WePresent.Font = Enum.Font.GothamBold
    WePresent.TextSize = 13
    WePresent.Parent = Container

    -- Title (typewriter + shimmer)
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Position = UDim2.new(0, 0, 0, 22)
    TitleLabel.Size = UDim2.new(1, 0, 0, 60)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = TitleText
    TitleLabel.TextColor3 = White
    TitleLabel.Font = Enum.Font.GothamBlack
    TitleLabel.TextSize = 50
    TitleLabel.MaxVisibleGraphemes = 0
    TitleLabel.Parent = Container

    local Shimmer = Instance.new("UIGradient")
    Shimmer.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Purple),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Purple),
    })
    Shimmer.Offset = Vector2.new(-1, 0)
    Shimmer.Parent = TitleLabel

    TweenService:Create(Shimmer, TweenInfo.new(2.2, Enum.EasingStyle.Linear,
        Enum.EasingDirection.InOut, -1), {
        Offset = Vector2.new(1, 0)
    }):Play()

    -- Accent line
    local Line = Instance.new("Frame")
    Line.AnchorPoint = Vector2.new(0.5, 0)
    Line.Position = UDim2.new(0.5, 0, 0, 90)
    Line.Size = UDim2.fromOffset(0, 3)
    Line.BackgroundColor3 = Purple
    Line.BorderSizePixel = 0
    Line.Parent = Container
    Instance.new("UICorner", Line).CornerRadius = UDim.new(1, 0)

    -- Version badge
    local Badge = Instance.new("Frame")
    Badge.AnchorPoint = Vector2.new(0.5, 0)
    Badge.Position = UDim2.new(0.5, 0, 0, 104)
    Badge.Size = UDim2.fromOffset(0, 0)
    Badge.BackgroundColor3 = Purple
    Badge.BorderSizePixel = 0
    Badge.ClipsDescendants = true
    Badge.Parent = Container
    Instance.new("UICorner", Badge).CornerRadius = UDim.new(0, 16)

    local BadgeText = Instance.new("TextLabel")
    BadgeText.Size = UDim2.fromScale(1, 1)
    BadgeText.BackgroundTransparency = 1
    BadgeText.Text = "V1.6"
    BadgeText.TextColor3 = White
    BadgeText.TextTransparency = 1
    BadgeText.Font = Enum.Font.GothamBlack
    BadgeText.TextSize = 16
    BadgeText.Parent = Badge

    -- Discord card (inside a CanvasGroup so it can fade + slide as one)
    local CardGroup = Instance.new("CanvasGroup")
    CardGroup.Position = UDim2.new(0, 0, 0, 176)
    CardGroup.Size = UDim2.new(1, 0, 0, 150)
    CardGroup.BackgroundTransparency = 1
    CardGroup.GroupTransparency = 1
    CardGroup.Parent = Container

    local Card = Instance.new("Frame")
    Card.Position = UDim2.fromOffset(2, 2)
    Card.Size = UDim2.new(1, -4, 1, -4)
    Card.BackgroundColor3 = Panel
    Card.BorderSizePixel = 0
    Card.Parent = CardGroup
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 14)

    local CardStroke = Instance.new("UIStroke")
    CardStroke.Color = Purple
    CardStroke.Thickness = 1.5
    CardStroke.Transparency = 0.2
    CardStroke.Parent = Card

    local CardTitle = Instance.new("TextLabel")
    CardTitle.Position = UDim2.fromOffset(16, 12)
    CardTitle.Size = UDim2.new(1, -32, 0, 20)
    CardTitle.BackgroundTransparency = 1
    CardTitle.Text = "JOIN OUR DISCORD SERVER"
    CardTitle.TextColor3 = White
    CardTitle.Font = Enum.Font.GothamBold
    CardTitle.TextSize = 14
    CardTitle.Parent = Card

    local CardSub = Instance.new("TextLabel")
    CardSub.Position = UDim2.fromOffset(16, 33)
    CardSub.Size = UDim2.new(1, -32, 0, 16)
    CardSub.BackgroundTransparency = 1
    CardSub.Text = "Get updates, support and more!"
    CardSub.TextColor3 = Muted
    CardSub.Font = Enum.Font.Gotham
    CardSub.TextSize = 11
    CardSub.Parent = Card

    local LinkBox = Instance.new("TextBox")
    LinkBox.Position = UDim2.fromOffset(16, 58)
    LinkBox.Size = UDim2.new(1, -32, 0, 32)
    LinkBox.BackgroundColor3 = ButtonColor
    LinkBox.BorderSizePixel = 0
    LinkBox.Text = DiscordLink
    LinkBox.TextColor3 = LightPurple
    LinkBox.Font = Enum.Font.GothamBold
    LinkBox.TextSize = 12
    LinkBox.ClearTextOnFocus = false
    LinkBox.Parent = Card
    Instance.new("UICorner", LinkBox).CornerRadius = UDim.new(0, 8)

    -- The link can be selected and copied, but not changed.
    Connect(LinkBox:GetPropertyChangedSignal("Text"), function()
        if LinkBox.Text ~= DiscordLink then
            LinkBox.Text = DiscordLink
        end
    end)

    local CopyButton = Instance.new("TextButton")
    CopyButton.Position = UDim2.fromOffset(16, 98)
    CopyButton.Size = UDim2.new(1, -32, 0, 32)
    CopyButton.BackgroundColor3 = Purple
    CopyButton.BorderSizePixel = 0
    CopyButton.Text = "COPY INVITE LINK"
    CopyButton.TextColor3 = White
    CopyButton.Font = Enum.Font.GothamBold
    CopyButton.TextSize = 12
    CopyButton.AutoButtonColor = false
    CopyButton.Parent = Card
    Instance.new("UICorner", CopyButton).CornerRadius = UDim.new(0, 8)

    local CopyHover = Color3.fromRGB(170, 120, 255)

    Connect(CopyButton.MouseEnter, function()
        Tween(CopyButton, 0.15, { BackgroundColor3 = CopyHover })
    end)

    Connect(CopyButton.MouseLeave, function()
        Tween(CopyButton, 0.15, { BackgroundColor3 = Purple })
    end)

    local Copying = false

    Connect(CopyButton.MouseButton1Click, function()
        if Copying then return end
        Copying = true

        if CopyToClipboard(DiscordLink) then
            CopyButton.Text = "COPIED!"
        else
            -- No clipboard access: select the text so you can press Ctrl+C.
            LinkBox:CaptureFocus()
            LinkBox.CursorPosition = #DiscordLink + 1
            LinkBox.SelectionStart = 1
            CopyButton.Text = "PRESS CTRL+C TO COPY"
        end

        task.wait(2)

        if CopyButton.Parent then
            CopyButton.Text = "COPY INVITE LINK"
        end
        Copying = false
    end)

    -- Loading bar
    local Track = Instance.new("Frame")
    Track.AnchorPoint = Vector2.new(0.5, 0)
    Track.Position = UDim2.new(0.5, 0, 0, 340)
    Track.Size = UDim2.fromOffset(260, 4)
    Track.BackgroundColor3 = Panel
    Track.BorderSizePixel = 0
    Track.Parent = Container
    Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.fromScale(0, 1)
    Fill.BackgroundColor3 = Purple
    Fill.BorderSizePixel = 0
    Fill.Parent = Track
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    -- Continue button (appears when loading finishes)
    local Continue = Instance.new("TextButton")
    Continue.AnchorPoint = Vector2.new(0.5, 0)
    Continue.Position = UDim2.new(0.5, 0, 0, 330)
    Continue.Size = UDim2.fromOffset(0, 0)
    Continue.BackgroundColor3 = Purple
    Continue.BorderSizePixel = 0
    Continue.Text = ""
    Continue.TextColor3 = White
    Continue.Font = Enum.Font.GothamBold
    Continue.TextSize = 13
    Continue.AutoButtonColor = false
    Continue.ClipsDescendants = true
    Continue.Visible = false
    Continue.Parent = Container
    Instance.new("UICorner", Continue).CornerRadius = UDim.new(0, 10)

    local ContinueStroke = Instance.new("UIStroke")
    ContinueStroke.Color = Color3.fromRGB(230, 215, 255)
    ContinueStroke.Thickness = 1.5
    ContinueStroke.Transparency = 0.2
    ContinueStroke.Parent = Continue

    Connect(Continue.MouseEnter, function()
        Tween(Continue, 0.15, { BackgroundColor3 = CopyHover })
    end)

    Connect(Continue.MouseLeave, function()
        Tween(Continue, 0.15, { BackgroundColor3 = Purple })
    end)

    local Clicked = false
    Connect(Continue.MouseButton1Click, function()
        Clicked = true
    end)

    ---------------------------------------------------------------
    -- TIMELINE
    ---------------------------------------------------------------

    Tween(Intro, 0.5, { GroupTransparency = 0 }, Enum.EasingStyle.Sine)
    task.wait(0.35)

    local BarTween = Tween(Fill, 3.6, { Size = UDim2.fromScale(1, 1) },
        Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

    -- 1) We present
    Tween(WePresent, 0.7, {
        Position = UDim2.new(0, 0, 0, 0),
        TextTransparency = 0
    })
    task.wait(0.5)

    -- 2) Accent line
    Tween(Line, 0.6, { Size = UDim2.fromOffset(260, 3) })
    task.wait(0.15)

    -- 3) Title typewriter
    for i = 1, #TitleText do
        if not Alive then return end
        TitleLabel.MaxVisibleGraphemes = i
        task.wait(0.055)
    end
    task.wait(0.1)

    -- 4) Version badge pops in
    Tween(Badge, 0.5, { Size = UDim2.fromOffset(96, 32) },
        Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    Tween(BadgeText, 0.4, { TextTransparency = 0 })
    task.wait(0.35)

    -- 5) Discord card slides up
    Tween(CardGroup, 0.7, {
        Position = UDim2.new(0, 0, 0, 150),
        GroupTransparency = 0
    })

    -- 6) Wait for loading to finish
    BarTween.Completed:Wait()
    if not Alive then return end

    Tween(Track, 0.3, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
    Tween(Fill, 0.3, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
    task.wait(0.2)

    Continue.Text = "CONTINUE  ▶"
    Continue.Visible = true
    Tween(Continue, 0.45, { Size = UDim2.fromOffset(200, 38) },
        Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    TweenService:Create(ContinueStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine,
        Enum.EasingDirection.InOut, -1, true), {
        Transparency = 0.85
    }):Play()

    repeat
        task.wait()
    until Clicked or not Alive

    if not Alive then return end

    -- 7) Exit: zoom + fade out
    Tween(ContainerScale, 0.6, { Scale = ContainerScale.Scale * 1.08 },
        Enum.EasingStyle.Sine, Enum.EasingDirection.In)

    local FadeOut = Tween(Intro, 0.6, { GroupTransparency = 1 },
        Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    FadeOut.Completed:Wait()

    FitConnection:Disconnect()
end

task.spawn(function()
    local ok, err = pcall(PlayIntro)

    if not ok then
        warn("[Keyless Hub] Intro failed: " .. tostring(err))
    end

    -- Always clean up the overlay and show the window.
    local leftover = GUI:FindFirstChild("Intro")
    if leftover then
        leftover:Destroy()
    end

    if Alive then
        RevealMain()
    end
end)

print("KEYLESS HUB v1.6 loaded!")

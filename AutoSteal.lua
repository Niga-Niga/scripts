getgenv().Config = getgenv().Config or {
    ["Auto Game"] = {
        ["Rarity"] = {
            ["Enable"] = false,
            ["Name Rarity"] = {"Mythic","Secret"},
        },
        ["Name"] = {
            ["Enable"] = true,
            ["Name Brainrot"] = {"Pandanini Frostini","Lucky Block"},
        }
    },
    ["Max slot"] = 10,
    ["Hold Buffer"] = 1,
    ["Clone Check Interval"] = 1,
    ["Prompt Search Radius"] = 18,
    ["Prompt Search Radius Max"] = 60,
    ["Prompt Search Time"] = 2.5,
    ["Fallback Use Any Steal Prompt"] = true
}

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

local CFG = getgenv().Config
local Plots = workspace:WaitForChild("Plots")

local function safeWrite(name, content)
    pcall(function()
        if writefile then writefile(name, content) end
    end)
end

local Camera = workspace.CurrentCamera
local CamSaved

local function camTopDownCharacter()
    local cam = workspace.CurrentCamera
    if not cam or not hrp then return end

    CamSaved = {
        Type = cam.CameraType,
        CFrame = cam.CFrame,
        Focus = cam.Focus,
        Subject = cam.CameraSubject,
        Fov = cam.FieldOfView,
    }

    cam.CameraType = Enum.CameraType.Scriptable

    local height = 6
    local pos = hrp.Position
    local camPos = pos + Vector3.new(0, height, 0)

    cam.CFrame = CFrame.new(camPos, pos)
    cam.Focus = CFrame.new(pos)
end


local function camRestore()
    Camera = workspace.CurrentCamera
    if not (Camera and CamSaved) then return end
    Camera.CameraType = CamSaved.Type
    Camera.CFrame = CamSaved.CFrame
    Camera.Focus = CamSaved.Focus
    Camera.CameraSubject = CamSaved.Subject
    Camera.FieldOfView = CamSaved.Fov
    CamSaved = nil
end

local DesiredNames = {}
for _,n in ipairs((CFG["Auto Game"] and CFG["Auto Game"]["Name"] and CFG["Auto Game"]["Name"]["Name Brainrot"]) or {}) do
    DesiredNames[n] = true
end

local function nameMatch(n) return DesiredNames[n] == true end

local function rarityMatch(r)
    for _,v in ipairs((CFG["Auto Game"] and CFG["Auto Game"]["Rarity"] and CFG["Auto Game"]["Rarity"]["Name Rarity"]) or {}) do
        if r == v then return true end
    end
    return false
end

local function getMyPlot()
    for _,p in ipairs(Plots:GetChildren()) do
        local yb = p:FindFirstChild("PlotSign") and p.PlotSign:FindFirstChild("YourBase")
        if yb and yb.Enabled then return p end
    end
end

local myPlot = getMyPlot()
if not myPlot then return end

local characterDied = false
local lastPath = nil

local function setupCharacterMonitor()
    characterDied = false
    if hum then
        hum.Died:Connect(function()
            characterDied = true
        end)
    end
end

setupCharacterMonitor()

lp.CharacterAdded:Connect(function(newChar)
    char = newChar
    hum = char:WaitForChild("Humanoid")
    hrp = char:WaitForChild("HumanoidRootPart")
    task.wait(0.5)
    setupCharacterMonitor()
    characterDied = false
    lastPath = nil
end)

local function getDistance2D(v1, v2)
    return (Vector3.new(v1.X, 0, v1.Z) - Vector3.new(v2.X, 0, v2.Z)).Magnitude
end

local SKIP_TTL = 20
local Skipped = {}

local function now() return os.clock() end

local function getId(inst)
    if typeof(inst) ~= "Instance" then return nil end
    local ok, id = pcall(function()
        return inst:GetDebugId(1)
    end)
    if ok and id then return id end
    return tostring(inst)
end

local function targetKey(info)
    if info.Kind == "Pod" and info.Prompt then
        return "P:" .. (getId(info.Prompt) or (info.Name .. "|pod"))
    end
    if info.Root and typeof(info.Root) == "Instance" then
        return "M:" .. (getId(info.Root) or (info.Name .. "|model"))
    end
    local p = info.Position
    if typeof(p) == "Vector3" then
        return ("X:%d|Y:%d|Z:%d|%s"):format(math.floor(p.X+0.5), math.floor(p.Y+0.5), math.floor(p.Z+0.5), tostring(info.Name))
    end
    return tostring(info.Name)
end

local function isSkipped(info)
    local k = targetKey(info)
    local t = Skipped[k]
    if not t then return false end
    if now() >= t then
        Skipped[k] = nil
        return false
    end
    return true
end

local function skipTarget(info)
    Skipped[targetKey(info)] = now() + SKIP_TTL
end

local function walkTo(targetPos, useSavedPath)
    if characterDied then return false end
    if not (hrp and hum) then return false end

    local waypoints

    if useSavedPath and lastPath then
        waypoints = {}
        for i = #lastPath, 1, -1 do
            waypoints[#waypoints + 1] = lastPath[i]
        end
    else
        local path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentCanClimb = true,
            WaypointSpacing = 8,
            Costs = { Water = math.huge, Danger = math.huge },
        })

        local ok = pcall(function()
            path:ComputeAsync(hrp.Position, targetPos)
        end)

        if not ok or path.Status ~= Enum.PathStatus.Success then
            return false
        end

        waypoints = path:GetWaypoints()
        lastPath = waypoints
        if not waypoints or #waypoints == 0 then
            return false
        end
    end

    for _, wp in ipairs(waypoints) do
        if characterDied then
            return false
        end

        if wp.Action == Enum.PathWaypointAction.Jump then
            hum.Jump = true
        end

        hum:MoveTo(wp.Position)

        local reached = false
        local conn = hum.MoveToFinished:Connect(function()
            reached = true
        end)

        local t0 = tick()
        local tStuck = tick()

        while not reached and getDistance2D(hrp.Position, wp.Position) > 4 do
            if characterDied then
                if conn then conn:Disconnect() end
                return false
            end

            if tick() - tStuck > 1.5 then
                local vel = hrp.AssemblyLinearVelocity.Magnitude
                if vel < 0.1 and hum.FloorMaterial ~= Enum.Material.Air then
                    hum.Jump = true
                    hum:MoveTo(wp.Position)
                end
                tStuck = tick()
            end

            if tick() - t0 > 10 then
                if conn then conn:Disconnect() end
                return false
            end

            task.wait(0.01)
        end

        if conn then conn:Disconnect() end
    end

    return true
end

local function backToBase(useSavedPath)
    if not myPlot then return false end
    local ok = walkTo(myPlot:GetPivot().Position, useSavedPath == true)
    if ok and useSavedPath == true then
        lastPath = nil
    end
    return ok
end

local function scanOwned(plot)
    local pods = plot and plot:FindFirstChild("AnimalPodiums")
    if not pods then return 0,{} end
    local occupied,list = 0,{}
    for _,s in ipairs(pods:GetChildren()) do
        local spawn = s:FindFirstChild("Base") and s.Base:FindFirstChild("Spawn")
        if not spawn then continue end
        local att = spawn:FindFirstChild("Attachment")
        local oh = att and att:FindFirstChild("AnimalOverhead")
        local dn = oh and oh:FindFirstChild("DisplayName")
        local rr = oh and oh:FindFirstChild("Rarity")
        if dn and rr then
            occupied += 1
            list[#list+1] = {Name = dn.Text, Rarity = rr.Text}
        end
    end
    return occupied,list
end

local function scanPods(plot)
    local list = {}
    local pods = plot and plot:FindFirstChild("AnimalPodiums")
    if not pods then return list end
    for _,s in ipairs(pods:GetChildren()) do
        local spawn = s:FindFirstChild("Base") and s.Base:FindFirstChild("Spawn")
        if not spawn then continue end
        local att = spawn:FindFirstChild("Attachment")
        local oh = att and att:FindFirstChild("AnimalOverhead")
        local dn = oh and oh:FindFirstChild("DisplayName")
        local rr = oh and oh:FindFirstChild("Rarity")
        if not (dn and rr) then continue end

        local prompt
        local pa = spawn:FindFirstChild("PromptAttachment")
        if pa then
            for _,p in ipairs(pa:GetChildren()) do
                if p:IsA("ProximityPrompt") and p.ActionText == "Steal" then
                    prompt = p
                    break
                end
            end
        end

        if prompt then
            list[#list+1] = {Name = dn.Text, Rarity = rr.Text, Root = spawn, Position = spawn.Position, Prompt = prompt, Kind = "Pod"}
        end
    end
    return list
end

local function getModelPos(m)
    local ok, cf = pcall(function() return m:GetPivot() end)
    if ok and cf then return cf.Position end
    local pp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
    return pp and pp.Position
end

local function scanModels(plot)
    local list = {}
    if not plot then return list end
    for _,d in ipairs(plot:GetDescendants()) do
        if d:IsA("Model") and nameMatch(d.Name) then
            local pos = getModelPos(d)
            if pos then
                list[#list+1] = {Name = d.Name, Root = d, Position = pos, Prompt = nil, Kind = "Model"}
            end
        end
    end
    return list
end

local function promptWorldPos(pr)
    local part = pr.Parent
    if part and part:IsA("Attachment") then part = part.Parent end
    if part and part:IsA("BasePart") then return part.Position end
end

local function bestStealPromptNear(expectedName, radius)
    local best, bestDist
    for _,inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("ProximityPrompt") and inst.Enabled and inst.ActionText == "Steal" then
            local pos = promptWorldPos(inst)
            if pos then
                local dist = (hrp.Position - pos).Magnitude
                if dist <= radius then
                    local okName = true
                    if expectedName then
                        local ot = inst.ObjectText
                        if ot and ot ~= "" then
                            okName = (ot == expectedName) or (string.find(ot, expectedName, 1, true) ~= nil)
                        end
                    end
                    if okName and (not bestDist or dist < bestDist) then
                        best, bestDist = inst, dist
                    end
                end
            end
        end
    end
    return best, bestDist
end

local function nearestAnyStealPrompt(radius)
    local best, bestDist
    for _,inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("ProximityPrompt") and inst.Enabled and inst.ActionText == "Steal" then
            local pos = promptWorldPos(inst)
            if pos then
                local dist = (hrp.Position - pos).Magnitude
                if (not radius or dist <= radius) and (not bestDist or dist < bestDist) then
                    best, bestDist = inst, dist
                end
            end
        end
    end
    return best, bestDist
end

local function findTarget()
    for _,p in ipairs(Plots:GetChildren()) do
        if p ~= myPlot then
            for _,info in ipairs(scanPods(p)) do
                if not isSkipped(info) then
                    if CFG["Auto Game"]["Name"]["Enable"] and nameMatch(info.Name) then
                        return info
                    end
                    if CFG["Auto Game"]["Rarity"]["Enable"] and rarityMatch(info.Rarity) then
                        return info
                    end
                end
            end
            if CFG["Auto Game"]["Name"]["Enable"] then
                for _,info in ipairs(scanModels(p)) do
                    if not isSkipped(info) then
                        return info
                    end
                end
            end
        end
    end
end

local function holdPrompt(prompt)
    hum:Move(Vector3.zero)
    task.wait(0.05)
    local t = (prompt.HoldDuration or 0) + (CFG["Hold Buffer"] or 1)
    prompt:InputHoldBegin()
    task.wait(t)
    prompt:InputHoldEnd()
end

local function holdTarget(info)
    if info.Kind == "Pod" and info.Prompt then
        pcall(function() holdPrompt(info.Prompt) end)
        return
    end

    local t0 = now()
    local r = CFG["Prompt Search Radius"] or 18
    local rmax = CFG["Prompt Search Radius Max"] or 60
    local searchTime = CFG["Prompt Search Time"] or 2.5

    while now() - t0 < searchTime do
        local p = bestStealPromptNear(info.Name, r)
        if p then
            pcall(function() holdPrompt(p) end)
            return
        end
        r = math.min(r + 6, rmax)
        task.wait(0.1)
    end

    if CFG["Fallback Use Any Steal Prompt"] then
        local p = nearestAnyStealPrompt(rmax)
        if p then
            pcall(function() holdPrompt(p) end)
            return
        end
    end
end

local function hasDesiredInMyBase()
    local _,list = scanOwned(myPlot)
    for _,i in ipairs(list) do
        if CFG["Auto Game"]["Name"]["Enable"] and nameMatch(i.Name) then return true end
        if CFG["Auto Game"]["Rarity"]["Enable"] and rarityMatch(i.Rarity) then return true end
    end
    if CFG["Auto Game"]["Name"]["Enable"] then
        for _,d in ipairs(myPlot:GetDescendants()) do
            if d:IsA("Model") and nameMatch(d.Name) then return true end
        end
    end
    return false
end

local ROLE_IS_MAIN = not hasDesiredInMyBase()

if not ROLE_IS_MAIN then
    while true do
        if not hasDesiredInMyBase() then
            safeWrite(lp.Name .. ".txt", "Completed-Clone")
            task.wait(1)
            game:Shutdown()
            break
        end
        task.wait(CFG["Clone Check Interval"] or 1)
    end
    return
end

while true do
    local occupied = select(1, scanOwned(myPlot))
    if occupied >= (CFG["Max slot"] or 10) then
        safeWrite(lp.Name .. ".txt", "Completed-Main")
        task.wait(1)
        game:Shutdown()
        break
    end

    local target = findTarget()
    if not target then
        task.wait(1)
        continue
    end

    local ok = walkTo(target.Position)
    if not ok then
        skipTarget(target)
        pcall(function() backToBase(false) end)
        task.wait(0.5)
        continue
    end

    task.wait(0.25)

    camTopDownCharacter()
    pcall(function()
        holdTarget(target)
    end)
    camRestore()

    task.wait(0.3)
    backToBase(true)
    task.wait(0.5)
end

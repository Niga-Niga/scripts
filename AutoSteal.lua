getgenv().Config = getgenv().Config or {
    ["Auto Game"] = {
        ["Rarity"] = {
            ["Enable"] = false,
            ["Name Rarity"] = {"Mythic","Secret"},
        },
        ["Name"] = {
            ["Enable"] = true,
            ["Name Brainrot"] = {"Secret Lucky Block", "Festive Lucky Block"},
        }
    },
    ["Max slot"] = 10,
    ["Hold Buffer"] = 1,
    ["Clone Check Interval"] = 1,

    ["Prompt Search Radius"] = 18,
    ["Prompt Search Radius Max"] = 60,
    ["Prompt Search Time"] = 2.5,
    ["Fallback Use Any Steal Prompt"] = true,

    ["Waypoint Spacing"] = 8,
    ["Waypoint Timeout"] = 10,
    ["Stuck Check Every"] = 1.5,
    ["Stuck Velocity"] = 0.1,
    ["Arrive Dist2D"] = 4,
    ["Compute Retry"] = 3
}

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local lp = Players.LocalPlayer
local CFG = getgenv().Config
local Plots = workspace:WaitForChild("Plots")

local char = lp.Character or lp.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

lp.CharacterAdded:Connect(function(c)
    char = c
    hum = char:WaitForChild("Humanoid")
    hrp = char:WaitForChild("HumanoidRootPart")
end)

local function safeWrite(name, content)
    pcall(function()
        if writefile then writefile(name, content) end
    end)
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

local function waitForLanding(maxSec)
    maxSec = maxSec or 8
    local t0 = os.clock()
    while os.clock() - t0 < maxSec do
        if hum and hum.FloorMaterial ~= Enum.Material.Air then return true end
        task.wait(0.1)
    end
    return false
end

local function dist2D(a, b)
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local lastPath = nil

local function nudgeUnstuck()
    if not (hum and hrp) then return end
    hum.Jump = true
    hum:MoveTo(hrp.Position + hrp.CFrame.LookVector * 6)
    task.wait(0.15)
end

local function computePath(fromPos, toPos)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = CFG["Waypoint Spacing"] or 8,
        Costs = { Water = math.huge, Danger = math.huge },
    })
    local ok = pcall(function()
        path:ComputeAsync(fromPos, toPos)
    end)
    if ok and path.Status == Enum.PathStatus.Success then
        return path:GetWaypoints()
    end
end

local function walkTo(targetPos, useSavedReverse)
    if not (hum and hrp) then return false end
    waitForLanding(6)

    local waypoints
    if useSavedReverse and lastPath then
        waypoints = {}
        for i = #lastPath, 1, -1 do
            waypoints[#waypoints+1] = lastPath[i]
        end
    else
        local tries = CFG["Compute Retry"] or 3
        for i = 1, tries do
            waypoints = computePath(hrp.Position, targetPos)
            if waypoints then break end
            nudgeUnstuck()
            task.wait(0.05)
        end

        if waypoints then
            lastPath = waypoints
        else
            hum:MoveTo(targetPos)
            hum.MoveToFinished:Wait()
            return true
        end
    end

    local arrive2d = CFG["Arrive Dist2D"] or 4
    local wpTimeout = CFG["Waypoint Timeout"] or 10
    local stuckEvery = CFG["Stuck Check Every"] or 1.5
    local stuckVel = CFG["Stuck Velocity"] or 0.1

    for i, wp in ipairs(waypoints) do
        if wp.Action == Enum.PathWaypointAction.Jump then
            hum.Jump = true
        end

        hum:MoveTo(wp.Position)

        local reached = false
        local conn
        conn = hum.MoveToFinished:Connect(function()
            reached = true
            if conn then conn:Disconnect() end
        end)

        local t0 = os.clock()
        local stuckT = os.clock()

        while (not reached) and dist2D(hrp.Position, wp.Position) > arrive2d do
            if os.clock() - stuckT > stuckEvery then
                local v = hrp.AssemblyLinearVelocity.Magnitude
                if v < stuckVel and hum.FloorMaterial ~= Enum.Material.Air then
                    hum.Jump = true
                    hum:MoveTo(wp.Position)
                end
                stuckT = os.clock()
            end

            if os.clock() - t0 > wpTimeout then
                break
            end
            task.wait(0.01)
        end

        if conn then conn:Disconnect() end
    end
    return true
end

local function backToBase()
    local pos = myPlot:GetPivot().Position
    local ok = walkTo(pos, true)
    lastPath = nil
    waitForLanding(6)
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
            list[#list+1] = {Name = dn.Text, Rarity = rr.Text, Position = spawn.Position, Prompt = prompt, Kind = "Pod"}
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
                list[#list+1] = {Name = d.Name, Position = pos, Kind = "Model"}
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
                if CFG["Auto Game"]["Name"]["Enable"] and nameMatch(info.Name) then
                    return info
                end
                if CFG["Auto Game"]["Rarity"]["Enable"] and rarityMatch(info.Rarity) then
                    return info
                end
            end
            if CFG["Auto Game"]["Name"]["Enable"] then
                local ms = scanModels(p)
                if #ms > 0 then
                    return ms[1]
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
        return true
    end

    local t0 = os.clock()
    local r = CFG["Prompt Search Radius"] or 18
    local rmax = CFG["Prompt Search Radius Max"] or 60
    local searchTime = CFG["Prompt Search Time"] or 2.5

    while os.clock() - t0 < searchTime do
        local p = bestStealPromptNear(info.Name, r)
        if p then
            pcall(function() holdPrompt(p) end)
            return true
        end
        r = math.min(r + 6, rmax)
        task.wait(0.1)
    end

    if CFG["Fallback Use Any Steal Prompt"] then
        local p = nearestAnyStealPrompt(rmax)
        if p then
            pcall(function() holdPrompt(p) end)
            return true
        end
    end
    return false
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
            print("het brainrot")
            safeWrite(lp.Name .. ".txt", "Completed-CloneSAB")
            break
        end
        task.wait(CFG["Clone Check Interval"] or 1)
    end
    return
end

while true do
    local occupied = select(1, scanOwned(myPlot))
    if occupied >= (CFG["Max slot"] or 10) then
        print("max slot")
        safeWrite(lp.Name .. ".txt", "Completed-Main")
        break
    end

    local target = findTarget()
    if not target then
        print("ko co target")
        safeWrite(lp.Name .. ".txt", "Completed-Main")
        break
    end

    walkTo(target.Position, false)
    task.wait(0.15)
    holdTarget(target)
    task.wait(0.2)
    backToBase()
    task.wait(0.25)
end

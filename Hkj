getgenv().Config = getgenv().Config or {
    ["Auto Game"] = {
        ["Rarity"] = {
            ["Enable"] = false,
            ["Name Rarity"] = {"Mythic","Secret"},
        },
        ["Name"] = {
            ["Enable"] = true,
            ["Name Brainrot"] = {"Secret Lucky Block","Festive Lucky Block"},
        }
    },
    ["Account Main"] = {"dopro0","Dopro0"},
    ["Max slot"] = 10,
    ["Hold Buffer"] = 1,
    ["Clone Check Interval"] = 1,
    ["Prompt Search Radius"] = 18,
    ["Prompt Search Radius Max"] = 60,
    ["Prompt Search Time"] = 0.5,
    ["Fallback Use Any Steal Prompt"] = true,
    ["No Target Timeout"] = 60,
    ["Base Offset"] = Vector3.new(0,0,6),
    ["Direct Move Timeout"] = 10
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

local function isMain()
    for _,v in ipairs(CFG["Account Main"] or {}) do
        if v == lp.Name or v == lp.DisplayName then
            return true
        end
    end
    return false
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

local function getSafeBasePos()
    local sign = myPlot:FindFirstChild("PlotSign")
    if sign then
        local bp = sign:FindFirstChildWhichIsA("BasePart", true)
        if bp then return bp.Position + (CFG["Base Offset"] or Vector3.new(0,0,6)) end
    end
    local bp = myPlot.PrimaryPart or myPlot:FindFirstChildWhichIsA("BasePart", true)
    if bp then return bp.Position + (CFG["Base Offset"] or Vector3.new(0,0,6)) end
    return myPlot:GetPivot().Position
end

local function directRunTo(pos, timeout)
    timeout = timeout or (CFG["Direct Move Timeout"] or 10)
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        hum:MoveTo(pos)
        local ok = hum.MoveToFinished:Wait()
        if ok then return true end
        task.wait(0.05)
    end
    return (hrp.Position - pos).Magnitude <= 6
end

local function findBestRampPart_AllPlots(fromPos, targetPos)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local best, bestScore
    local ty = targetPos.Y
    for _,obj in ipairs(plots:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "Model" then
            for _,d in ipairs(obj:GetDescendants()) do
                if d:IsA("BasePart") and d.CanCollide then
                    local p = d.Position
                    local distFrom = (fromPos - p).Magnitude
                    local distToTarget = (targetPos - p).Magnitude
                    local yGain = p.Y - fromPos.Y
                    local score = distFrom + distToTarget - math.clamp(yGain, 0, 200) * 0.6
                    if ty > fromPos.Y + 8 and p.Y < fromPos.Y + 2 then
                        score += 50
                    end
                    if not bestScore or score < bestScore then
                        best, bestScore = d, score
                    end
                end
            end
        end
    end
    return best
end

local function walkToSmart(pos)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 10,
        AgentMaxSlope = 89
    })
    path:ComputeAsync(hrp.Position, pos)
    if path.Status == Enum.PathStatus.Success then
        for _,wp in ipairs(path:GetWaypoints()) do
            hum:MoveTo(wp.Position)
            local ok = hum.MoveToFinished:Wait()
            if not ok then break end
        end
        if (hrp.Position - pos).Magnitude <= 6 then return true end
    end
    local rp = findBestRampPart_AllPlots(hrp.Position, pos)
    if rp then
        directRunTo(rp.Position, 4)
        task.wait(0.1)
    end
    return directRunTo(pos, CFG["Direct Move Timeout"] or 10)
end

local function backToBase()
    return walkToSmart(getSafeBasePos())
end

local function countDesiredInPods(plot)
    local pods = plot and plot:FindFirstChild("AnimalPodiums")
    if not pods then return 0 end
    local c = 0
    for _,s in ipairs(pods:GetChildren()) do
        local spawn = s:FindFirstChild("Base") and s.Base:FindFirstChild("Spawn")
        if not spawn then continue end
        local att = spawn:FindFirstChild("Attachment")
        local oh = att and att:FindFirstChild("AnimalOverhead")
        local dn = oh and oh:FindFirstChild("DisplayName")
        if dn then
            local t = tostring(dn.Text or "")
            if t ~= "" and nameMatch(t) then
                c += 1
            end
        end
    end
    return c
end

local function countDesiredModels(plot)
    if not plot then return 0 end
    local c = 0
    for _,d in ipairs(plot:GetDescendants()) do
        if d:IsA("Model") and nameMatch(d.Name) then
            c += 1
        end
    end
    return c
end

local function countDesiredOwned(plot)
    return countDesiredInPods(plot) + countDesiredModels(plot)
end

local function scanOwned(plot)
    local pods = plot and plot:FindFirstChild("AnimalPodiums")
    if not pods then return 0,{} end
    local occupied, list = 0, {}
    for _,s in ipairs(pods:GetChildren()) do
        local spawn = s:FindFirstChild("Base") and s.Base:FindFirstChild("Spawn")
        if not spawn then continue end
        local att = spawn:FindFirstChild("Attachment")
        local oh = att and att:FindFirstChild("AnimalOverhead")
        local dn = oh and oh:FindFirstChild("DisplayName")
        local rr = oh and oh:FindFirstChild("Rarity")
        if dn and rr then
            local dnT = tostring(dn.Text or "")
            local rrT = tostring(rr.Text or "")
            if dnT ~= "" and rrT ~= "" then
                occupied += 1
                list[#list+1] = {Name = dnT, Rarity = rrT}
            end
        end
    end
    return occupied, list
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
        local dnT = tostring(dn.Text or "")
        local rrT = tostring(rr.Text or "")
        if dnT == "" or rrT == "" then continue end

        local prompt
        local pa = spawn:FindFirstChild("PromptAttachment")
        if pa then
            for _,p in ipairs(pa:GetChildren()) do
                if p:IsA("ProximityPrompt") and p.ActionText == "Steal" and p.Enabled then
                    prompt = p
                    break
                end
            end
        end

        if prompt then
            list[#list+1] = {Name = dnT, Rarity = rrT, Root = spawn, Position = spawn.Position, Prompt = prompt, Kind = "Pod"}
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
    if CFG["Auto Game"]["Name"]["Enable"] then
        if countDesiredOwned(myPlot) > 0 then return true end
    end
    if CFG["Auto Game"]["Rarity"]["Enable"] then
        local _,list = scanOwned(myPlot)
        for _,i in ipairs(list) do
            if rarityMatch(i.Rarity) then return true end
        end
    end
    return false
end

local function findTarget()
    for _,p in ipairs(Plots:GetChildren()) do
        if p ~= myPlot then
            for _,info in ipairs(scanPods(p)) do
                if CFG["Auto Game"]["Name"]["Enable"] and nameMatch(info.Name) then
                    info.Plot = p
                    return info
                end
                if CFG["Auto Game"]["Rarity"]["Enable"] and rarityMatch(info.Rarity) then
                    info.Plot = p
                    return info
                end
            end
            if CFG["Auto Game"]["Name"]["Enable"] then
                local ms = scanModels(p)
                if #ms > 0 then
                    ms[1].Plot = p
                    return ms[1]
                end
            end
        end
    end
end

if not isMain() then
    while true do
        if not hasDesiredInMyBase() then
            safeWrite(lp.Name .. ".txt", "Completed-CloneSAB")
            break
        end
        task.wait(CFG["Clone Check Interval"] or 1)
    end
    return
end

local noTargetSince = nil

while true do
    if CFG["Auto Game"]["Name"]["Enable"] then
        local desiredCount = countDesiredOwned(myPlot)
        if desiredCount >= (CFG["Max slot"] or 10) then
            safeWrite(lp.Name .. ".txt", "Completed-Main")
            break
        end
    else
        local occupied = select(1, scanOwned(myPlot))
        if occupied >= (CFG["Max slot"] or 10) then
            safeWrite(lp.Name .. ".txt", "Completed-Main")
            break
        end
    end

    local target = findTarget()
    if not target then
        if not noTargetSince then noTargetSince = os.clock() end
        if (os.clock() - noTargetSince) >= (CFG["No Target Timeout"] or 60) then
            safeWrite(lp.Name .. ".txt", "Completed-Main")
            break
        end
        task.wait(0.5)
        continue
    end

    noTargetSince = nil

    walkToSmart(target.Position)
    task.wait(0.25)
    holdTarget(target)
    task.wait(0.3)
    backToBase()
    task.wait(0.5)
end

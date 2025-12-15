local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

local Plots = workspace:WaitForChild("Plots")

local AUTO_NAME_ENABLE = true
local AUTO_RARITY_ENABLE = false
local DESIRED_BRAINROTS = {"Secret Lucky Block", "Festive Lucky Block"}
local DESIRED_RARITIES = {"Mythic","Secret"}

local ACCOUNT_MAIN = {"dopro0","Dopro0"}
local MAX_SLOT = 10

local HOLD_BUFFER = 1
local CLONE_CHECK_INTERVAL = 1
local PROMPT_SEARCH_RADIUS = 18
local PROMPT_SEARCH_RADIUS_MAX = 60
local PROMPT_SEARCH_TIME = 0.5
local FALLBACK_USE_ANY_STEAL_PROMPT = true

local function safeWrite(name, content)
    pcall(function()
        if writefile then writefile(name, content) end
    end)
end

local function isMain()
    for _,v in ipairs(ACCOUNT_MAIN) do
        if v == lp.Name or v == lp.DisplayName then
            return true
        end
    end
    return false
end

local DesiredNames = {}
for _,n in ipairs(DESIRED_BRAINROTS) do
    DesiredNames[n] = true
end

local function nameMatch(n) return DesiredNames[n] == true end

local function rarityMatch(r)
    for _,v in ipairs(DESIRED_RARITIES) do
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

local function walkTo(pos)
    local path = PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true})
    path:ComputeAsync(hrp.Position,pos)
    if path.Status ~= Enum.PathStatus.Success then return false end
    for _,wp in ipairs(path:GetWaypoints()) do
        hum:MoveTo(wp.Position)
        hum.MoveToFinished:Wait()
    end
    return true
end

local function backToBase()
    return walkTo(myPlot:GetPivot().Position)
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
                if AUTO_NAME_ENABLE and nameMatch(info.Name) then
                    info.Plot = p
                    return info
                end
                if AUTO_RARITY_ENABLE and rarityMatch(info.Rarity) then
                    info.Plot = p
                    return info
                end
            end
            if AUTO_NAME_ENABLE then
                local ms = scanModels(p)
                if #ms > 0 then
                    ms[1].Plot = p
                    return ms[1]
                end
            end
        end
    end
end

local function holdPrompt(prompt)
    hum:Move(Vector3.zero)
    task.wait(0.05)
    local t = (prompt.HoldDuration or 0) + HOLD_BUFFER
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
    local r = PROMPT_SEARCH_RADIUS
    local rmax = PROMPT_SEARCH_RADIUS_MAX
    local searchTime = PROMPT_SEARCH_TIME

    while os.clock() - t0 < searchTime do
        local p = bestStealPromptNear(info.Name, r)
        if p then
            pcall(function() holdPrompt(p) end)
            return true
        end
        r = math.min(r + 6, rmax)
        task.wait(0.1)
    end

    if FALLBACK_USE_ANY_STEAL_PROMPT then
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
        if AUTO_NAME_ENABLE and nameMatch(i.Name) then return true end
        if AUTO_RARITY_ENABLE and rarityMatch(i.Rarity) then return true end
    end
    if AUTO_NAME_ENABLE then
        for _,d in ipairs(myPlot:GetDescendants()) do
            if d:IsA("Model") and nameMatch(d.Name) then return true end
        end
    end
    return false
end

if not isMain() then
    while true do
        if not hasDesiredInMyBase() then
            safeWrite(lp.Name .. ".txt", "Completed-CloneSAB")
            break
        end
        task.wait(CLONE_CHECK_INTERVAL)
    end
    return
end

while true do
    local occupied = select(1, scanOwned(myPlot))
    if occupied >= MAX_SLOT then
        safeWrite(lp.Name .. ".txt", "Completed-Main")
        break
    end

    local target = findTarget()
    if not target then
        safeWrite(lp.Name .. ".txt", "Completed-Main")
        break
    end

    walkTo(target.Position)
    task.wait(0.25)
    holdTarget(target)
    task.wait(0.3)
    backToBase()
    task.wait(0.5)
end

getgenv().Config = getgenv().Config or {
    ["Auto Game"] = {
        ["Rarity"] = {
            ["Enable"] = false,
            ["Name Rarity"] = {"Mythic","Secret"},
        },
        ["Name"] = {
            ["Enable"] = true,
            ["Name Brainrot"] = {"Bananita Dolphinita","Lucky Block","Festive Lucky Block","Admin Lucky Block"},
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

local BLACKLIST_SECONDS = 90
local WALK_TIMEOUT = 10
local WALK_RETRIES = 2
local DIRECT_WALK_TIMEOUT = 9
local STUCK_CHECK_INTERVAL = 0.35
local STUCK_DISTANCE_EPS = 0.15
local NEED_STAIR_DY = 10

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

local function moveToWait(pos, timeout)
    hum:MoveTo(pos)
    local done = false
    local conn
    conn = hum.MoveToFinished:Connect(function()
        done = true
        if conn then conn:Disconnect() end
    end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < (timeout or 6) do
        task.wait(0.03)
    end
    if conn then conn:Disconnect() end
    return done
end

local function computeWaypoints(fromPos, toPos)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 6,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 3
    })
    local ok = pcall(function()
        path:ComputeAsync(fromPos, toPos)
    end)
    if not ok or path.Status ~= Enum.PathStatus.Success then
        return nil
    end
    local wps = path:GetWaypoints()
    if not wps or #wps == 0 then
        return nil
    end
    return wps
end

local Blacklist = {}

local function mkKey(info)
    local p = info and info.Position
    if not p then return tostring(info and info.Name or "nil") end
    return tostring(info.Kind) .. "|" .. tostring(info.Name) .. "|" ..
        math.floor(p.X + 0.5) .. "," .. math.floor(p.Y + 0.5) .. "," .. math.floor(p.Z + 0.5)
end

local function isBlacklisted(info)
    local k = mkKey(info)
    local exp = Blacklist[k]
    if not exp then return false end
    if os.clock() >= exp then
        Blacklist[k] = nil
        return false
    end
    return true
end

local function blacklist(info, seconds)
    Blacklist[mkKey(info)] = os.clock() + (seconds or BLACKLIST_SECONDS)
end

local StairParts = {}

local function collectStairParts(plot)
    if StairParts[plot] then return StairParts[plot] end
    local parts = {}
    for _,d in ipairs(plot:GetDescendants()) do
        if d.Name == "Model" then
            if d:IsA("BasePart") then
                parts[#parts+1] = d
            else
                for _,x in ipairs(d:GetDescendants()) do
                    if x:IsA("BasePart") then
                        parts[#parts+1] = x
                    end
                end
            end
        end
    end
    StairParts[plot] = parts
    return parts
end

local function nearestStairPart(plot, fromPos)
    local parts = collectStairParts(plot)
    if not parts or #parts == 0 then return nil end
    local best, bestDist
    for _,pt in ipairs(parts) do
        if pt and pt.Parent then
            local dist = (fromPos - pt.Position).Magnitude
            if not bestDist or dist < bestDist then
                best, bestDist = pt, dist
            end
        end
    end
    return best
end

local function directWalkTo(pos, timeout)
    local t0 = os.clock()
    local lastPos = hrp.Position
    local lastMove = os.clock()

    while os.clock() - t0 < (timeout or DIRECT_WALK_TIMEOUT) do
        hum:MoveTo(pos)

        local nowPos = hrp.Position
        if (nowPos - pos).Magnitude <= 3.2 then
            return true
        end

        if (nowPos - lastPos).Magnitude > STUCK_DISTANCE_EPS then
            lastPos = nowPos
            lastMove = os.clock()
        else
            if os.clock() - lastMove > 0.9 then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                task.wait(0.05)
                hum:MoveTo(pos + Vector3.new(math.random(-2,2), 0, math.random(-2,2)))
                task.wait(0.12)
                lastMove = os.clock()
                lastPos = hrp.Position
            end
        end

        task.wait(STUCK_CHECK_INTERVAL)
    end

    return false
end

local function stairAssistWalk(plot, targetPos)
    local stair = nearestStairPart(plot, hrp.Position)
    if not stair then return false end

    local stairPos = stair.Position + Vector3.new(0, 2, 0)
    local okToStair = directWalkTo(stairPos, 6)
    if not okToStair then
        okToStair = moveToWait(stairPos, 4)
    end
    if not okToStair then return false end

    return directWalkTo(targetPos, DIRECT_WALK_TIMEOUT)
end

local function walkTo(pos, targetPlot)
    targetPlot = targetPlot or myPlot

    for _ = 1, WALK_RETRIES do
        local wps = computeWaypoints(hrp.Position, pos)
        if wps then
            local t0 = os.clock()
            for _,wp in ipairs(wps) do
                if os.clock() - t0 > WALK_TIMEOUT then break end
                if wp.Action == Enum.PathWaypointAction.Jump then
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                end
                local ok = moveToWait(wp.Position, 3.5)
                if not ok then break end
            end
            if (hrp.Position - pos).Magnitude <= 4 then
                return true
            end
        end

        if directWalkTo(pos, DIRECT_WALK_TIMEOUT) then
            return true
        end

        if (pos.Y - hrp.Position.Y) >= NEED_STAIR_DY then
            if stairAssistWalk(targetPlot, pos) then
                return true
            end
        end
    end

    return false
end

local function backToBase()
    return walkTo(myPlot:GetPivot().Position, myPlot)
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
            list[#list+1] = {Name = dn.Text, Rarity = rr.Text, Root = spawn, Position = spawn.Position, Prompt = prompt, Kind = "Pod", Plot = plot}
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
                list[#list+1] = {Name = d.Name, Root = d, Position = pos, Prompt = nil, Kind = "Model", Plot = plot}
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
        return
    end

    local t0 = os.clock()
    local r = CFG["Prompt Search Radius"] or 18
    local rmax = CFG["Prompt Search Radius Max"] or 60
    local searchTime = CFG["Prompt Search Time"] or 2.5

    while os.clock() - t0 < searchTime do
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

local function findTarget()
    for _,p in ipairs(Plots:GetChildren()) do
        if p ~= myPlot then
            for _,info in ipairs(scanPods(p)) do
                if not isBlacklisted(info) then
                    if CFG["Auto Game"]["Name"]["Enable"] and nameMatch(info.Name) then
                        return info
                    end
                    if CFG["Auto Game"]["Rarity"]["Enable"] and rarityMatch(info.Rarity) then
                        return info
                    end
                end
            end
            if CFG["Auto Game"]["Name"]["Enable"] then
                for _,m in ipairs(scanModels(p)) do
                    if not isBlacklisted(m) then
                        return m
                    end
                end
            end
        end
    end
end

if not ROLE_IS_MAIN then
    while true do
        if not hasDesiredInMyBase() then
            print("het brainrot")
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
        print("max slot")
        safeWrite(lp.Name .. ".txt", "Completed-Main")
        task.wait(1)
        game:Shutdown()
        break
    end

    local target = findTarget()
    if not target then
        print("ko co target")
        task.wait(1)
        continue
    end

    local okWalk = walkTo(target.Position, target.Plot or myPlot)
    if not okWalk then
        blacklist(target, BLACKLIST_SECONDS)
        task.wait(0.2)
        continue
    end

    task.wait(0.25)
    holdTarget(target)
    task.wait(0.3)
    backToBase()
    task.wait(0.5)
end

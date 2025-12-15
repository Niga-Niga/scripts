getgenv().Config = getgenv().Config or {
    ["Auto Game"] = {
        ["Rarity"] = {
            ["Enable"] = false,
            ["Name Rarity"] = {"Mythic","Secret"},
        },
        ["Name"] = {
            ["Enable"] = true,
            ["Name Brainrot"] = {"Bananita Dolphinita","Lucky Block"},
        }
    },
    ["Account Main"] = {"dopro0","Dopro0"},
    ["Max slot"] = 10,
    ["Hold Buffer"] = 1,
    ["Clone Check Interval"] = 1
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
        if writefile then
            writefile(name, content)
        end
    end)
end

local function isMain()
    local n, d = lp.Name, lp.DisplayName
    for _,v in ipairs(CFG["Account Main"] or {}) do
        if v == n or v == d then
            return true
        end
    end
    return false
end

local function nameMatch(n)
    for _,v in ipairs(CFG["Auto Game"]["Name"]["Name Brainrot"] or {}) do
        if n == v then return true end
    end
    return false
end

local function rarityMatch(r)
    for _,v in ipairs(CFG["Auto Game"]["Rarity"]["Name Rarity"] or {}) do
        if r == v then return true end
    end
    return false
end

local function scanOwned(plot)
    local pods = plot and plot:FindFirstChild("AnimalPodiums")
    if not pods then return 0, {} end
    local occupied, list = 0, {}
    for _,s in ipairs(pods:GetChildren()) do
        local spawn = s:FindFirstChild("Base") and s.Base:FindFirstChild("Spawn")
        if not spawn then continue end
        local att = spawn:FindFirstChild("Attachment")
        local oh = att and att:FindFirstChild("AnimalOverhead")
        local dn = oh and oh:FindFirstChild("DisplayName")
        local rr = oh and oh:FindFirstChild("Rarity")
        if dn and rr then
            occupied += 1
            list[#list+1] = {Name = dn.Text, Rarity = rr.Text, Pod = s, Root = spawn, Position = spawn.Position}
        end
    end
    return occupied, list
end

local function scanStealable(plot)
    local pods = plot and plot:FindFirstChild("AnimalPodiums")
    if not pods then return {} end
    local list = {}
    for _,s in ipairs(pods:GetChildren()) do
        local spawn = s:FindFirstChild("Base") and s.Base:FindFirstChild("Spawn")
        if not spawn then continue end
        local att = spawn:FindFirstChild("Attachment")
        local oh = att and att:FindFirstChild("AnimalOverhead")
        local dn = oh and oh:FindFirstChild("DisplayName")
        local rr = oh and oh:FindFirstChild("Rarity")
        if not (dn and rr) then continue end

        local pa = spawn:FindFirstChild("PromptAttachment")
        local prompt
        if pa then
            for _,p in ipairs(pa:GetChildren()) do
                if p:IsA("ProximityPrompt") and p.ActionText == "Steal" then
                    prompt = p
                    break
                end
            end
        end

        if prompt then
            list[#list+1] = {Name = dn.Text, Rarity = rr.Text, Prompt = prompt, Root = spawn, Position = spawn.Position, Pod = s}
        end
    end
    return list
end

local function getMyPlot()
    for _,p in ipairs(Plots:GetChildren()) do
        local yb = p:FindFirstChild("PlotSign") and p.PlotSign:FindFirstChild("YourBase")
        if yb and yb.Enabled then
            return p
        end
    end
end

local myPlot = getMyPlot()
if not myPlot then
    return
end

local function walkTo(pos)
    local path = PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true})
    path:ComputeAsync(hrp.Position, pos)
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

local function findTarget()
    for _,p in ipairs(Plots:GetChildren()) do
        local list = scanStealable(p)
        for _,info in ipairs(list) do
            if CFG["Auto Game"]["Name"]["Enable"] and nameMatch(info.Name) then
                return info
            end
            if CFG["Auto Game"]["Rarity"]["Enable"] and rarityMatch(info.Rarity) then
                return info
            end
        end
    end
end

local function holdPrompt(info)
    local prompt = info and info.Prompt
    local root = info and info.Root
    if not prompt or not prompt.Enabled or not root then return false end
    if (hrp.Position - root.Position).Magnitude > (prompt.MaxActivationDistance or 10) then
        return false
    end
    hum:Move(Vector3.zero)
    task.wait(0.05)
    local t = (prompt.HoldDuration or 0) + (CFG["Hold Buffer"] or 1)
    local ok = pcall(function()
        prompt:InputHoldBegin()
        task.wait(t)
        prompt:InputHoldEnd()
    end)
    return ok
end

local function hasDesiredInMyBase()
    local _, list = scanOwned(myPlot)
    for _,info in ipairs(list) do
        if CFG["Auto Game"]["Name"]["Enable"] and nameMatch(info.Name) then
            return true
        end
        if CFG["Auto Game"]["Rarity"]["Enable"] and rarityMatch(info.Rarity) then
            return true
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
        task.wait(CFG["Clone Check Interval"] or 1)
    end
    return
end

while true do
    local occupied = select(1, scanOwned(myPlot))
    if occupied >= (CFG["Max slot"] or 10) then
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
    holdPrompt(target)
    task.wait(0.3)
    backToBase()
    task.wait(0.5)
end

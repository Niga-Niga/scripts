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
    ["Clone Check Interval"] = 1,
    ["Model Hold Time"] = 3
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
    for _,v in ipairs(CFG["Account Main"] or {}) do
        if v == lp.Name or v == lp.DisplayName then
            return true
        end
    end
    return false
end

local DesiredNames = {}
for _,n in ipairs(CFG["Auto Game"]["Name"]["Name Brainrot"] or {}) do
    DesiredNames[n] = true
end

local function nameMatch(n)
    return DesiredNames[n] == true
end

local function rarityMatch(r)
    for _,v in ipairs(CFG["Auto Game"]["Rarity"]["Name Rarity"] or {}) do
        if r == v then return true end
    end
    return false
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
        if dn and rr then
            list[#list+1] = {
                Name = dn.Text,
                Rarity = rr.Text,
                Root = spawn,
                Position = spawn.Position,
                Prompt = spawn:FindFirstChild("PromptAttachment") and spawn.PromptAttachment:FindFirstChildWhichIsA("ProximityPrompt")
            }
        end
    end
    return list
end

local function scanModels(plot)
    local list = {}
    for _,d in ipairs(plot:GetDescendants()) do
        if d:IsA("Model") and nameMatch(d.Name) then
            local cf = d:GetPivot()
            list[#list+1] = {
                Name = d.Name,
                Rarity = nil,
                Root = d,
                Position = cf.Position,
                Prompt = nil,
                IsModel = true
            }
        end
    end
    return list
end

local function findTarget()
    for _,p in ipairs(Plots:GetChildren()) do
        for _,info in ipairs(scanPods(p)) do
            if CFG["Auto Game"]["Name"]["Enable"] and nameMatch(info.Name) then
                return info
            end
            if CFG["Auto Game"]["Rarity"]["Enable"] and rarityMatch(info.Rarity) then
                return info
            end
        end
        for _,info in ipairs(scanModels(p)) do
            return info
        end
    end
end

local function holdTarget(info)
    hum:Move(Vector3.zero)
    task.wait(0.05)
    if info.Prompt then
        local t = (info.Prompt.HoldDuration or 0) + (CFG["Hold Buffer"] or 1)
        info.Prompt:InputHoldBegin()
        task.wait(t)
        info.Prompt:InputHoldEnd()
    else
        task.wait(CFG["Model Hold Time"] or 3)
    end
end

local function hasDesiredInMyBase()
    local _,list = scanOwned(myPlot)
    for _,i in ipairs(list) do
        if CFG["Auto Game"]["Name"]["Enable"] and nameMatch(i.Name) then
            return true
        end
        if CFG["Auto Game"]["Rarity"]["Enable"] and rarityMatch(i.Rarity) then
            return true
        end
    end
    for _,d in ipairs(myPlot:GetDescendants()) do
        if d:IsA("Model") and nameMatch(d.Name) then
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
    if occupied >= CFG["Max slot"] then
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

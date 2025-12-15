
getgenv().Config = {
    ["Auto Game"] = {
        ["Rarity"] = {
            ["Enable"] = false,
            ["Name Rarity"] = {"Mythic","Secret"},
        },
        ["Name"] = {
            ["Enable"] = true,
            ["Name Brainrot"] = {"Lucky Block"},
        }
    },
    ["Account Main"] = {"dopro0","Dopro0"},
    ["Max slot"] = 10
}

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

local CFG = getgenv().Config
local Plots = workspace:WaitForChild("Plots")

local function isMain()
    for _,v in ipairs(CFG["Account Main"]) do
        if plr.Name == v then
            return true
        end
    end
    return false
end

local IS_MAIN = isMain()

local function getMyPlot()
    for _,p in ipairs(Plots:GetChildren()) do
        if p:FindFirstChild("Owner") and p.Owner.Value == plr then
            return p
        end
    end
end

local myPlot
repeat
    myPlot = getMyPlot()
    task.wait(1)
until myPlot

local function scanPlot(plot)
    local pods = plot:FindFirstChild("AnimalPodiums")
    if not pods then return 0,0,{} end
    local cur,max,out = 0,0,{}
    for _,s in ipairs(pods:GetChildren()) do
        local n = tonumber(s.Name)
        if n and n > max then max = n end
        local a = s:FindFirstChild("Base") and s.Base:FindFirstChild("Spawn") and s.Base.Spawn:FindFirstChild("Attachment")
        if a then
            cur += 1
            local oh = a:FindFirstChild("AnimalOverhead")
            local dn, rr = oh and oh:FindFirstChild("DisplayName"), oh and oh:FindFirstChild("Rarity")
            if dn and rr then
                out[#out+1] = {Name = dn.Text, Rarity = rr.Text}
            end
        end
    end
    return cur,max,out
end

local function baseHasAnyTarget()
    local _,_,list = scanPlot(myPlot)
    for _,it in ipairs(list) do
        if CFG["Auto Game"]["Name"]["Enable"] then
            for _,n in ipairs(CFG["Auto Game"]["Name"]["Name Brainrot"]) do
                if it.Name == n then
                    return true
                end
            end
        end
        if CFG["Auto Game"]["Rarity"]["Enable"] then
            for _,r in ipairs(CFG["Auto Game"]["Rarity"]["Name Rarity"]) do
                if it.Rarity == r then
                    return true
                end
            end
        end
    end
    return false
end

local function walkTo(pos)
    hum:MoveTo(pos)
    hum.MoveToFinished:Wait()
end

local function holdPrompt(p)
    ProximityPromptService:PromptButtonHoldBegan(p)
    task.wait(p.HoldDuration + 0.2)
    ProximityPromptService:PromptButtonHoldEnded(p)
end

local function findTarget()
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled then
            if CFG["Auto Game"]["Name"]["Enable"] then
                for _,n in ipairs(CFG["Auto Game"]["Name"]["Name Brainrot"]) do
                    if v.Parent and v.Parent.Name == n then
                        return v
                    end
                end
            end
        end
    end
end

if not IS_MAIN then
    while true do
        if myPlot and not baseHasAnyTarget() then
            writefile(plr.Name .. ".txt", "Completed-CloneSAB")
            break
        end
        task.wait(2)
    end
    return
end

while true do
    local cur = select(1, scanPlot(myPlot))
    if cur >= CFG["Max slot"] then
        writefile(plr.Name .. ".txt", "Completed-Main")
        break
    end
    local target = findTarget()
    if not target then
        writefile(plr.Name .. ".txt", "Completed-Main")
        break
    end
    walkTo(target.Parent.Position)
    holdPrompt(target)
    task.wait(0.3)
end

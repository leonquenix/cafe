--!strict
-- Posiciona o personagem atrás do balcão, parado, com um aventalzinho.
-- No modo andar (fora do expediente) o personagem fica livre pelo café.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)

local Barista = {}

local function addApron(character: Model)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local apron = Instance.new("Part")
	apron.Name = "Apron"
	apron.Size = Vector3.new(torso.Size.X * 0.8, torso.Size.Y * 1.3, 0.1)
	apron.Color = Color3.fromRGB(150, 182, 150)
	apron.Material = Enum.Material.SmoothPlastic
	apron.CanCollide = false
	apron.Massless = true
	apron.CFrame = torso.CFrame * CFrame.new(0, -torso.Size.Y * 0.3, -torso.Size.Z / 2 - 0.06)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = apron
	weld.Parent = apron
	apron.Parent = character
end

local walking: { [Player]: boolean } = {}

local function spotFor(player: Player): Vector3
	-- vários jogadores ficam lado a lado atrás do balcão
	local index = table.find(Players:GetPlayers(), player) or 1
	return Layout.BaristaSpot + Vector3.new(-(index - 1) * 2.6, 0, 0)
end

local function park(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local feet = spotFor(player)
	local height = humanoid.HipHeight + root.Size.Y / 2
	local pos = feet + Vector3.new(0, height, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)))
	root.Anchored = true
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	player.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
	player.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
end

local function onCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not root or not humanoid then
		return
	end
	walking[player] = nil
	park(player, character)
	addApron(character)
end

-- Libera (ou trava de volta atrás do balcão) o personagem
function Barista.setWalking(player: Player, on: boolean)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	if on then
		walking[player] = true
		root.Anchored = false
		humanoid.WalkSpeed = 14
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = 5
		player.DevComputerMovementMode = Enum.DevComputerMovementMode.UserChoice
		player.DevTouchMovementMode = Enum.DevTouchMovementMode.UserChoice
	else
		walking[player] = nil
		park(player, character)
	end
end

function Barista.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		walking[player] = nil
	end)
end

return Barista

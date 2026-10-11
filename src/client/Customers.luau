--!strict
-- Fila de clientes (só no cliente: cada jogador vê a própria fila).
-- O servidor manda o plano do dia (quem vem, em ordem); aqui eles entram, fazem fila,
-- pedem no balcão, recebem a bebida e vão embora.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Characters = require(ReplicatedStorage.Shared.Characters)
local Layout = require(ReplicatedStorage.Shared.Layout)
local CustomerModel = require(script.Parent.Art.CustomerModel)
local Bubble = require(script.Parent.UI.Bubble)

type Waypoint = { Position: Vector3, Tag: string? }
export type PlanEntry = { kind: number, regular: number }

export type Customer = {
	Uid: number,
	Index: number, -- posição no plano do dia (id enviado ao servidor)
	Kind: number,
	Regular: number,
	Art: CustomerModel.CustomerModel,
	Position: Vector3,
	Yaw: number,
	TargetYaw: number,
	Path: { Waypoint },
	Inside: boolean,
	Leaving: boolean,
	Ordered: boolean,
	WalkTime: number,
	Speed: number,
	Bubble: BillboardGui?,
}

local WALK_SPEED = 8
local ADVANCE_DELAY = 0.35 -- espera o atendido sair do balcão antes da fila andar
local rng = Random.new()
local Kind = Characters.Kind

local Customers = {}

local container: Folder
local queue: { Customer } = {}
local all: { [number]: Customer } = {}
local nextUid = 0
local onFrontReady: ((Customer) -> ())? = nil

local dayRunning = false
local plan: { PlanEntry } = {}
local nextIndex = 1

local function yawOf(dir: Vector3): number
	return math.atan2(-dir.X, -dir.Z)
end

local FACE_COUNTER = yawOf(Vector3.new(0, 0, 1))

local function slotPath(c: Customer, index: number): { Waypoint }
	local slot = { Position = Layout.queueSlot(index), Tag = "slot" }
	if c.Inside then
		return { slot }
	end
	return {
		{ Position = Layout.Entrance, Tag = "entrance" },
		{ Position = Layout.QueueEntry },
		slot,
	}
end

local function advanceQueue()
	for i, other in queue do
		other.Path = slotPath(other, i)
	end
end

local function checkFront()
	local front = queue[1]
	if front and not front.Ordered and #front.Path == 0 then
		front.Ordered = true
		if onFrontReady then
			onFrontReady(front)
		end
	end
end

local function remove(c: Customer)
	all[c.Uid] = nil
	for _, p in c.Art.Model:GetChildren() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			TweenService:Create(p, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end
	task.delay(0.45, function()
		c.Art.Model:Destroy()
	end)
end

local function leave(c: Customer)
	c.Path = {
		{ Position = Layout.ExitLane[1] },
		{ Position = Layout.ExitLane[2] },
		{ Position = Layout.Entrance },
		{ Position = Layout.Outside, Tag = "exit" },
	}
end

local function spawnCustomer(index: number, entry: PlanEntry)
	nextUid += 1
	local style: CustomerModel.Style = "Normal"
	local artRng = rng
	local look: Characters.Look? = nil
	if entry.kind == Kind.Kid then
		style = "Kid"
	elseif entry.kind == Kind.Critic then
		style = "Critic"
	elseif entry.kind == Kind.Regular then
		style = "Regular"
		local r = Characters.Regulars[entry.regular]
		if r then
			artRng = Random.new(r.Seed)
			look = r.Look
		end
	end
	local art = CustomerModel.build(artRng, style, look)

	local c: Customer = {
		Uid = nextUid,
		Index = index,
		Kind = entry.kind,
		Regular = entry.regular,
		Art = art,
		Position = Layout.Outside + Vector3.new(rng:NextNumber(-1, 1), 0, 0),
		Yaw = 0,
		TargetYaw = 0,
		Path = {},
		Inside = false,
		Leaving = false,
		Ordered = false,
		WalkTime = rng:NextNumber(0, 10),
		Speed = WALK_SPEED * rng:NextNumber(0.9, 1.1) * (if entry.kind == Kind.Kid or (look and look.Kid) then 1.15 else 1),
		Bubble = nil,
	}
	all[c.Uid] = c
	table.insert(queue, c)
	c.Path = slotPath(c, #queue)
	art.Model.Parent = container
end

local function animate(c: Customer, dt: number)
	local moving = false
	local target = c.Path[1]
	if target then
		local delta = (target.Position - c.Position) * Vector3.new(1, 0, 1)
		local dist = delta.Magnitude
		local step = c.Speed * dt
		if dist <= step then
			c.Position = target.Position
			table.remove(c.Path, 1)
			if target.Tag == "entrance" then
				c.Inside = true
			elseif target.Tag == "exit" then
				remove(c)
				return
			end
			if #c.Path == 0 then
				c.TargetYaw = FACE_COUNTER
				if not c.Leaving then
					checkFront()
				end
			end
		else
			c.Position += delta.Unit * step
			c.TargetYaw = yawOf(delta.Unit)
			moving = true
		end
	end

	local diff = (c.TargetYaw - c.Yaw + math.pi) % (2 * math.pi) - math.pi
	c.Yaw += diff * math.min(1, dt * 10)

	local swing, bob
	if moving then
		c.WalkTime += dt * (if c.Kind == Kind.Kid then 12 else 9)
		swing = math.sin(c.WalkTime) * 0.55
		bob = math.abs(math.sin(c.WalkTime)) * 0.18
	else
		c.WalkTime += dt * 2
		swing = 0
		bob = math.sin(c.WalkTime) * 0.04
	end

	local root = CFrame.new(c.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, c.Yaw, 0)
	local parts, cframes = {}, {}
	for i, limb in c.Art.Limbs do
		parts[i] = limb.Part
		cframes[i] = root * limb.Pivot * CFrame.Angles(swing * limb.Swing, 0, 0) * limb.Offset
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function Customers.get(index: number): Customer?
	for _, c in queue do
		if c.Index == index then
			return c
		end
	end
	return nil
end

function Customers.front(): Customer?
	return queue[1]
end

function Customers.showOrder(c: Customer, info: Bubble.OrderInfo)
	if c.Bubble then
		c.Bubble:Destroy()
	end
	c.Bubble = Bubble.order(c.Art.Head, info)
end

-- Entrega a bebida ao cliente da frente: ele dá um passo pro lado, reage e vai embora.
-- happy = false quando a bebida veio errada (ele leva mesmo assim, mas sem pagar).
function Customers.serveFront(drinkColor: Color3, thanks: string?, happy: boolean?)
	local c = table.remove(queue, 1)
	if not c then
		return
	end
	if c.Bubble then
		Bubble.pop(c.Bubble)
	end
	c.Art.Cup.Transparency = 0
	c.Art.Cup.Color = drinkColor:Lerp(Color3.new(1, 1, 1), 0.15)
	c.Leaving = true
	c.Path = { { Position = Layout.PickupSpot } }

	local reaction = if happy == false then Bubble.sad(c.Art.Head, thanks) else Bubble.heart(c.Art.Head, thanks)
	c.Bubble = reaction

	task.delay(1.4, function()
		Bubble.pop(reaction)
		leave(c)
	end)

	task.delay(ADVANCE_DELAY, advanceQueue)
end

-- Fim do dia forçado: todo mundo na fila recebe a bebida e vai embora feliz
function Customers.dismissAll()
	while #queue > 0 do
		Customers.serveFront(Color3.fromRGB(190, 150, 110), "Obrigado!", true)
	end
end

function Customers.beginDay(dayPlan: { PlanEntry }, alreadyResolved: number)
	plan = dayPlan
	nextIndex = alreadyResolved + 1
	dayRunning = true
end

function Customers.endDay()
	dayRunning = false
end

function Customers.start(frontReady: (Customer) -> ())
	onFrontReady = frontReady
	container = Instance.new("Folder")
	container.Name = "Customers"
	container.Parent = workspace

	RunService.Heartbeat:Connect(function(dt)
		for _, c in all do
			animate(c, dt)
		end
	end)

	-- cadência: fila curta enche rápido, fila cheia desacelera
	task.spawn(function()
		while true do
			if dayRunning and nextIndex <= #plan and #queue < Layout.MaxQueue then
				spawnCustomer(nextIndex, plan[nextIndex])
				nextIndex += 1
				local n = #queue
				local gap = if n <= 1 then rng:NextNumber(1, 1.6) elseif n == 2 then rng:NextNumber(2.2, 3.4) else rng:NextNumber(3.5, 5)
				task.wait(gap)
			else
				task.wait(0.25)
			end
		end
	end)
end

return Customers

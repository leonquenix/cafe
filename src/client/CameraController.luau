--!strict
-- Câmera fixa olhando o balcão, com um balanço bem sutil pra dar vida.
-- focus()/release() fazem a câmera voar até um ponto (ex.: decoração nova) e voltar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Layout = require(ReplicatedStorage.Shared.Layout)

local CameraController = {}

type Shot = { CFrame: CFrame, FieldOfView: number }
type Move = { From: Shot, To: Shot, Start: number, Duration: number }

local move: Move? = nil
local holding: Shot? = nil -- enquanto focado, fica parado aqui

local function defaultShot(): Shot
	local cfg = Layout.Camera
	local t = os.clock()
	local sway = Vector3.new(math.sin(t * 0.35) * 0.08, math.sin(t * 0.5) * 0.05, 0)
	return { CFrame = CFrame.lookAt(cfg.Position + sway, cfg.LookAt), FieldOfView = cfg.FieldOfView }
end

local function ease(a: number): number
	return a * a * (3 - 2 * a) -- smoothstep
end

local function currentShot(): Shot
	local camera = workspace.CurrentCamera
	return { CFrame = camera.CFrame, FieldOfView = camera.FieldOfView }
end

-- Voa até olhar `target` a partir de `position`
function CameraController.focus(position: Vector3, target: Vector3, duration: number?, fov: number?)
	local to = { CFrame = CFrame.lookAt(position, target), FieldOfView = fov or 55 }
	move = { From = currentShot(), To = to, Start = os.clock(), Duration = math.max(duration or 1.2, 0.001) }
	holding = to
end

-- Volta pro enquadramento normal
function CameraController.release(duration: number?)
	move = { From = currentShot(), To = defaultShot(), Start = os.clock(), Duration = math.max(duration or 1, 0.001) }
	holding = nil
end

local suspended = false

-- Entrega a câmera pro Roblox (modo andar): segue o personagem normalmente
function CameraController.suspend()
	suspended = true
	local camera = workspace.CurrentCamera
	local player = game:GetService("Players").LocalPlayer
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
	camera.FieldOfView = 70
end

-- Volta pra câmera fixa, voando suavemente de onde estiver
function CameraController.resume(duration: number?)
	suspended = false
	CameraController.release(duration or 1.2)
end

function CameraController.start()
	RunService:BindToRenderStep("CafeCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		if not camera or suspended then
			return
		end
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end

		local shot: Shot
		local m = move
		if m then
			local a = math.min(1, (os.clock() - m.Start) / m.Duration)
			local to = if holding then m.To else defaultShot() -- ao voltar, persegue o balanço atual
			local k = ease(a)
			shot = {
				CFrame = m.From.CFrame:Lerp(to.CFrame, k),
				FieldOfView = m.From.FieldOfView + (to.FieldOfView - m.From.FieldOfView) * k,
			}
			if a >= 1 then
				move = nil
			end
		elseif holding then
			shot = holding
		else
			shot = defaultShot()
		end
		camera.CFrame = shot.CFrame
		camera.FieldOfView = shot.FieldOfView
	end)
end

return CameraController

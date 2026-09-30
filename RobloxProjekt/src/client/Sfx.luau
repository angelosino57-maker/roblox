-- Kurze UI-/Effekt-Sounds (lokal). Sfx.play(name, volume, pitch)
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local Sfx = {}

local cache = {}

function Sfx.play(name: string, volume: number?, pitch: number?)
	local id = Sounds[name]
	if id == nil then
		return
	end
	local template = cache[name]
	if template == nil then
		template = Instance.new("Sound")
		template.SoundId = id
		template.Parent = SoundService
		cache[name] = template
	end
	local sound = template:Clone()
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(3, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

return Sfx

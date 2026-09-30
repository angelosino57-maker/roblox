-- Lage der Gärten um den Platz und Positionen darin (reine Geometrie).
-- Jeder Garten schaut mit seinem Eingang (lokal -Z) zur Mitte.
local BaseLayout = {}

BaseLayout.CELL = 110
BaseLayout.SIZE = 90 -- Kantenlänge eines Gartens
BaseLayout.GRID = { { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, { 0, 1 }, { 1, 1 } }
BaseLayout.COUNT = #BaseLayout.GRID
BaseLayout.GATE_WIDTH = 14
BaseLayout.PODIUMS = 3

local HALF = BaseLayout.SIZE / 2

function BaseLayout.center(i: number): Vector3
	local g = BaseLayout.GRID[i]
	return Vector3.new(g[1] * BaseLayout.CELL, 0, g[2] * BaseLayout.CELL)
end

-- Achsparallel: Seitengärten schauen zur Mitte, Eckgärten in Z-Richtung zur Mitte.
function BaseLayout.frame(i: number): CFrame
	local g = BaseLayout.GRID[i]
	local front = if g[2] ~= 0 then Vector3.new(0, 0, -g[2]) else Vector3.new(-g[1], 0, 0)
	local center = BaseLayout.center(i)
	return CFrame.lookAt(center, center + front)
end

-- Die Wolke schwebt in der Gartenmitte, etwas nach hinten versetzt.
function BaseLayout.cloud(i: number): CFrame
	return BaseLayout.frame(i) * CFrame.new(0, 18, 10)
end

-- Kissen vor der Wolke (Blick zur Wolke).
function BaseLayout.seat(i: number): CFrame
	return BaseLayout.frame(i) * CFrame.new(0, 0, -6) * CFrame.Angles(0, math.pi, 0)
end

-- Hier landen die Brainrots, zwischen Kissen und Wolke.
function BaseLayout.drop(i: number): CFrame
	return BaseLayout.frame(i) * CFrame.new(0, 0, 4)
end

-- Podeste für die 3 ausgerüsteten Brainrots, hinter der Wolke.
function BaseLayout.podium(i: number, k: number): CFrame
	return BaseLayout.frame(i) * CFrame.new((k - 2) * 14, 0, 28)
end

function BaseLayout.gate(i: number): CFrame
	return BaseLayout.frame(i) * CFrame.new(0, 0, -HALF)
end

function BaseLayout.sign(i: number): CFrame
	return BaseLayout.frame(i) * CFrame.new(-12, 0, -HALF - 2)
end

function BaseLayout.spawnPoint(i: number): Vector3
	return (BaseLayout.frame(i) * CFrame.new(0, 3, -22)).Position
end

function BaseLayout.contains(i: number, position: Vector3): boolean
	local p = BaseLayout.frame(i):PointToObjectSpace(position)
	return math.abs(p.X) <= HALF and math.abs(p.Z) <= HALF and p.Y > -3 and p.Y < 60
end

function BaseLayout.baseAt(position: Vector3): number?
	for i = 1, BaseLayout.COUNT do
		if BaseLayout.contains(i, position) then
			return i
		end
	end
	return nil
end

return BaseLayout

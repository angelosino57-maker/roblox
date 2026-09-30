-- Reine Logik der Brainrot-Wolke: Drops würfeln, Einkommen, Glück, Tempo, Upgrade-Preise.
local Config = require(script.Parent.Config.Cloud)
local Rarity = require(script.Parent.Config.Rarity)
local Species = require(script.Parent.Config.Species)
local Mutations = require(script.Parent.Config.Mutations)
local Loot = require(script.Parent.Loot)

local Cloud = {}

-- Sekunden zwischen zwei Drops beim Knien (Tempo-Stufe, Event-Faktor).
function Cloud.interval(speedLevel: number, event: number?): number
	return math.max(Config.MIN_INTERVAL, Config.BASE_INTERVAL * Config.upgrades.speed.step ^ speedLevel) / (event or 1)
end

-- Auto-Farm: langsamer als Knien, jede weitere Stufe schneller; nil ohne Auto-Farm.
function Cloud.autoInterval(speedLevel: number, autoLevel: number, event: number?): number?
	if autoLevel <= 0 then
		return nil
	end
	return Cloud.interval(speedLevel, event) * Config.AUTO_SLOWER / (1 + 0.5 * (autoLevel - 1))
end

function Cloud.upgradePrice(kind: string, level: number): number?
	local u = Config.upgrades[kind]
	if u == nil or level >= u.max then
		return nil
	end
	return math.floor(u.price * u.growth ^ level)
end

-- Geld pro Sekunde eines Brainrots (Seltenheit × Form).
function Cloud.income(creature): number
	local form = creature.mutation and Mutations.byId[creature.mutation]
	return Config.income[creature.rarity] * (if form then form.money else 1)
end

function Cloud.totalIncome(data): number
	local total = 0
	for _, id in data.equipped do
		local creature = data.creatures[id]
		if creature then
			total += Cloud.income(creature)
		end
	end
	return total
end

function Cloud.skipValue(creature): number
	return Cloud.income(creature) * Config.SKIP_FACTOR
end

-- Glück: Wolken-Stufe × Diamant/Regenbogen-Brainrots im Team × Bonus (König, Event).
function Cloud.luck(data, bonus: number?): number
	local formLuck = 0
	for _, id in data.equipped do
		local creature = data.creatures[id]
		local form = creature and creature.mutation and Mutations.byId[creature.mutation]
		if form then
			formLuck += form.luck
		end
	end
	return (1 + data.cloud.luck * Config.upgrades.luck.step) * (1 + formLuck) * (bonus or 1)
end

-- Ein Drop: Seltenheit (mit Glück), Art passend zur Seltenheit, vielleicht eine Form.
function Cloud.roll(rng: Random, luck: number, formBoost: number?)
	local rarity = Loot.pick(Config.drops, rng, luck).rarity
	local pool = Species.byRarity[rarity]
	local mutation = nil
	for i = #Mutations.list, 1, -1 do -- seltenste Form zuerst
		local form = Mutations.list[i]
		if rng:NextNumber() < form.chance * (formBoost or 1) then
			mutation = form.id
			break
		end
	end
	return { species = pool[rng:NextInteger(1, #pool)], rarity = rarity, mutation = mutation }
end

-- Wie lange die Wolke vor der Enthüllung Spannung aufbaut (seltener = länger).
function Cloud.revealSeconds(creature): number
	return Config.reveal[creature.rarity] + (if creature.mutation then Config.REVEAL_FORM_BONUS else 0)
end

-- Nächster Drop nach einer Entscheidung: Das Tempo-Intervall seit dem letzten Drop gilt weiter,
-- schnelles Entscheiden überspringt es nicht. Nur eine kurze Pause kommt mindestens dazu.
function Cloud.nextDropAfterChoice(due: number?, now: number): number
	return math.max(due or now, now + Config.CHOICE_PAUSE)
end

-- Auto-Farm verkauft gewöhnliche Drops selbst; gute (Selten+ oder mit Form) muss der Spieler holen.
function Cloud.autoSells(creature): boolean
	return creature.mutation == nil and Rarity.index(creature.rarity) < Rarity.index(Config.AUTO_WAIT_FROM)
end

-- Wie viele Brainrots passen insgesamt (Podeste + Rucksack)?
function Cloud.capacity(): number
	return Config.EQUIP_MAX + Config.BAG_MAX
end

return Cloud

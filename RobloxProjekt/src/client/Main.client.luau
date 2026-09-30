local Client = script.Parent

local ClientState = require(Client.ClientState)
local Hud = require(Client.UI.Hud)
local DropCard = require(Client.UI.DropCard)
local CreaturePanel = require(Client.UI.CreaturePanel)
local HelpPanel = require(Client.UI.HelpPanel)
local FomoWidget = require(Client.UI.FomoWidget)
local EffectsController = require(Client.Controllers.EffectsController)
local CreatureMotion = require(Client.Controllers.CreatureMotion)

Hud.start()
DropCard.start()
CreaturePanel.start()
HelpPanel.start()
ClientState.start()
EffectsController.start()
CreatureMotion.start()
task.spawn(FomoWidget.start)

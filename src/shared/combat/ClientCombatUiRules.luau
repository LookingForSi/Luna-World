--!strict

local ClientCombatUiRules = {}
local ArchetypeDefinitions = require(script.Parent.Parent.definitions.ArchetypeDefinitions)

local REJECTION_TEXT = table.freeze({
	Cooldown = "Действие ещё не готово",
	InvalidTarget = "Недопустимая цель",
	OutOfRange = "Цель слишком далеко",
	InsufficientResource = "Недостаточно ресурса",
	ForbiddenState = "Сейчас действие недоступно",
	RateLimited = "Слишком частый ввод",
})

function ClientCombatUiRules.getSkills(archetypeId: unknown): { string }
	if typeof(archetypeId) ~= "string" then return {} end
	local definition = ArchetypeDefinitions[archetypeId]
	if definition == nil then return {} end
	return table.clone(definition.skillIds)
end

function ClientCombatUiRules.canonicalPlayerTargetId(userId: unknown): string?
	if typeof(userId) ~= "number" or userId ~= userId or math.abs(userId) == math.huge or userId % 1 ~= 0 or userId == 0 then return nil end
	return "player:" .. tostring(userId)
end

function ClientCombatUiRules.shouldIgnoreForGuiNavigation(inputTypeName: unknown, hasSelectedObject: boolean): boolean
	return typeof(inputTypeName) == "string"
		and string.sub(inputTypeName, 1, 7) == "Gamepad"
		and hasSelectedObject
end

function ClientCombatUiRules.getRejectionText(reasonCode: unknown): string?
	if typeof(reasonCode) ~= "string" then return nil end
	return REJECTION_TEXT[reasonCode]
end

function ClientCombatUiRules.getTouchProbeOffsets(radius: number): { Vector2 }
	local safeRadius = math.max(0, radius)
	return {
		Vector2.zero,
		Vector2.new(safeRadius, 0),
		Vector2.new(-safeRadius, 0),
		Vector2.new(0, safeRadius),
		Vector2.new(0, -safeRadius),
	}
end

function ClientCombatUiRules.screenRectDistance(
	point: Vector2,
	minimum: Vector2,
	maximum: Vector2,
	padding: number
): number
	local safePadding = math.max(0, padding)
	local minX = math.min(minimum.X, maximum.X) - safePadding
	local maxX = math.max(minimum.X, maximum.X) + safePadding
	local minY = math.min(minimum.Y, maximum.Y) - safePadding
	local maxY = math.max(minimum.Y, maximum.Y) + safePadding
	local dx = math.max(minX - point.X, 0, point.X - maxX)
	local dy = math.max(minY - point.Y, 0, point.Y - maxY)
	return math.sqrt(dx * dx + dy * dy)
end

return table.freeze(ClientCombatUiRules)

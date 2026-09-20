--!strict

local ClientCombatLogRules = {}

function ClientCombatLogRules.isRelevant(message: { actorEntityId: string?, targetEntityId: string? }, localEntityId: string): boolean
	return message.actorEntityId == localEntityId or message.targetEntityId == localEntityId
end

function ClientCombatLogRules.formatAmount(amount: number): string
	local rounded = math.round(amount * 10) / 10
	if rounded % 1 == 0 then return tostring(math.floor(rounded)) end
	return string.format("%.1f", rounded)
end

function ClientCombatLogRules.rejectionText(reasonCode: string?): string
	local messages = {
		Cooldown = "перезарядка",
		InvalidTarget = "неверная цель",
		OutOfRange = "цель слишком далеко",
		InsufficientResource = "не хватает ресурса",
		ForbiddenState = "действие сейчас недоступно",
		RateLimited = "слишком частые команды",
	}
	return messages[reasonCode or ""] or "неизвестная причина"
end

return table.freeze(ClientCombatLogRules)

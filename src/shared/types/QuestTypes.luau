--!strict
export type Objective = { id: string, displayText: string, kind: string, required: number, mobId: string?, npcId: string?, poiId: string?, radius: number?, waypointPoiId: string? }
export type Definition = { id: string, displayName: string, description: string, giverNpcId: string, turnInNpcId: string, prerequisiteQuestIds: { string }, objectives: { Objective }, rewardXP: number, rewardLuna: number, autoTurnIn: boolean? }
return table.freeze({})

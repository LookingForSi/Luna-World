#!/usr/bin/env python3
"""Static hostile-input, lifecycle, and canonical-reward guard for M5."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
service=(ROOT/'src/server/features/party/PartyService.luau').read_text()
network=(ROOT/'src/server/features/party/PartyNetworkService.luau').read_text()
kill=(ROOT/'src/server/features/party/KillCreditService.luau').read_text()
loot=(ROOT/'src/server/services/LootService.luau').read_text()
quest=(ROOT/'src/server/services/QuestService.luau').read_text()

for token in ('target.Parent ~= Players','PlayerDataService.isReady','invite.targetUserId ~= player.UserId',
              'record.leaderUserId ~= inviter.UserId','PartyConfig.MaxMembers','Players.PlayerRemoving',
              'pending.targetUserId == target.UserId','task.delay(PartyConfig.InviteTtlSeconds'):
    assert token in service, f'party authority guard missing {token}'
for token in ('PartyRequestRules.validate','lastRequestAt[player]','lastRequestAt[player] = nil'):
    assert token in network, f'party network hardening missing {token}'
assert kill.index('rewardLedger:mark(entityId)') < kill.index('resolvedEvent:Fire'), 'dedupe must precede canonical emission'
assert 'KillCreditService.KillResolved:Connect' in loot
assert 'KillCreditService.KillResolved:Connect' in quest
assert 'MobService.MobDied:Connect' not in loot and 'MobService.MobDied:Connect' not in quest
print('Party security and canonical reward contract: PASS')

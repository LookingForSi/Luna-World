#!/usr/bin/env python3
"""Static guard for M5 party UI/client authority boundaries."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ui=(ROOT/'src/client/features/party/PartyUi.luau').read_text()
controller=(ROOT/'src/client/features/party/PartyController.luau').read_text()
adapter=(ROOT/'src/client/bootstrap/adapters/ExistingClientComponents.luau').read_text()
combat_hud=(ROOT/'src/client/ui/CombatHud.luau').read_text()
target_controller=(ROOT/'src/client/controllers/TargetController.luau').read_text()
config=(ROOT/'src/shared/party/PartyConfig.luau').read_text()
for token in ('"ГРУППА"','PartyHud','InviteBanner','"DEAD"','Humanoid','TouchEnabled','ScrollingFrame'):
    assert token in ui, f'party UI missing {token}'
assert 'button(gui,"ГРУППА"' not in ui, 'solo HUD must not have a permanent party button'
assert 'local active = hasActiveParty()' in ui and 'partyWidget.Visible = active' in ui, 'party widget must only exist for an active party'
assert 'InviteTtlSeconds = 12' in config, 'party invite lifetime must be twelve seconds'
for token in ('InviteTargetButton','"👤+"','Players:GetPlayerFromCharacter','setPartyInviteHandler'):
    assert token in combat_hud, f'player target invite action missing {token}'
for token in ('Players:GetPlayerFromCharacter(current)','targetPlayer ~= localPlayer','canonicalPlayerTargetId'):
    assert token in target_controller, f'player world targeting missing {token}'
for token in ('PartyActionRequest','PartySnapshot','PartyInviteReceived','PartyResult'):
    assert token in controller, f'party controller missing {token}'
assert 'FireServer({ action="Invite", targetUserId=userId })' in controller
assert 'PartyActionFeedback' in ui and 'Приглашение отправлено' in ui
for reason in ('NotReady','AlreadyInParty','PartyFull','InviteCooldown','TargetUnavailable','NotAllowed'):
    assert reason in ui, f'party result feedback missing {reason}'
assert 'PartyUi.start' in adapter and 'PartyUi.stop' in adapter
assert 'PartyController.start' in adapter and 'PartyController.stop' in adapter
print('Party client UI contract: PASS')

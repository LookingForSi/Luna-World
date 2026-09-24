#!/usr/bin/env python3
"""Static guard for M5 party UI/client authority boundaries."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ui=(ROOT/'src/client/features/party/PartyUi.luau').read_text()
controller=(ROOT/'src/client/features/party/PartyController.luau').read_text()
adapter=(ROOT/'src/client/bootstrap/adapters/ExistingClientComponents.luau').read_text()
for token in ('"ГРУППА"','PartyHud','InviteDialog','"DEAD"','Humanoid','TouchEnabled'):
    assert token in ui, f'party UI missing {token}'
for token in ('PartyActionRequest','PartySnapshot','PartyInviteReceived','PartyResult'):
    assert token in controller, f'party controller missing {token}'
assert 'FireServer({ action="Invite", targetUserId=userId })' in controller
assert 'PartyUi.start' in adapter and 'PartyUi.stop' in adapter
assert 'PartyController.start' in adapter and 'PartyController.stop' in adapter
print('Party client UI contract: PASS')

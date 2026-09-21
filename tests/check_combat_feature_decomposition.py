from pathlib import Path
root=Path('src/server/features/combat')
for name in ('CombatCoordinator','PlayerCombatState','TargetingService','BasicAttackService','SkillExecutionService','AutoAttackService','CombatLifecycleAdapter'):
 assert (root/f'{name}.luau').exists()
facade=(root/'CombatCoordinator.luau').read_text()
assert 'services.CombatService' in facade
print('Combat decomposition seams preserve authoritative facade: PASS')

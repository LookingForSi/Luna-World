from pathlib import Path
adapter=Path('src/client/bootstrap/adapters/ExistingClientComponents.luau').read_text()
assert 'features.inventory.InventoryController' in adapter and 'features.economy.EconomyController' in adapter
print('Economy and inventory feature seams: PASS')

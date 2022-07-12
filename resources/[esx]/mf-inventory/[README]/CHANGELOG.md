### 10/06/2021
## 1
- Added xPlayer.setAccountMoney to README.md
- Type-shift various "count" vars from string -> int
- Fix shops giving items with undefined quality.
- Fix initial setup of xPlayer inventory reading old item weights instead of new database-defined values.
- Likely some other UI fix in here also.

## 2
- Fix for selling items to shop.

## 3
- Fix shop "count" problem.

### 12/06/2021
## 1
- Fix for vehicle inventory errors when Config.AllowLocalVehicleInventories is set to false
- Altered ground inventory functionality, fixing various reported issues (such as items disappearing, duplicating items, etc)
- Added export to delete inventory
- Fix for purchase item and craft item events not checking player weight before adding items.

### 13/06/2021
## 1
- Fix for item degradation not working correctly.
- Fix for purchase item and craft item not accounting for item count during player weight check.
- Enforce positive whole numbers for transfer amount.
- Added export to build inventory items from pre-existing items tables.
- Added config option "BagsOfHolding" to stop infinite inventory space stacking.
  -- NOTE: This wont work on old/already existing container items. Only newly created ones.
- Fix for purchasing container items from shops not creating a new container inventory.

### 14/06/2021
## 1
- Enforce integer on amount input.
- Vehicle trunks now require you to stand near the appropriate location (front of vehicle for rear-engine cars).
- Vehicles without a trunk door to open will no longer be able to open a trunk inventory (too much realism? I don't know).
- Added config option "ShowGroundItems" to display a marker above items on the ground within pickup radius.
- Added config table "DegradeModifiers" to modify the degradation rates of items in different inventory subtypes.
- Added "subtype" var to inventory containers, to control the item degradation rates set in the config. This can be set on creation (check readme for new creation export).
- Added "description" var to items, set by database column (check SQL file).
- Added example files for visual backpacks (probably for competent editors only).
- Allow degradation to stack continually on items (e.g: degraded_degraded_degraded_water_bottle).
- Added "buyAccounts" and "sellAccount" to shops. Check config for example and comments.
- Added recipe required item "keep" var, allowing players to keep the item after crafting the recipe.

### 15/06/2021
## 1
- Fix for ground item markers not appearing on relog/login.
- Fix for degraded ground item markers not disappearing.
- Fix for swap item bug.

### 16/06/2021
## 1
- Fix for items being usable from non-player inventories.
- Added readme information for ESX.RegisterUsableItem changes.

### 17/07/2021
- Added vehicle weight/slot defaults based on class/category. Check config.lua and readme.md for information.
  -- NOTE: Vehicle will default to the "Config.Defaults" table if class not defined on inventory creation.
- Config option "MakeAmmoUsable" added to register usable items from ammo found in database items.
  -- NOTE: Only works with weapon names prefixed with "ammo_", e.g: "ammo_weapon_smg".
- Fix for player inventory not refreshing visually after using an item.
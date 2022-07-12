# mf-inventory
## https://modit.store

# Dependencies
- mysql-async
- es_extended (Tested on v1.2)

# Noteworthy Features
## Item degradation
Items automatically degrade over time (if the config option is enabled).
If the item reaches 0 quality, if possible, the item will degrade into its counterpart.
To create a degraded counterpart for an item, simply add it into the database under the same name as your item,
prefixed by "degraded_".

## Unique
The unique column added to your database determines whether or not an item is allowed to be stacked.
Items such as weapons and containers are unique by default (enforced through code).

## DegradeModifier
The degrademodifier column that is added to your items database table through the sql insert query is responsible for varying
the time it takes to degrade different types of items. 0.0 = no degradation, 1.0 = default degradation, 2.0+ = faster degradation.

## Container Items
Container items are items that are capable of being used to open another sub-inventory (e.g: tacobell food bag).
You can define more container items in the config.lua.

# Usage

## Get Inventory Items
```lua
-- client side:
exports["mf-inventory"]:getInventoryItems(identifier,function(items)
  -- Do something with items here...
end)

-- server-side:
local inventory = exports["mf-inventory"]:getInventoryItems(identifier)
```

## New Inventory
You can create and access a new inventory (e.g: housing) through a few simple function calls, as shown below.
If you have a pre-existing items table (general ESX inventory layout), you can convert the items to the format required by the inventory by calling the export "buildInventoryItems", E.G:

```lua
-- Server side, called once for creation:
local uniqueIdentifier = "houseUniqueIdentifier:123:ABC"          -- Unique identifier for this inventory.
local inventoryType = "inventory"                                 -- Inventory type. Default is "inventory", other types are "shop" and "recipe".
local inventorySubType = "housing"                                -- Inventory sub-type, used to modify degrade modifiers by the config table.
local inventoryLabel = "house_storage"                            -- The inventorys UI label index (which will pull the translation value).
local maxWeight = 250.0                                           -- Max weight for the inventory.
local maxSlots = 50                                               -- Max slots for the inventory.
local items = exports["mf-inventory"]:buildInventoryItems({       -- Construct table of valid items for the inventory from pre-existing ESX items table.
  {
    name = 'water_bottle',
    label = 'Water Bottle',
    count = 5
  }
})

exports["mf-inventory"]:createInventory(uniqueIdentifier,inventoryType,inventorySubType,inventoryLabel,maxWeight,maxSlots,items)
```

```lua
-- Client side, called any time you want to open the inventory:
exports["mf-inventory"]:openOtherInventory("houseUniqueIdentifier:123:ABC")
```

NOTE: This must be called AFTER the script has authorized.

## New Vehicle Inventory
When a new vehicle is purchased, you should create an inventory for it by triggering the export, passing the vehicles plate, and optionally the vehicles class/category:
```lua
exports["mf-inventory"]:registerVehicleInventory(plate,class)
```

Alternative net event:
```lua
TriggerServerEvent("inventory:registerVehicleInventory",plate,class)
```

## Shops
You can create shops that allow both buying and selling for fixed values via the config.
While the inventory logic is handled automatically, you will still need to implement a way to open these shops via the export:

```lua
RegisterCommand('inventory:openOther',function(source,args)
  local identifier = args and args[1] or "example_shop:1"
  exports["mf-inventory"]:openOtherInventory(identifier)
end)
```

To create a shop, check out the config.lua and read the example shop provided.

## Crafting
You can create recipes sets which contain a list of recipes, directly craftable from the inventory via the config.
Again, crafting logic is all handled internally but you will need to implement a method for opening the recipe set, e.g:

```lua
RegisterCommand('inventory:openCrafting',function(source,args)
  local identifier = args and args[1] or "example_recipe"
  exports["mf-inventory"]:openCrafting(identifier)
end)
```

To create a recipe set, check out the config.lua and read the example recipe set provided.

## Minigame
A small minigame is included. Press space to use. Example usage:

```lua
RegisterCommand('inventory:minigame',function(source,args)
  local count = 4
  local speed = 0.6
  exports["mf-inventory"]:startMinigame(count,speed,function(res)
    print("Minigame complete",res)
  end)
end)
```

## Forcing inventories to save
Inventories save to the database on a thread roughly every 5 minutes (only as required). To force inventories to save immediately, call the export:
```lua
exports["mf-inventory"]:saveInventories(function()
  print("Inventories saved.")
end)

-- Example for txAdmin:
AddEventHandler('txAdmin:events:scheduledRestart',function(eventData)
  if eventData.secondsRemaining == 30 then
    exports["mf-inventory"]:saveInventories()
  end
end)
```

Allow some time for sql operations before closing server after this function is called.

## Forcing individual inventory to save
```lua
exports["mf-inventory"]:saveInventory(uniqueIdentifier)
```

## Deleting inventories
You can delete inventories that you've created from the server side by calling the export:
```lua
exports["mf-inventory"]:deleteInventory(uniqueIdentifier)
```

## Register usable item
ESX.RegisterUsableItem is now passed a callback function to remove the item that was used. Optional param count of items to remove.
The item being used is also passed.
```lua
ESX.RegisterUsableItem('meth_raw',function(source,removeCb,item)
  print(json.encode(item))
  
  local removeCount = 2
  removeCb(removeCount)
end)
```

## Account money as inventory items
To have account money show up as an inventory item, you need to add the account name to the config.lua table `Config.DisplayAccounts`, and insert the account name as an item in the database.
The default ESX 'money' and 'black_money' items have been provided by default in the database and in the config.

# Installation Instructions
- Below is a list of files you need to change within your es_extended resource.
- Some functions (addAccountMoney and removeAccountMoney) change depending on your ESX version. Observe the comments below and apply the correct modifications.
- The easiest way to replace these files is simply by heading to the file listed, using the "search" feature of your text editor
  to find the function, and overwriting it with the version below.
- Don't forget to run the SQL file before attempting to use this script.

## es_extended/client/functions.lua
```lua
-- Open inventory UI.
ESX.ShowInventory = function()
  exports["mf-inventory"]:openInventory()
end
```

## es_extended/server/functions.lua
```lua
-- Ensure item is usable before using it, add optional param
ESX.UseItem = function(source, item, remove, ...)
  if ESX.UsableItemsCallbacks[item] then
    ESX.UsableItemsCallbacks[item](source,remove,...)
  end
end
```

## es_extended/server/commands.lua
```lua
ESX.RegisterCommand('clearinventory', 'admin', function(xPlayer, args, showError)
  exports["mf-inventory"]:clearInventory(xPlayer.identifier)
end, true, {help = _U('command_clearinventory'), validate = true, arguments = {
  {name = 'playerId', help = _U('id_param'), type = 'player'}
}})

ESX.RegisterCommand('clearloadout', 'admin', function(xPlayer, args, showError)
  for k,v in ipairs(args.playerId.loadout) do
    args.playerId.removeWeapon(v.name,v.ammo,true)
  end
  exports["mf-inventory"]:clearLoadout(xPlayer.identifier)
end, true, {help = _U('command_clearloadout'), validate = true, arguments = {
  {name = 'playerId', help = _U('id_param'), type = 'player'}
}})
```

## es_extended/server/main.lua
```lua
  -- Find and comment out this line to ignore invalid item warnings:
  -- print(('[es_extended] [^3WARNING^7] Ignoring invalid item "%s" for "%s"'):format(name, identifier))
```

## es_extended/server/classes/player.lua
```lua
self.getInventory = function(minimal)
  return exports["mf-inventory"]:getPlayerInventory(self.identifier)
end

-- Will return first stack of items found in inventory by name 
-- Optional param count: find first stack by name where count >= count
self.getInventoryItem = function(name,count, ...)
  return exports["mf-inventory"]:getInventoryItem(self.identifier,name,count, ...)
end

-- Optional param quality.
self.addInventoryItem = function(name, count, quality, ...)
  return exports["mf-inventory"]:addInventoryItem(self.identifier,name,count,self.source,quality, ...)
end

self.removeInventoryItem = function(name, count, ...)
  return exports["mf-inventory"]:removeInventoryItem(self.identifier,name,count,self.source, ...)
end

self.addWeapon = function(weaponName, ammo, ignoreInventory)
  if not self.hasWeapon(weaponName) then
    local weaponLabel = ESX.GetWeaponLabel(weaponName)

    table.insert(self.loadout, {
      name = weaponName,
      ammo = ammo,
      label = weaponLabel,
      components = {},
      tintIndex = 0
    })

    self.triggerEvent('esx:addWeapon', weaponName, ammo)
    self.triggerEvent('esx:addInventoryItem', weaponLabel, false, false)

    if not ignoreInventory then
      exports["mf-inventory"]:addInventoryItem(self.identifier,weaponName,1,self.source)
    end
  end
end

self.removeWeapon = function(weaponName, ammo, ignoreInventory)
  local weaponLabel,weaponIndex

  for k,v in ipairs(self.loadout) do
    if v.name == weaponName then
      weaponLabel = v.label
      weaponIndex = k

      for k2,v2 in ipairs(v.components) do
        self.removeWeaponComponent(weaponName, v2)
      end

      break
    end
  end

  if weaponLabel then
    local weapon = self.loadout[weaponIndex]
    table.remove(self.loadout,weaponIndex)

    self.triggerEvent('esx:removeWeapon', weaponName, ammo)     
    self.triggerEvent('esx:removeInventoryItem', weaponLabel, false, false)

    if not ignoreInventory then
      exports["mf-inventory"]:removeInventoryItem(self.identifier,weaponName,1,self.source)
    end
  end
end
```

## es_extended/server/classes/player.lua (v1.2)
```lua
self.addAccountMoney = function(accountName, money, ignoreInventory)
  if money > 0 then
    local account = self.getAccount(accountName)

    if account then
      local newMoney = account.money + ESX.Math.Round(money)
      account.money = newMoney

      if accountName == 'bank' then
        self.set('bank', newMoney)
      end

      self.triggerEvent('esx:setAccountMoney', account)

      if not ignoreInventory then
        exports["mf-inventory"]:addInventoryItem(self.identifier,accountName,money,self.source)
      end
    end
  end
end

self.removeAccountMoney = function(accountName, money, ignoreInventory)
  if money > 0 then
    local account = self.getAccount(accountName)

    if account then
      local newMoney = account.money - ESX.Math.Round(money)
      account.money = newMoney

      if accountName == 'bank' then
        self.set('bank', newMoney)
      end

      self.triggerEvent('esx:setAccountMoney', account)

      if not ignoreInventory then
        exports["mf-inventory"]:removeInventoryItem(self.identifier,accountName,money,self.source)
      end
    end
  end
end 

self.setAccountMoney = function(accountName, money)
  if money >= 0 then
    local account = self.getAccount(accountName)

    if account then
      local prevMoney = account.money
      local newMoney = ESX.Math.Round(money)
      local diff = math.abs(tonumber(prevMoney) - tonumber(newMoney))
      account.money = newMoney

      if accountName == 'bank' then
        self.set('bank', newMoney)
      end

      self.triggerEvent('esx:setAccountMoney', account)

      if prevMoney > newMoney then
        exports["mf-inventory"]:removeInventoryItem(self.identifier,accountName,diff,self.source)
      elseif prevMoney < newMoney then
        exports["mf-inventory"]:addInventoryItem(self.identifier,accountName,diff,self.source)
      end
    end
  end
end
```

## es_extended/server/classes/player.lua (v1 final)
```lua
self.addAccountMoney = function(accountName, money, ignoreInventory)
  if money > 0 then
    local account = self.getAccount(accountName)

    if account then
      local newMoney = account.money + ESX.Math.Round(money)
      account.money = newMoney

      self.triggerEvent('esx:setAccountMoney', account)

      if not ignoreInventory then
        exports["mf-inventory"]:addInventoryItem(self.identifier,accountName,money,self.source)
      end
    end
  end
end

self.removeAccountMoney = function(accountName, money, ignoreInventory)
  if money > 0 then
    local account = self.getAccount(accountName)

    if account then
      local newMoney = account.money - ESX.Math.Round(money)
      account.money = newMoney

      self.triggerEvent('esx:setAccountMoney', account)

      if not ignoreInventory then
        exports["mf-inventory"]:removeInventoryItem(self.identifier,accountName,money,self.source)
      end
    end
  end
end

self.setAccountMoney = function(accountName, money)
  if money >= 0 then
    local account = self.getAccount(accountName)

    if account then
      local prevMoney = account.money
      local newMoney = ESX.Math.Round(money)
      local diff = math.abs(tonumber(prevMoney) - tonumber(newMoney))
      account.money = newMoney

      self.triggerEvent('esx:setAccountMoney', account)

      if prevMoney > newMoney then
        exports["mf-inventory"]:removeInventoryItem(self.identifier,accountName,diff,self.source)
      elseif prevMoney < newMoney then
        exports["mf-inventory"]:addInventoryItem(self.identifier,accountName,diff,self.source)
      end
    end
  end
end
```
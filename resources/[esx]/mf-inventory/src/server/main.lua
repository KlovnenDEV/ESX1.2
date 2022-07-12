local openInventories       = {}
local registeredInventories = {}
local itemTemplates         = {}
local characters            = {}
local numbers               = {}
local registerCallback      = (Config.UsingESX and ESX.RegisterServerCallback)
local accountLookup         = {}
local craftingRecipes       = {}
local groundItems           = {}
local saveInventoriesCb

local standardInventories = {
  -- Don't touch...
  {
    identifier = "ground",
    type = "inventory",
    subtype = "ground",
    label = "ground",
    maxWeight = Config.Defaults.MaxWeights.ground or 5000.0,
    maxSlots = Config.Defaults.MaxSlots.ground or 100,
    items = {}
  }
}

for i = 48,  57 do table.insert(numbers, string.char(i))    end
for i = 65,  90 do table.insert(characters, string.char(i)) end
for i = 97, 122 do table.insert(characters, string.char(i)) end

for k,v in pairs(Config.CraftingRecipes) do
  v.identifier = k
  craftingRecipes[k] = v
end

for k,v in ipairs(Config.DisplayAccounts) do
  accountLookup[v] = true
end

local generateRandomUid = function(chars,nums)
  math.randomseed(os.time())
  local str = ''
  for i=1,chars,1 do
    str = str .. characters[math.random(#characters)]
  end
  for i=1,nums,1 do
    str = str .. numbers[math.random(#numbers)]
  end
  return str
end

local generateUniqueId = function(kvp,chars,numbers)
  local uid = generateRandomUid(chars,numbers)
  while kvp[uid] do
    uid = generateRandomUid(chars,numbers)
  end
  return uid
end

local getPlayerIdentifier = function(source)
  return ESX.GetPlayerFromId(source).identifier
end

local addMoneyToPlayer = function(source,money,account)
  ESX.GetPlayerFromId(source).addAccountMoney(account or Config.CashAccountName,money)
end

local removeMoneyFromPlayer = function(source,money,account)
  ESX.GetPlayerFromId(source).removeAccountMoney(account or Config.CashAccountName,money)
end

local hasPlayerGotEnoughMoney = function(source,money,accounts)
  local xPlayer = ESX.GetPlayerFromId(source)
  if accounts then
    for k,v in ipairs(accounts) do
      if xPlayer.getAccount(v).money >= money then
        return true,v
      end
    end
    return false
  else
    return (xPlayer.getAccount(Config.CashAccountName).money >= money)
  end
end

local notify = function(source,msg)
  TriggerClientEvent("inventory:notify",source,msg)
end

local getItemTemplate = function(itemName)
  local item = {}
  if itemTemplates[itemName] then
    for k,v in pairs(itemTemplates[itemName]) do
      item[k] = v
    end
    return item
  else
    debugPrint(string.format("invalid item: %s",itemName),2)
  end
end

local getWeight = function(items)
  local weight = 0
  for k,v in ipairs(items) do
    if v.weight and v.count then
      weight = weight + (v.weight*v.count)
    end
  end
  return weight
end

local getPlayerItems = function(accounts,items,loadout)
  local res       = {}
  local seenItems = {}
  local itemCount = 0

  for i=1,Config.Defaults.MaxSlots["player"] - itemCount,1 do    
    res[i] = {}
    for k,v in pairs(accounts) do
      if not seenItems[v.name] and v.money > 0 and accountLookup[v.name] then
        seenItems[v.name] = true

        res[i] = {
          slot    = i,
          quality = 100,
          name    = v.name,
          weight  = 0.0,
          label   = v.label,
          count   = tonumber(v.money)
        }

        itemCount = itemCount + 1
        break
      end
    end
  end

  for i=1,Config.Defaults.MaxSlots["player"] - itemCount,1 do
    if not res[i].name then
      for k,v in pairs(items) do
        if not seenItems[v.name] and tonumber(v.count) > 0 then
          seenItems[v.name] = true

          res[i] = {
            slot    = i,
            quality = 100,
            name    = v.name,
            weight  = itemTemplates[v.name] and itemTemplates[v.name].weight or 1.0,
            label   = v.label,
            count   = tonumber(v.count) or 1
          }

          itemCount = itemCount + 1
          break
        end
      end
    end
  end

  for i=1,Config.Defaults.MaxSlots["player"] - itemCount,1 do
    if not res[i].name then
      for k,v in pairs(loadout) do
        local name = v.name:lower()
        if not seenItems[name] then
          seenItems[name] = true

          res[i] = {
            slot = i,
            quality = 100,
            name = name,
            weight = itemTemplates[name] and itemTemplates[name].weight or 1.0,
            label = v.label,
            count = 1,
            unique = true
          }
        end
      end
    end
  end

  return res
end

local getMinimalInventory = function(identifier,typeof,subtype,label,maxWeight,maxSlots,items)
  local _items = {}
  for i=1,maxSlots,1 do
    if not items[i] then
      _items[i] = {}
    else
      _items[i] = items[i]
    end
  end

  return {
    identifier  = identifier,
    type        = typeof,
    subtype     = subtype or "default",
    label       = label,
    weight      = getWeight(items),
    maxWeight   = maxWeight,
    maxSlots    = maxSlots,
    items       = _items
  }
end

local logAction = function(source,action)
  local id = getPlayerIdentifier(source)
  debugPrint(string.format("inventory:logAction: %s: %s",id,action))
  TriggerClientEvent("inventory:logAction",source,action)
end

local addNotification = function(source,added,item)
  TriggerClientEvent("inventory:addNotification",source,added,item)
end

local refreshInventory = function(...)
  TriggerClientEvent("inventory:refreshInventory",...)
end

local checkWeapon = function(source,item,inv,taking)
  if Config.Weapons[item.name:lower()] then
    local xPlayer = ESX.GetPlayerFromId(source)
    local index,weapon = xPlayer.getWeapon(item.name)
    if taking then
      if weapon then
        local nextWeapon = inv:getItem(item.name)
        if not nextWeapon or nextWeapon.count <= 0 then
          xPlayer.removeWeapon(weapon.name,0,true)
        end
      end
    else
      if not weapon then
        xPlayer.addWeapon(item.name,0,100,true)
      end
    end
  end
end

local checkAccount = function(source,item,count,taking)
  count = count and count > 0 and count or item.count
  if accountLookup[item.name] then
    local xPlayer = ESX.GetPlayerFromId(source)
    local account = xPlayer.getAccount(item.name)
    if taking then
      xPlayer.removeAccountMoney(item.name,count,true)
    else
      xPlayer.addAccountMoney(item.name,count,true)
    end
  end
end

local destroyInventory = function(invId)
  local inv = registeredInventories[invId]
  if inv then
    registeredInventories[invId] = nil
    MySQL.Async.execute("DELETE FROM inventories WHERE identifier=@identifier",{
      ['@identifier'] = invId
    })
  end
end

local removeGroundItem = function(name,count,pos)
  pos = vector3(pos.x,pos.y,pos.z)

  for k,v in ipairs(groundItems) do
    if v.pos == pos and v.name == name then
      if count >= v.count then
        table.remove(groundItems,k)
      else
        v.count = v.count - count
      end

      break
    end
  end

  TriggerClientEvent("inventory:removeGroundItem",-1,name,count,pos)
end

local addGroundItem = function(name,count,pos)  
  pos = vector3(pos.x,pos.y,pos.z)

  table.insert(groundItems,{
    name = name,
    count = count,
    pos = pos
  })

  TriggerClientEvent("inventory:addGroundItem",-1,name,count,pos)
end

local getVehicleClassDefaults = function(class)
  if type(class) == "number" then
    return Config.VehicleClassDefaults[class]
  else
    for i=0,#Config.VehicleClassDefaults do
      if class == Config.VehicleClassDefaults[i].name then
        return Config.VehicleClassDefaults[i]
      end
    end
  end
end

function debugPrint(...)
  if Config.Debug then
    print(...)
  end
end

function setReady(ready)
  scriptReady = ready
end

function registerInventory(identifier,typeof,label,maxWeight,maxSlots,items,subtype)
  identifier = tostring(identifier)
  local minimal = getMinimalInventory(identifier,typeof or "inventory",subtype or "default",label or "player",maxWeight or Config.Defaults.MaxWeights["player"],maxSlots or Config.Defaults.MaxSlots["player"],items or {})
  local mt = newInventory(minimal)
  registeredInventories[identifier] = mt
  debugPrint("Inventory registered for id "..identifier)
  
  MySQL.Async.execute("INSERT INTO inventories (identifier,data) VALUES (@identifier,@data)",{
    ['@identifier'] = identifier,
    ['@data'] = json.encode(minimal)
  })
end

function createInventory(identifier,typeof,subtype,label,maxWeight,maxSlots,items)
  identifier = tostring(identifier)
  local minimal = getMinimalInventory(identifier,typeof or "inventory",subtype or "default",label or "player",maxWeight or Config.Defaults.MaxWeights["player"],maxSlots or Config.Defaults.MaxSlots["player"],items or {})
  local mt = newInventory(minimal)
  registeredInventories[identifier] = mt
  debugPrint("Inventory registered for id "..identifier)
  
  MySQL.Async.execute("INSERT INTO inventories (identifier,data) VALUES (@identifier,@data)",{
    ['@identifier'] = identifier,
    ['@data'] = json.encode(minimal)
  })
end

function registerVehicleInventory(plate,class)    
  plate = ESX.Math.Trim(plate)

  if not registeredInventories["glovebox_"..plate] then
    local maxWeight = Config.Defaults.MaxWeights["vehicleGloveBox"]
    local maxSlots  = Config.Defaults.MaxSlots["vehicleGloveBox"]

    if class then
      local classDefaults = getVehicleClassDefaults(class)
      if classDefaults then
        maxWeight = classDefaults.gloveBox.maxWeight
        maxSlots  = classDefaults.gloveBox.maxSlots
      end
    end

    local id = "glovebox_"..plate
    local data = getMinimalInventory(id,"inventory","vehicleGloveBox","vehicle_glove_box",maxWeight,maxSlots,{})          
    local mt = newInventory(data)
    registeredInventories[id] = mt  

    MySQL.Async.execute("INSERT INTO inventories (identifier,data) VALUES (@identifier,@data)",{
      ['@identifier'] = id,
      ['@data'] = json.encode(data)
    })
  end

  if not registeredInventories[plate] then
    local maxWeight = Config.Defaults.MaxWeights["vehicleTrunk"]
    local maxSlots  = Config.Defaults.MaxSlots["vehicleTrunk"]

    if class then
      local classDefaults = getVehicleClassDefaults(class)
      if classDefaults then
        maxWeight = classDefaults.gloveBox.maxWeight
        maxSlots  = classDefaults.gloveBox.maxSlots
      end
    end

    local id = plate
    local data = getMinimalInventory(id,"inventory","vehicleTrunk","vehicle_trunk",maxWeight,maxSlots,{})
    local mt = newInventory(data)
    registeredInventories[id] = mt  

    MySQL.Async.execute("INSERT INTO inventories (identifier,data) VALUES (@identifier,@data)",{
      ['@identifier'] = id,
      ['@data'] = json.encode(data)
    })
  end
end

MySQL.ready(function()
  while not scriptReady do Wait(100) end
  MySQL.Async.fetchAll("SELECT * FROM inventories",{},function(res)
    for k,v in ipairs(res) do
      local data = json.decode(v.data)
      local minimal = getMinimalInventory(v.identifier,data.type,data.subtype,data.label,data.maxWeight,data.maxSlots,data.items)
      local mt = newInventory(minimal)
      registeredInventories[v.identifier] = mt
    end

    for k,v in ipairs(standardInventories) do
      if not registeredInventories[v.identifier] then
        local minimal = getMinimalInventory(v.identifier,v.type,v.subtype,v.label,v.maxWeight,v.maxSlots,v.items)
        local mt = newInventory(minimal)
        registeredInventories[v.identifier] = mt

        MySQL.Async.execute("INSERT INTO inventories (identifier,data) VALUES (@identifier,@data)",{
          ['@identifier'] = v.identifier,
          ['@data'] = json.encode(minimal)
        })

        debugPrint("Registered default inventory ",v.identifier)
      else
        local inv = registeredInventories[v.identifier]
        inv.subtype = v.subtype
        inv.label = v.label
        inv.maxWeight = v.maxWeight
        inv.maxSlots = v.maxSlots
        inv.type = v.type
      end
    end

    if Config.Shops then
      for k,v in ipairs(Config.Shops) do
        local minimal = getMinimalInventory(v.identifier,v.type,v.subtype,v.label,v.maxWeight,v.maxSlots,v.items)
        local mt = newInventory(minimal)
        registeredInventories[v.identifier] = mt
      end
    end

    MySQL.Async.fetchAll("SELECT * FROM items",{},function(items)
      for _,item in ipairs(items) do
        item.name = item.name:lower()
        item.unique = item.unique > 0

        if Config.ContainerItems[item.name] or Config.Weapons[item.name] then
          item.unique = true
        end

        itemTemplates[item.name] = item
      end

      if Config.MakeAmmoUsable then
        for _,item in pairs(itemTemplates) do
          if item.name:sub(1,5) == "ammo_" then
            if itemTemplates[item.name:gsub("ammo_","")] then
              ESX.RegisterUsableItem(item.name,function(source,remove,item)
                remove(1)
                TriggerClientEvent("inventory:useAmmo",source,item.name:gsub("ammo_",""))
              end)
            end
          end
        end
      end

      MySQL.Async.fetchAll("SELECT * FROM owned_vehicles",{},function(vehicles)
        for k,v in ipairs(vehicles) do
          registerVehicleInventory(v.plate)
        end
          
        local groundInventory = registeredInventories["ground"]
        for i=1,#groundInventory.items do
          local item = groundInventory.items[i]
          if item and item.name then
            table.insert(groundItems,{
              name = item.name,
              count = item.count,
              pos = vector3(item.pos.x,item.pos.y,item.pos.z)
            })
          end
        end

        for k,v in pairs(registeredInventories) do
          for k,v in pairs(v.items) do
            if v and v.name then
              if not v.description and itemTemplates[v.name] then
                v.description = itemTemplates[v.name].description
              end
            end
          end
        end

        isReady = true
        debugPrint("Script ready.")
      end)
    end)
  end)
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
  while not isReady do Wait(0) end
  local id = xPlayer.identifier
  if not registeredInventories[id] then
    local playerItems = getPlayerItems(xPlayer.accounts,xPlayer.inventory,xPlayer.loadout)
    local minimal = getMinimalInventory(id,"inventory","player","player",Config.Defaults.MaxWeights["player"],Config.Defaults.MaxSlots["player"],playerItems)
    local mt = newInventory(minimal)
    registeredInventories[id] = mt

    MySQL.Async.execute("INSERT INTO inventories (identifier,data) VALUES (@identifier,@data)",{
      ['@identifier'] = id,
      ['@data'] = json.encode(minimal)
    })

    debugPrint("Registered new inventory for player "..GetPlayerName(playerId))
  else
    local inv       = registeredInventories[id]
    inv.maxWeight   = Config.Defaults.MaxWeights["player"]
    inv.maxSlots    = Config.Defaults.MaxSlots["player"]
    inv.shouldSave  = true
  end
end)

AddEventHandler("playerDropped",function()
  for k,v in pairs(openInventories) do
    if v == source then
      openInventories[k] = nil
    end
  end
end)

AddEventHandler("esx:removeWeapon",function(source,weaponName)
  local id = getPlayerIdentifier(source)
  local inv = registeredInventories[id]
  local item = getItemTemplate(weaponName:lower())  

  if not item then
    return
  end

  inv:removeItem(weaponName,1)

  logAction(source,string.format(_T("removed_from_inventory"),1,item.label))
  addNotification(source,false,{label = item.label,name=item.name,count = 1})
  refreshInventory(source,inv,false)
  inv.shouldSave = true
end)

AddEventHandler("esx:addWeapon",function(source,weaponName,quality)
  local id = getPlayerIdentifier(source)
  local inv = registeredInventories[id]
  local item = getItemTemplate(weaponName:lower())  
  
  if not item then
    return
  end

  item.quality = quality or 100
  inv:addItem(item,1)

  logAction(source,string.format(_T("added_to_inventory"),1,item.label)) 
  addNotification(source,true,{label = item.label,name=item.name,count = 1})
  refreshInventory(source,inv,false)
  inv.shouldSave = true
end)

RegisterNetEvent("inventory:closed")
AddEventHandler("inventory:closed",function()
  for identifier,player in pairs(openInventories) do
    if player == source then
      openInventories[identifier] = nil
    end
  end
end)

RegisterNetEvent("inventory:useItem")
AddEventHandler("inventory:useItem",function(identifier,index)
  local _source = source
  local xPlayer = ESX.GetPlayerFromId(_source)
  if xPlayer and xPlayer.identifier == identifier then
    local inventory = registeredInventories[identifier]
    local item = inventory:getItemAtSlot(index)
    if item and item.name then
      ESX.UseItem(_source,item.name,function(count)
        count = (count and tonumber(count) or 1)
        inventory:removeCountAtSlot(index,count)
        logAction(_source,string.format(_T('used_item'),count,item.label))
        addNotification(_source,true,{label = item.label,name=item.name,count = count})
        inventory.shouldSave = true

        local plyInv,otherInv = registeredInventories[identifier]
        for k,v in pairs(openInventories) do
          if v == _source then
            if k ~= identifier then
              otherInv = registeredInventories[k]
            end
          end
        end

        refreshInventory(_source,plyInv,otherInv)
      end,item)
    end
  end
end)

RegisterNetEvent("inventory:registerVehicleInventory")
AddEventHandler("inventory:registerVehicleInventory",registerVehicleInventory)

registerCallback("inventory:getGroundItems",function(source,callback,location)
  while not isReady do Wait(0) end
  callback(groundItems)
end)

registerCallback("inventory:openInventory",function(source,callback,location)
  local id = getPlayerIdentifier(source)
  if id then
    local plyInv = registeredInventories[id]
    local groundInv = registeredInventories["ground"]
    local byDistance = groundInv:getItemsAtDistance(Config.PickupDistance,location)
    local otherInv = groundInv:minimal()
    otherInv.items = byDistance
    if not openInventories[id] then
      openInventories[id] = source
      callback(true,plyInv,otherInv)
    else
      notify(source,_T('inventory_in_use'))
      callback(false)
    end
  end
end)

registerCallback("inventory:openCrafting",function(source,callback,recipeId)
  local id = getPlayerIdentifier(source)
  if id then
    local plyInv = registeredInventories[id]
    local recipe = craftingRecipes[recipeId]
    if not openInventories[id] then
      openInventories[id] = source
      callback(true,plyInv,recipe)
    else
      notify(source,_T('inventory_in_use'))
      callback(false)
    end
  end
end)

registerCallback("inventory:openOtherInventory",function(source,callback,otherId)
  local id = getPlayerIdentifier(source)
  if id then
    local plyInv = registeredInventories[id]
    local otherInv = registeredInventories[otherId]

    if plyInv and otherInv then
      if not openInventories[id] and not openInventories[otherId] then
        openInventories[id] = source
        openInventories[otherId] = source
        callback(true,plyInv,otherInv)
      else
        notify(source,_T('inventory_in_use'))
        callback(false)
      end
    else
      callback(false)
    end
  end
end)

registerCallback("inventory:openVehicleInventory",function(source,callback,plate,class,inside,location)
  local id = getPlayerIdentifier(source)
  if id then
    plate = (inside and "glovebox_"..plate or plate)
    local plyInv = registeredInventories[id]
    local otherInv = registeredInventories[plate]

    if otherInv then
      if not openInventories[id] and not openInventories[plate] then
        openInventories[plate]  = source
        openInventories[id]     = source
        callback(true,plyInv:minimal(),otherInv:minimal())
      else
        notify(source,_T('inventory_in_use'))
        callback(false)
      end
    else
      if Config.AllowLocalVehicleInventories then
        local maxWeight = Config.Defaults.MaxWeights[(inside and "vehicleGloveBox" or "vehicleTrunk")]
        local maxSlots  = Config.Defaults.MaxSlots[(inside and "vehicleGloveBox" or "vehicleTrunk")]

        local classDefaults = getVehicleClassDefaults(class)
        if classDefaults then
          maxWeight = classDefaults[(inside and "gloveBox" or "trunk")].maxWeight
          maxSlots  = classDefaults[(inside and "gloveBox" or "trunk")].maxSlots
        end

        local uniqueIdentifier  = plate
        local inventoryType     = "inventory"
        local inventorySubType  = (inside and "vehicleGloveBox" or "vehicleTrunk")
        local inventoryLabel    = (inside and "vehicle_glove_box" or "vehicle_trunk")

        local data  = getMinimalInventory(uniqueIdentifier,inventoryType,inventorySubType,inventoryLabel,maxWeight,maxSlots,{})
        local mt    = newInventory(data)

        openInventories[plate]        = source
        openInventories[id]           = source
        registeredInventories[plate]  = mt

        callback(true,plyInv,mt)
      else
        local groundInv   = registeredInventories["ground"]
        local byDistance  = groundInv:getItemsAtDistance(Config.PickupDistance,location)
        local otherInv    = groundInv:minimal()
        otherInv.items    = byDistance

        if not openInventories[id] then
          openInventories[id] = source
          callback(true,plyInv,false,otherInv)
        end
      end
    end
  end
end)

registerCallback("inventory:purchaseItem",function(source,callback,fromIdentifier,fromIndex,toIndex,item,count)
  local id = getPlayerIdentifier(source)
  local plyInv = registeredInventories[id]
  local shopInv = registeredInventories[fromIdentifier]
  
  local cfgShop
  for k,v in ipairs(Config.Shops) do
    if v.identifier == fromIdentifier then
      cfgShop = v
      break
    end
  end

  if shopInv.type == "shop" then
    local _item = shopInv:getItemAtSlot(fromIndex)
    if _item.name and _item.price then
      if _item.price >= item.price then
        local itemTemplate = getItemTemplate(item.name:lower())
        if itemTemplate then
          if itemTemplate.unique then
            count = 1
          end

          local inSlot = plyInv:getItemAtSlot(toIndex)
          local price = math.floor(_item.price * count)
          local hasEnough,acc = hasPlayerGotEnoughMoney(source,price,cfgShop and cfgShop.buyAccounts or nil)
          if hasEnough then
            if plyInv:checkWeight(itemTemplate,false,count) then
              itemTemplate.quality = (_item.quality or 100)

              if Config.ContainerItems[itemTemplate.name] then
                local cfgItem = Config.ContainerItems[itemTemplate.name]
                local itemId = generateUniqueId(registeredInventories,8,8)
                itemTemplate.itemId = itemId
                registerInventory(itemId,"subinventory",itemTemplate.label,cfgItem.maxWeight,cfgItem.maxSlots,itemTemplate.name)
              end

              if inSlot and inSlot.name then
                if plyInv:addItem(itemTemplate,count) then
                  removeMoneyFromPlayer(source,price,acc)
                  logAction(source,string.format(_T('purchased_items'),count,item.label,price))
                  addNotification(source,true,{label = item.label,name=item.name,count = count})
                  checkWeapon(source,itemTemplate)
                end
              else
                removeMoneyFromPlayer(source,price,acc)
                plyInv:addItemAtSlot(toIndex,itemTemplate,count)
                logAction(source,string.format(_T('purchased_items'),count,item.label,price))
                addNotification(source,true,{label = item.label,name=item.name,count = count})
                checkWeapon(source,itemTemplate)
              end
              plyInv.shouldSave = true
            else
              notify(source,_T('item_too_heavy'))
            end
          else
            notify(source,_T('not_enough_money'))
          end
        else
          debugPrint("Invalid item",item.name)
        end
        callback(plyInv:minimal(),shopInv:minimal())
      else
        debugPrint("Player somehow got different price for item",id,item.name)
      end
    else
      debugPrint("Unable to find correct item at slot.")
    end
  end
end)

registerCallback("inventory:sellItem",function(source,callback,toIdentifier,fromIndex,toIndex,item,count)
  count = math.min(tonumber(count),(tonumber(item.count) or 1))
  local id = getPlayerIdentifier(source)
  local plyInv = registeredInventories[id]
  local shopInv = registeredInventories[toIdentifier]

  local cfgShop
  for k,v in ipairs(Config.Shops) do
    if v.identifier == toIdentifier then
      cfgShop = v
      break
    end
  end

  if shopInv.type == "shop" then
    local _item = shopInv:getItemAtSlot(toIndex)
    if _item.buyPrice and item.name == _item.name then
      local sellItem = plyInv:getItemAtSlot(fromIndex)
      if sellItem.count and tonumber(sellItem.count) >= count then
        local price = math.floor(_item.buyPrice * count)
        addMoneyToPlayer(source,price,cfgShop.sellAccount)

        plyInv:removeCountAtSlot(fromIndex,count)
        logAction(source,string.format(_T('sold_items'),count,item.name,price))
        addNotification(source,false,{label = item.label,name=item.name,count = count})
        checkWeapon(source,item,true)
        callback(plyInv:minimal(),shopInv:minimal())
        plyInv.shouldSave = true
      else
        debugPrint("Player tried to sell more items then they have.")
      end
    else
      debugPrint("Unable to find correct item at slot.")
    end
  end
end)

registerCallback("inventory:move",function(source,callback,identifier,fromIndex,toIndex,item,count,pos)
  count = math.min(tonumber(count),(tonumber(item.count) or 1))
  local id = getPlayerIdentifier(source)
  if id then
    if identifier == "ground" or openInventories[identifier] == source then
      local inventory = registeredInventories[identifier]
      local fromItem = inventory:getItemAtSlot(fromIndex)
      local toItem = inventory:getItemAtSlot(toIndex)
      if fromItem and fromItem.name and fromItem.name == item.name then
        if toItem and toItem.name then
          if toItem.name == fromItem.name and not toItem.unique and not fromItem.unique then
            if count >= fromItem.count then
              inventory:removeItemAtSlot(fromIndex)
            else
              inventory:removeCountAtSlot(fromIndex,count)
            end
            inventory:addCountAtSlot(toIndex,count)
          else
            inventory:addItemAtSlot(toIndex,fromItem,fromItem.count)
            inventory:addItemAtSlot(fromIndex,toItem,toItem.count)
          end
        else
          inventory:removeCountAtSlot(fromIndex,count)
          inventory:addItemAtSlot(toIndex,item,count)
        end

        local plyInv,otherInv
        if id == identifier then
          plyInv = inventory:minimal()
        else
          otherInv = inventory:minimal()
        end

        inventory.shouldSave = true

        callback(plyInv or false,otherInv or false)
      end
    end
  end
end)

registerCallback("inventory:transferItem",function(source,callback,fromIdentifier,toIdentifier,fromIndex,toIndex,item,count,pos)
  count = math.min(tonumber(count),(tonumber(item.count) or 1))
  local _pos = item.pos
  item.pos = {x = pos.x, y = pos.y, z = pos.z}
  local id = getPlayerIdentifier(source)
  if id then
    if fromIdentifier == "ground" or openInventories[fromIdentifier] == source and toIdentifier == "ground" or openInventories[toIdentifier] == source then
      local fromInv = registeredInventories[fromIdentifier]
      local toInv = registeredInventories[toIdentifier]

      local gaveItem,gotItem

      if toInv.type == "subinventory" and Config.ContainerItems[item.name] and not Config.BagsOfHolding then
        notify(source,_T('cant_stack_subinventory'))
      else
        if toInv:checkWeight(item,toInv:getItemAtSlot(toIndex),count) or toIdentifier == "ground" then
          if (not toInv:getItemAtSlot(toIndex).unique and not fromInv:getItemAtSlot(fromIndex).unique) or (not toInv:getItemAtSlot(toIndex).name or toIdentifier == "ground") then
            if fromIdentifier == "ground" then
              if toInv:getItemAtSlot(toIndex).name then
                if toInv:getItemAtSlot(toIndex).name == item.name then
                  if fromInv:removeItemWithData(item.name,count,"pos",_pos) then
                    toInv:addCountAtSlot(toIndex,count)
                    gaveItem = true
                    checkWeapon(source,item,fromInv)
                    checkAccount(source,item,count)
                  end
                else
                  if fromInv:removeItemWithData(item.name,count,"pos",_pos) then
                    local swapItem = toInv:getItemAtSlot(toIndex)

                    swapItem.pos = item.pos
                    fromInv:addItem(swapItem,swapItem.count)

                    toInv:addItemAtSlot(toIndex,item,count)

                    gaveItem = true
                    gotItem  = swapItem

                    checkWeapon(source,item,fromInv)
                    checkAccount(source,item,count)
                  end
                end
              else
                if fromInv:removeItemWithData(item.name,count,"pos",_pos) then
                  toInv:addItemAtSlot(toIndex,item,count)
                  gaveItem = true

                  checkWeapon(source,item,fromInv)
                  checkAccount(source,item,count)
                end          
              end

              if gaveItem then
                removeGroundItem(item.name,count,_pos)
              end

              if gotItem then
                addGroundItem(gotItem.name,gotItem.count,pos)
              end
            elseif toIdentifier == "ground" then
              fromInv:removeCountAtSlot(fromIndex,count)
              toInv:addItem(item,count,true) 
              gaveItem = true      
              checkWeapon(source,item,fromInv,true)
              checkAccount(source,item,count,true)

              addGroundItem(item.name,count,pos)
            else  
              local swapItem = toInv:getItemAtSlot(toIndex) 
              if swapItem and swapItem.name then
                if swapItem.name == item.name and not swapItem.unique and not item.unique then
                  fromInv:removeCountAtSlot(fromIndex,count)
                  toInv:addCountAtSlot(toIndex,count)
                else

                  fromInv:addItemAtSlot(fromIndex,swapItem,swapItem.count)
                  toInv:addItemAtSlot(toIndex,item,item.count)
                end

                gaveItem = true
                gotItem  = swapItem

                if toInv.identifier == id then
                  checkWeapon(source,item,fromInv)
                  checkAccount(source,item,count)
                else
                  checkWeapon(source,item,fromInv,true)
                  checkAccount(source,item,count,true)
                end
              else
                fromInv:removeCountAtSlot(fromIndex,count)
                toInv:addItemAtSlot(toIndex,item,count)
                gaveItem = true

                if toInv.identifier == id then
                  checkWeapon(source,item,fromInv)
                  checkAccount(source,item,count)

                  local oPlayer = ESX.GetPlayerFromIdentifier(fromInv.identifier)
                  if oPlayer then
                    checkWeapon(oPlayer.source,item,fromInv,true)
                  end
                else
                  checkWeapon(source,item,fromInv,true)
                  checkAccount(source,item,count,true)

                  local oPlayer = ESX.GetPlayerFromIdentifier(toInv.identifier)
                  if oPlayer then
                    checkWeapon(oPlayer.source,item,fromInv)
                  end
                end
              end
            end  
          end   
        else 
          notify(source,_T('item_too_heavy'))
        end
      end

      local plyInv    = (fromInv.identifier == id and fromInv or toInv):minimal()
      local otherInv  = (fromInv.identifier == id and toInv or fromInv)

      plyInv.shouldSave   = true
      otherInv.shouldSave = true

      local items 
      if otherInv.identifier == "ground" then
        local items = otherInv:getItemsAtDistance(Config.PickupDistance,pos)
        otherInv = otherInv:minimal()
        otherInv.items = items
      end

      if fromInv.identifier == id then
        if gotItem and gaveItem then
          logAction(source,string.format(_T('swapped_items'),item.count,item.label,gotItem.count,gotItem.label))
          addNotification(source,true,{label = gotItem.label,name=gotItem.name,count = gotItem.count})
          addNotification(source,false,{label = item.label,name=item.name,count = item.count})

          TriggerEvent("inventory:playerGotItem",id,gotItem.name)
          TriggerEvent("inventory:playerLostItem",id,item.name)
        elseif gaveItem then
          logAction(source,string.format(_T('removed_from_inventory'),count,item.label))
          addNotification(source,false,{label = item.label,count = count})

          TriggerEvent("inventory:playerLostItem",id,item.name)
        end
      else
        if gotItem and gaveItem then
          logAction(source,string.format(_T('swapped_items'),gotItem.count,gotItem.label,item.count,item.label))
          addNotification(source,true,{label = item.label,name=item.name,count = item.count})
          addNotification(source,false,{label = gotItem.label,name=gotItem.name,count = gotItem.count})

          TriggerEvent("inventory:playerGotItem",id,item.name)
          TriggerEvent("inventory:playerLostItem",id,gotItem.name)
        elseif gaveItem then
          logAction(source,string.format(_T('added_to_inventory'),count,item.label))
          addNotification(source,true,{label = item.label,name=item.name,count = count})

          TriggerEvent("inventory:playerGotItem",id,item.name)
        end
      end

      callback(plyInv,otherInv)
      return
    else
      debugPrint(string.format("Player %i trying to interact with inventory that is not open.",source))
    end
  end
end)

registerCallback("inventory:pressHotkey",function(source,callback,index)
  local id = getPlayerIdentifier(source)
  if id then
    local plyInventory = registeredInventories[id]
    local slots = {}
    for i=1,4,1 do slots[i] = plyInventory:getItemAtSlot(i); end
    local selected = slots[index]
    if selected and selected.name then
      if Config.Weapons[selected.name:lower()] then
        TriggerClientEvent("inventory:useWeapon",source,selected.name)
      else
        ESX.UseItem(source,selected.name,function(count)
          count = (count and tonumber(count) or 1)
          plyInventory:removeCountAtSlot(index,count)
          logAction(source,string.format(_T('used_item'),count,selected.label))
          addNotification(source,true,{label = selected.label,name=selected.name,count = count})
          plyInventory.shouldSave = true
        end,selected)
      end
    end
    callback(slots)
  end
end)

registerCallback("inventory:craft",function(source,callback,identifier,recipe)
  local id = getPlayerIdentifier(source)
  if id then
    local plyInventory = registeredInventories[id]
    local recipes = craftingRecipes[identifier]
    local makeRecipe
    for _,r in ipairs(recipes.recipes) do
      if r.name == recipe.name then
        makeRecipe = r
        break
      end
    end

    if plyInventory:hasAllItems(makeRecipe.required) then
      local itemTemplate = getItemTemplate(recipe.name:lower())

      if not itemTemplate then
        return
      end

      if plyInventory:checkWeight(itemTemplate,false,recipe.count) then
        local swapStr = ''
        for k,v in ipairs(recipe.required) do
          if not v.keep then
            swapStr = string.format('%s, x%i "%s"',swapStr,v.count,v.label)
            plyInventory:removeItem(v.name,v.count)
            addNotification(source,false,{label = v.label,name=v.name,count = v.count})
          end
        end
        swapStr = swapStr:sub(3)

        itemTemplate.count    = recipe.count
        itemTemplate.name     = recipe.name
        itemTemplate.quality  = recipe.quality

        if Config.ContainerItems[itemTemplate.name] then
          local cfgItem = Config.ContainerItems[itemTemplate.name]
          local itemId = generateUniqueId(registeredInventories,8,8)
          itemTemplate.itemId = itemId
          registerInventory(itemId,"subinventory",itemTemplate.label,cfgItem.maxWeight,cfgItem.maxSlots,itemTemplate.name)
        end

        plyInventory:addItem(itemTemplate,recipe.count)

        logAction(source,string.format(_T('you_swapped'),swapStr,recipe.count,recipe.label))
        addNotification(source,true,{label = recipe.label,name=recipe.name,count = recipe.count})
        callback(plyInventory,recipes)
        plyInventory.shouldSave = true
      else
        notify(source,_T('item_too_heavy'))
      end
    else
      notify(source,_T('need_required_items'))
    end
  end
end)

registerCallback("inventory:getInventoryItems",function(source,callback,identifier)
  local inv = registeredInventories[identifier]
  local content = {}
  if inv then
    for k,v in ipairs(inv.items) do
      if v and v.name and tonumber(v.count) > 0 then
        table.insert(content,v)
      end
    end
  end
  callback(content)
end)

exports('clearInventory',function(identifier)
  if registeredInventories[identifier] then
    local inv = registeredInventories[identifier]
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    for i=1,#inv.items,1 do
      local item = inv.items[i]
      if item.name and not Config.Weapons[item.name:lower()] and not accountLookup[item.name] then
        if xPlayer then
          logAction(xPlayer.source,string.format(_T('cleared_from_inventory'),item.count,item.label))
          addNotification(xPlayer.source,false,{label = item.label,name=item.name,count = item.count})
        end
        registeredInventories[identifier].items[i] = {}
      end
    end
    inv.shouldSave = true
  end
end)

exports('clearLoadout',function(identifier)
  if registeredInventories[identifier] then
    local inv = registeredInventories[identifier]
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    for i=1,#inv.items,1 do
      local item = inv.items[i]
      if item.name and Config.Weapons[item.name:lower()] then
        if xPlayer then
          logAction(xPlayer.source,string.format(_T('cleared_from_loadout'),item.count,item.label))
          addNotification(xPlayer.source,false,{label = item.label,name=item.name,count = item.count})
        end
        registeredInventories[identifier].items[i] = {}
      end
    end
    inv.shouldSave = true
  end
end)

exports('getInventory',function(identifier)
  return registeredInventories[identifier]
end)

exports('getPlayerInventory',function(identifier)
  local inv = registeredInventories[identifier] or {items = {}}
  local content = {}
  for k,v in ipairs(inv.items) do
    if v and v.name and tonumber(v.count) > 0 then
      table.insert(content,v)
    end
  end
  return content
end)

exports('getInventoryItems',function(identifier)
  return registeredInventories[identifier].items
end)

exports('getInventoryItem',function(identifier,itemName,itemCount)
  local inventory = registeredInventories[identifier]
  return inventory:getItem(itemName,tonumber(itemCount) or 1)
end)

exports('addInventoryItem',function(identifier,itemName,count,source,quality)
  local template = getItemTemplate(itemName:lower())  

  if template then
    if template.unique then
      count = 1
    end
    
    if Config.ContainerItems[template.name] then
      local cfgItem = Config.ContainerItems[template.name]
      local itemId = generateUniqueId(registeredInventories,8,8)
      template.itemId = itemId
      registerInventory(itemId,"subinventory",template.label,cfgItem.maxWeight,cfgItem.maxSlots,template.name)
    end
    
    template.quality = quality or 100
    template.name = itemName

    local inventory = registeredInventories[identifier]
    if inventory:checkWeight(template,false,count) then
      inventory:addItem(template,count)

      if source then 
        logAction(source,string.format(_T('added_to_inventory'),(count or 1),template.label)) 
        addNotification(source,true,{label = template.label,name=template.name,count = count or 1})
        refreshInventory(source,inventory,false)
        TriggerEvent("inventory:playerGotItem",identifier,template.name)
      end

      inventory.shouldSave = true
      return true
    else
      local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
      if xPlayer and xPlayer.source then
        notify(xPlayer.source,_T('item_too_heavy'))
      end
      return false
    end
  else
    debugPrint("Invalid item.")
    return false
  end
end)

exports('removeInventoryItem',function(identifier,itemName,count,source)
  local template = getItemTemplate(itemName:lower())

  if template then
    local inventory = registeredInventories[identifier]
    if inventory:removeItem(itemName,(count or 1)) then
      if source then 
        logAction(source,string.format(_T('removed_from_inventory'),(count or 1),template.label)) 
        addNotification(source,false,{label = template.label,name=template.name,count = count or 1})
        refreshInventory(source,inventory,false)
        TriggerEvent("inventory:playerLostItem",identifier,itemName)
      end

      inventory.shouldSave = true

      return true
    else
      return false
    end
  else
    debugPrint("Invalid item.")
    return false
  end
end)

exports('registerInventory',registerInventory)
exports('createInventory',createInventory)

exports('registerVehicleInventory',registerVehicleInventory)

exports('buildInventoryItems',function(items)
  local content = {}
  for i=1,#items,1 do
    if items[i].count > 0 then
      local template = getItemTemplate(items[i].name)
      template.quality = 100
      template.count = tonumber(items[i].count)
      table.insert(content,template)
    end
  end
  return content
end)

exports('deleteInventory',function(id)
  if registeredInventories[id] then
    registeredInventories[id] = nil
    MySQL.Async.execute('DELETE FROM inventories WHERE identifier=@identifier',{
      ['@identifier'] = id
    })
  end
end)

exports('saveInventories',function(cb)
  for k,v in pairs(registeredInventories) do
    v.lastSave = 1
  end
  saveInventoriesCb = cb
end)

exports('saveInventory',function(identifier)
  local inv = registeredInventories[identifier]
  if inv then
    inv.shouldSave = false
    inv.lastSave = os.time()
    inv:save()
  end
end)

exports('setProperty',function(id,key,val)
  local inv = registeredInventories[identifier]
  if inv then
    if type(inv[key]) == "nil" then
      return false
    end

    if type(inv[key]) ~= type(val) then
      return false
    end

    inv[key] = val
    return true
  end
end)

Citizen.CreateThread(function()
  while true do
    local now = os.time()
    for id,inv in pairs(registeredInventories) do
      if Config.DegradeItems then
        if inv.type == "inventory" or inv.type == "subinventory" then
          for k,v in ipairs(inv.items) do
            if v.name and not accountLookup[v.name] then 
              if not v.lastQualityCheck then
                v.lastQualityCheck = now
              end

              if not v.degrademodifier then
                v.degrademodifier = 1.0
              end

              if now - v.lastQualityCheck >= (Config.TimeToDegrade) then
                local modifier = 1.0 * v.degrademodifier
                local modifiers = Config.DegradeModifiers[inv.subtype]
                if modifiers then
                  if modifiers.degradeItems and modifiers.degradeItems[v.name] then
                    modifier = modifiers.degradeModifier * v.degrademodifier
                  else
                    if not modifiers.ignoreItems or not modifiers.ignoreItems[v.name] then
                      modifier = modifiers.degradeModifier * v.degrademodifier
                    end
                  end
                end

                v.quality = math.max(0.0,v.quality - (Config.DegradeQuality * modifier))
                v.lastQualityCheck = now

                if v.quality <= 0 then
                  if v.unique and v.itemId then
                    destroyInventory(v.itemId)
                  end
                  
                  inv:removeCountAtSlot(k,1)

                  if inv.identifier == "ground" then
                    removeGroundItem(v.name,1,v.pos)
                  end

                  if itemTemplates['degraded_'..v.name] then
                    local item = getItemTemplate('degraded_'..v.name)
                    item.quality = 100

                    if tonumber(v.count) > 0 then
                      inv:addItem(item,1)
                    else
                      inv:addItemAtSlot(k,item,1)
                    end
                  end

                  inv.shouldSave = true
                  break
                end
              end
            end
          end
        end
      end

      if inv.shouldSave then
        if not inv.lastSave or ((now - inv.lastSave) > (5 * 60)) then
          inv:save()
          inv.lastSave = now
          inv.shouldSave = false
        end
      end
    end

    if saveInventoriesCb then
      Wait(1000)
      saveInventoriesCb()
      saveInventoriesCb = false
    end

    Wait(5000)
  end
end)

for k,v in pairs(Config.ContainerItems) do
  ESX.RegisterUsableItem(k,function(source,remove,item)
    local id = getPlayerIdentifier(source)
    local otherId = item.itemId

    if id then
      local plyInv = registeredInventories[id]
      local otherInv = registeredInventories[otherId]

      if plyInv and otherInv then
        if not openInventories[otherId] then
          for k,v in pairs(openInventories) do
            if v == source then
              openInventories[k] = nil
            end
          end

          openInventories[id] = source
          openInventories[otherId] = source
          TriggerClientEvent('inventory:openOther',source,true,plyInv,otherInv)
        else
          notify(source,_T('inventory_in_use'))
          TriggerClientEvent('inventory:openOther',source,false)
        end
      else
        notify(source,_T('inventory_not_found'))
        TriggerClientEvent('inventory:openOther',source,false)
      end
    end
  end)
end

--[[
RegisterCommand('getWater',function(source,args)
  local xPlayer = ESX.GetPlayerFromId(source)
  local item = xPlayer.getInventoryItem('water_bottle')
  print(item and type(item) == "table" and json.encode(item) or item)
end)

RegisterCommand('giveWater',function(source,args)
  local xPlayer = ESX.GetPlayerFromId(source)
  xPlayer.addInventoryItem('water_bottle',5)
end)

RegisterCommand('getItems',function(source,args)
  local xPlayer = ESX.GetPlayerFromId(source)
  xPlayer.addInventoryItem('scrap_metal',5)
  Wait(250)
  xPlayer.addInventoryItem('scrap_aluminum',1)
  Wait(250)
  xPlayer.addInventoryItem('basic_tools',1)
  Wait(250)
end)

ESX.RegisterUsableItem('lockpick',function(source,remove)
  remove()
  TriggerClientEvent("inventory:startMinigame",source,3,0.5)
end)

RegisterCommand('saveInventories',function()
  exports["mf-inventory"]:saveInventories(function()
    print("Saved")
  end)
end)

ESX.RegisterUsableItem('meth_raw',function(source,remove,item)
  print(json.encode(item))
  remove()
end)

RegisterCommand('registerInventory',function(source,args)
  local identifier,data = table.unpack(args)
  
  if not identifier then
    identifier = 'downtowncustoms'
  end

  if not data then
    data = {}
  end  

  createInventory(identifier,"inventory","default",identifier,100.0,50,data)
end)
--]]

local inventoryMt = {
  getItemsAtDistance = function(self,maxDist,pos)
    local nearbyItems = {}
    for slot,item in ipairs(self.items) do
      if item.pos then
        local loc = vector3(item.pos.x,item.pos.y,item.pos.z)
        local dist = #(pos - loc)
        if dist <= maxDist then
          table.insert(nearbyItems,{dist = dist, item = item})
        end
      end
    end
    table.sort(nearbyItems,function(a,b)
      return a.dist < b.dist
    end)
    for k,v in ipairs(nearbyItems) do
      nearbyItems[k] = v.item
    end
    return nearbyItems
  end,

  removeItemWithData = function(self,itemName,count,key,value)
    if
      type(self)      ~= "table"    or
      type(itemName)  ~= "string"   or
      type(count)     ~= "number"   or
      type(key)       ~= "string"   or
      type(value)     == "nil"
    then
      return
    end

    for slot,item in ipairs(self.items) do
      if item.count and item.count >= count and item.name == itemName then
        item.count = tonumber(item.count)

        if type(value) == "table" then
          if type(item[key]) == "table" then
            local matched,total = 0,0

            for k,v in pairs(value) do
              if item[key][k] and tostring(item[key][k]) == tostring(v) then
                matched = matched + 1
              end
              total = total + 1
            end

            if matched == total then
              if item.count - count <= 0 then
                self.items[slot] = {}
              else
                item.count = item.count - count
              end

              self.weight = self:getWeight()

              return true
            end
          end
        else
          if item[key] == value then
            if item.count > item.count - count <= 0 then
              self.items[slot] = {}
            else
              item.count = item.count - count
            end

            self.weight = self:getWeight()

            return true
          end
        end
      end
    end

    return false
  end,

  getItemWithData = function(self,key,value)
    if
      type(self)  ~= "table"   or
      type(key)   ~= "string"  or
      type(value) == "nil"
    then
      return
    end

    for slot,item in ipairs(self.items) do
      if type(value) == "table" then
        if type(item[key]) == "table" then
          local matched,count = 0,0
          for k,v in pairs(value) do
            if item[key][k] and tostring(item[key][k]) == tostring(v) then
              matched = matched + 1
            end
            count = count + 1
          end
          if matched == count then
            return item,slot
          end
        end
      else
        if item[key] == value then
          return item,slot
        end
      end
    end

    return false
  end,

  getItem = function(self,itemName,itemCount)
    itemCount = tonumber(itemCount) or 1
    for k,v in ipairs(self.items) do
      if v.name == itemName then
        if not itemCount or v.count >= itemCount then
          return v
        end
      end
    end
    return {name = itemName, count = 0}
  end,

  getItemWithId = function(self,itemId)
    for k,v in ipairs(self.items) do
      if v.itemId == itemId then
        return v
      end
    end
    return {name = itemName, count = 0}
  end,

  addItem = function(self,item,count,newStack)
    count = tonumber(count) or 1
    for s,i in ipairs(self.items) do
      if not i.name then
        item.slot = s
        item.count = count
        self.items[s] = item
        self.weight = self:getWeight()
        self.shouldSave = true
        return true
      elseif i.name == item.name and not i.unique and not newStack then
        self.items[s].count = self.items[s].count + count
        self.weight = self:getWeight()
        self.shouldSave = true
        return true
      end
    end
    return false
  end,

  removeItem = function(self,itemName,count)
    local removeItems = {}
    count = tonumber(count) or 1

    for slot,item in ipairs(self.items) do
      if count > 0 then
        if item.name and item.name == itemName then
          item.count = tonumber(item.count)
          local takeCount = (item.count >= count and count or item.count)
          count = count - takeCount
          removeItems[slot] = takeCount
        end
      else
        break
      end
    end

    if count <= 0 then
      for slot,count in pairs(removeItems) do
        self.items[slot].count = self.items[slot].count - count
        if self.items[slot].count <= 0 then
          self.items[slot] = {}
        end
      end
      self.weight = self:getWeight()
      self.shouldSave = true
      return true
    else
      return false
    end
  end,

  getItemAtSlot = function(self,slot)
    return self.items[slot]
  end,

  addItemAtSlot = function(self,slot,item,count)
    item.slot = slot
    item.count = tonumber(count) or 1
    self.items[slot] = item
    self.weight = self:getWeight()
    self.shouldSave = true
  end,

  removeItemAtSlot = function(self,slot)
    self.items[slot] = {}
    self.weight = self:getWeight()
    self.shouldSave = true
  end,

  addCountAtSlot = function(self,slot,count)
    count = tonumber(count) or 1
    self.items[slot].count = self.items[slot].count + count
    self.weight = self:getWeight()
    self.shouldSave = true
  end,

  removeCountAtSlot = function(self,slot,count)
    count = tonumber(count) or 1
    self.items[slot].count = tonumber(self.items[slot].count) - count
    self.items[slot].quality = 100

    if self.items[slot].count <= 0 then
      self:removeItemAtSlot(slot)
    end

    self.weight = self:getWeight()
    self.shouldSave = true
  end,

  hasAllItems = function(self,items)
    local copy = {}
    for k,v in pairs(items) do
      local itemCopy = {}
      for i,j in pairs(v) do
        itemCopy[i] = j
      end
      copy[k] = itemCopy
    end

    for k,v in ipairs(self.items) do
      for i,j in ipairs(copy) do
        if v.name == j.name then
          local maxTake = math.min(v.count,j.count)
          if maxTake >= j.count then
            j.count = 0
          else
            j.count = j.count - maxTake
          end
        end
      end
    end

    local hasAll = true
    for k,v in ipairs(copy) do
      if v.count > 0 then
        hasAll = false
        break
      end
    end

    return hasAll
  end,

  getWeight = function(self)
    local weight = 0
    for k,v in ipairs(self.items) do
      if v.weight and v.count then
        weight = weight + (v.weight*v.count)
      end
    end
    return weight
  end,

  checkWeight = function(self,addItem,takeItem,count)
    if not addItem or not addItem.name or not count then
      return false
    end

    if self.identifier == "ground" then
      return true
    end

    if not addItem.weight then
      print("Invalid weight for item",addItem.name)
    end

    local addWeight = addItem.weight * (tonumber(count) or 1)
    if takeItem and takeItem.name and addItem.name ~= takeItem.name then
      local takeWeight = takeItem.weight * takeItem.count
      return ((self.weight - takeWeight + addWeight) <= self.maxWeight)
    else
      return ((self.weight + addWeight) <= self.maxWeight)
    end
  end,

  minimal = function(self) 
    return {
      identifier  = self.identifier,
      type        = self.type,
      subtype     = self.subtype,
      label       = self.label,
      weight      = self:getWeight(),
      maxWeight   = self.maxWeight,
      maxSlots    = self.maxSlots,
      items       = self.items
    }
  end,

  save = function(self)
    if type(MySQL) == "table" and type(MySQL.Async) == "table" and (type(MySQL.Async.execute) == "function" or type(MySQL.Async.execute) == "table") then
      MySQL.Async.execute("UPDATE inventories SET data=@data WHERE identifier=@identifier",{
        ['@identifier'] = self.identifier,
        ['@data'] = json.encode(self:minimal())
      })
    end
  end
}

inventoryMt.__index = inventoryMt

setmetatable(inventoryMt,{
  __call = function(self,data)
    local mt = setmetatable(data,self)
    return mt
  end
})

newInventory = function(data)
  return inventoryMt(data)
end

if type(setReady) == "function" then
  setReady(true)
end
local actionLogs = {}
local callback = (Config.UsingESX and ESX.TriggerServerCallback)
local minigameCallback
local nuiLoaded
local vehicleDoorOpen

local showNotification = function(msg)
  AddTextEntry('inventory_notif', msg)
  SetNotificationTextEntry('inventory_notif')
  DrawNotification(false, true)
end

local showHelpNotification = function(msg)
  AddTextEntry('inventory_help', msg)
  DisplayHelpTextThisFrame('inventory_help', false)
end

local internalOpenInventory = function(playerInventory,otherInventory)
  TriggerScreenblurFadeIn(0)
  isOpen = true
  SetNuiFocus(true,true)
  ESX.UI.HUD.SetDisplay(0)
  
  SendNUIMessage({
    message         = "openInventory",
    playerInventory = playerInventory,
    otherInventory  = otherInventory
  })  
end

local internalStartMinigame = function(length,speed,callback)
  length            = (length or 3)
  speed             = (speed or 0.5)
  minigameCallback  = (callback or false)

  minigameOpen = true
  SetNuiFocus(true,true)
  
  SendNUIMessage({
    message = "startMinigame",
    length  = length,
    speed   = speed
  })  
end

local refreshInventory = function(playerInventory,otherInventory)  
  SendNUIMessage({
    message         = "refreshInventory",
    playerInventory = playerInventory,
    otherInventory  = otherInventory
  })  
end

local inventoryClosed = function()
  TriggerScreenblurFadeOut(0)
  isOpen = false
  SetNuiFocus(false,false)

  if Config.DisplayESXHud then
    ESX.UI.HUD.SetDisplay(1)
  end

  if vehicleDoorOpen then
    SetVehicleDoorShut(vehicleDoorOpen.veh,vehicleDoorOpen.doorIndex,true)
    vehicleDoorOpen = false
  end

  TriggerServerEvent("inventory:closed")
end

local disableControls = function(...)
  for i=1,select("#",...),1 do
    local c = select(i,...)
    DisableControlAction(0,c,true)
  end
end

local getVehicleInfront = function(max)
  local ply_ped = GetPlayerPed(-1)
  local ply_pos = GetEntityCoords(ply_ped)
  local ply_fwd = GetEntityForwardVector(ply_ped)
  local up = vector3(0.0,0.0,1.0)

  local from = ply_pos + (up*2)
  local to   = ply_pos - (up*2)

  local res,hit,end_pos,surface_norm,ent_hit
  for i=0,(max or 3),1 do
    local ray = StartShapeTestRay(from.x + (ply_fwd.x*i),from.y + (ply_fwd.y*i),from.z + (ply_fwd.z*i),to.x + (ply_fwd.x*i),to.y + (ply_fwd.y*i),to.z + (ply_fwd.z*i),2,ignore, 0);
    res,hit,end_pos,surface_norm,ent_hit = GetShapeTestResult(ray); 
    if ent_hit and ent_hit ~= 0 and ent_hit ~= -1 then
      local type = GetEntityType(ent_hit)
      if GetEntityType(ent_hit) == 2 then
        return ent_hit
      end
    end
  end
  return false
end

local getTrunkOffset = function(veh)
  local pos = GetEntityCoords(veh)
  local min,max = GetModelDimensions(GetEntityModel(veh))
  local fwd = GetEntityForwardVector(veh)
  local infront,behind = pos+fwd,pos-fwd
  local enginePos = GetWorldPositionOfEntityBone(veh,GetEntityBoneIndexByName(veh,'boot'))
  if #(infront - enginePos) < #(behind - enginePos) then
    return pos - (fwd * min.y),4
  else
    return pos - (fwd * max.y),5
  end
end

local hotkeyPressed = function(index)
  callback("inventory:pressHotkey",function(hotkeyItems)
    SendNUIMessage({
      message = "pressHotkey",
      index = index,
      hotkeyItems = hotkeyItems
    })
  end,index)
end

function openInventory()
  if not isOpening or not isOpen then
    local pos = GetEntityCoords(PlayerPedId())
    isOpening = true

    callback("inventory:openInventory",function(canOpen,playerInventory,otherInventory)
      isOpening = false
      if canOpen then
        internalOpenInventory(playerInventory,otherInventory)
      end
    end,pos)
  end
end

function openVehicleInventory(veh,isInside)
  if not isOpening or not isOpen then
    local plate = ESX.Game.GetVehicleProperties(veh).plate
    local class = GetVehicleClass(veh)
    local pos   = GetEntityCoords(PlayerPedId())

    isOpening = true
    isInside  = isInside or false

    callback("inventory:openVehicleInventory",function(canOpen,playerInventory,vehicleInventory,groundInventory)
      isOpening = false
      if canOpen then
        if vehicleInventory then
          internalOpenInventory(playerInventory,vehicleInventory)
        else
          internalOpenInventory(playerInventory,groundInventory)
        end
        return
      end
    end,plate,class,isInside,pos)
  end
end

function openCrafting(identifier)
  if not isOpening then
    isOpening = true

    callback("inventory:openCrafting",function(canOpen,playerInventory,recipe)
      isOpening = false
      if canOpen then
        internalOpenInventory(playerInventory,recipe)
      end
    end,identifier)
  end
end

function openOtherInventory(identifier)
  if not isOpening or not isOpen then
    isOpening = true
    
    callback("inventory:openOtherInventory",function(canOpen,playerInventory,otherInventory)
      isOpening = false
      if canOpen then
        internalOpenInventory(playerInventory,otherInventory)
      end
    end,tostring(identifier))
  end
end

function closeInventory()
  SendNUIMessage({message = "closeInventory"})
  inventoryClosed()
end

function startMinigame(...)
  if not minigameOpen then
    internalStartMinigame(...)
  end
end

RegisterNetEvent("inventory:notify")
AddEventHandler("inventory:notify",function(msg)
  showNotification(msg)
end)

RegisterNetEvent("inventory:useAmmo")
AddEventHandler("inventory:useAmmo",function(name)
  local ped,hash  = PlayerPedId(),GetHashKey(name)
  local curAmmo   = GetAmmoInPedWeapon(ped,hash)
  local clipSize  = GetMaxAmmoInClip(ped,hash,1)*Config.AddAmmoClips
  local totalAmmo = curAmmo + clipSize
  AddAmmoToPed(ped,hash,clipSize)
  TriggerServerEvent("esx:updateWeaponAmmo",name,totalAmmo)
end)

RegisterNetEvent("inventory:refreshInventory")
AddEventHandler("inventory:refreshInventory",refreshInventory)

RegisterNetEvent("inventory:logAction")
AddEventHandler("inventory:logAction",function(msg)
  table.insert(actionLogs,msg)

  SendNUIMessage({
    message = "updateActions",
    actions = actionLogs
  })
end)

RegisterNetEvent("inventory:useWeapon")
AddEventHandler("inventory:useWeapon",function(weaponName)
  local _,weaponHash = GetCurrentPedWeapon(PlayerPedId(),1)
  if weaponHash and weaponHash ~= GetHashKey(weaponName) then
    SetCurrentPedWeapon(PlayerPedId(),GetHashKey(weaponName),true)
  else
    SetCurrentPedWeapon(PlayerPedId(),GetHashKey('WEAPON_UNARMED'),true)
  end
end)

RegisterNetEvent("inventory:addNotification")
AddEventHandler("inventory:addNotification",function(added,item)
  if not isOpen then
    SendNUIMessage({
      message = "addNotification",
      added = added,
      item = item
    })
  end
end)

RegisterNetEvent("esx:setAccountMoney")
AddEventHandler("esx:setAccountMoney",function(account)
  if account.name == "money" then
    SendNUIMessage({
      message = "setMoney",
      money = account.money
    })
  end
end)

RegisterNetEvent("inventory:startMinigame")
AddEventHandler("inventory:startMinigame",function(...)
  startMinigame(...)
end)

RegisterNetEvent('inventory:openOther')
AddEventHandler('inventory:openOther',function(canOpen,playerInventory,otherInventory)
  if canOpen then
    internalOpenInventory(playerInventory,otherInventory)
  end
end)

RegisterNetEvent("inventory:addGroundItem")
AddEventHandler("inventory:addGroundItem",function(name,count,pos)
  if not groundItems then
    return
  end

  table.insert(groundItems,{
    name = name,
    count = count,
    pos = pos
  })
end)

RegisterNetEvent("inventory:removeGroundItem")
AddEventHandler("inventory:removeGroundItem",function(name,count,pos)
  if not groundItems then
    return
  end

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
end)

RegisterNUICallback('closed',inventoryClosed)

RegisterNUICallback('useItem',function(data)
  if Config.CloseOnUse[data.item.name] then
    closeInventory()
  end
  TriggerServerEvent("inventory:useItem",data.fromIdentifier,data.fromIndex)
end)

RegisterNUICallback('closedMinigame',function()
  if not isOpen then
    SetNuiFocus(false,false)

    if Config.DisplayESXHud then
      ESX.UI.HUD.SetDisplay(1)
    end
  end

  if minigameCallback then
    minigameCallback(false)
    minigameCallback = false
  end

  minigameOpen = false
end)

RegisterNUICallback('minigameComplete',function(data)
  if not isOpen then
    SetNuiFocus(false,false)

    if Config.DisplayESXHud then
      ESX.UI.HUD.SetDisplay(1)
    end
  end

  if minigameCallback then
    minigameCallback(data.result)
    minigameCallback = false
  end
  
  minigameOpen = false
end)

RegisterNUICallback('move',function(data)
  callback("inventory:move",function(playerInventory,otherInventory)
    refreshInventory(playerInventory,otherInventory)
  end,data.identifier,data.fromIndex,data.toIndex,data.item,data.count,GetEntityCoords(PlayerPedId()))
end)

RegisterNUICallback('craft',function(data)
  callback("inventory:craft",function(playerInventory,recipes)
    refreshInventory(playerInventory,recipes)
  end,data.identifier,data.recipe)
end)

RegisterNUICallback('purchase',function(data)
  callback("inventory:purchaseItem",function(playerInventory,otherInventory)
    refreshInventory(playerInventory,otherInventory)
  end,data.fromIdentifier,data.fromIndex,data.toIndex,data.item,data.count)
end)

RegisterNUICallback('sell',function(data)
  callback("inventory:sellItem",function(playerInventory,otherInventory)
    refreshInventory(playerInventory,otherInventory)
  end,data.toIdentifier,data.fromIndex,data.toIndex,data.item,data.count)
end)

RegisterNUICallback('transfer',function(data)
  callback("inventory:transferItem",function(playerInventory,otherInventory)
    internalOpenInventory(playerInventory,otherInventory)
  end,data.fromIdentifier,data.toIdentifier,data.fromIndex,data.toIndex,data.item,data.count,GetEntityCoords(PlayerPedId()))
end)

RegisterNUICallback('loaded',function()
  nuiLoaded = true
end)

exports('openInventory',function()
  if not isOpening and not isOpen then
    local ped = PlayerPedId()
    
    if IsPedInAnyVehicle(ped,false) then
      local inVeh = GetVehiclePedIsIn(ped,false)
      if GetPedInVehicleSeat(inVeh,-1) == ped or GetPedInVehicleSeat(inVeh,0) == ped then
        openVehicleInventory(inVeh,true)
        return
      end
    else   
      local pos = GetEntityCoords(ped)
      local veh = getVehicleInfront(2)
      if veh and veh > 0 then
        if not IsThisModelABike(GetEntityModel(veh)) then 
          local doorPos,doorIndex = getTrunkOffset(veh)
          local plate = ESX.Game.GetVehicleProperties(veh).plate
          if #(doorPos - GetEntityCoords(ped)) <= 1.5 then
            local locked = GetVehicleDoorLockStatus(veh)
            if (locked ~= 2 and locked ~= 3) then
              if GetIsDoorValid(veh,doorIndex) then
                vehicleDoorOpen = {
                  veh = veh,
                  doorIndex = doorIndex
                }
                SetVehicleDoorOpen(veh,doorIndex,false,true)
                openVehicleInventory(veh)   
                return
              else
                showNotification(_T('vehicle_no_trunk'))
              end     
            end
          end
        end
      end
    end

    openInventory()
  end
end)

exports('getInventoryItems',function(identifier,cb)
  callback("inventory:getInventoryItems",function(items)
    cb(items)
  end,identifier)
end)

exports('openCrafting',openCrafting)
exports('openOtherInventory',openOtherInventory)
exports('startMinigame',startMinigame)

Citizen.CreateThread(function()
  callback("inventory:getGroundItems",function(items)
    groundItems = {}

    for k,v in ipairs(items) do
      table.insert(groundItems,{
        name = v.name,
        count = v.count,
        pos = vector3(v.pos.x,v.pos.y,v.pos.z) 
      })
    end

    while not ESX.IsPlayerLoaded() do Wait(500) end
    
    local playerData = ESX.GetPlayerData()
    local plyId = playerData.identifier
    local plyMoney = 0

    for k,v in pairs(playerData.accounts) do
      if v.name == "money" then
        plyMoney = v.money
        break
      end
    end  

    while not nuiLoaded do
      SendNUIMessage({
        message       = "init",
        resourceName  = GetCurrentResourceName(),
        plyId         = plyId,
        plyMoney      = plyMoney,
        translations  = _T()
      })
      Wait(500)
    end

    local maxMarkerOpacity = 100
    while true do
      if isOpen or minigameOpen then
        HideHudAndRadarThisFrame()
      else
        disableControls(157,158,160,164)

        if      IsDisabledControlJustPressed(0,157) then
          hotkeyPressed(1)
        elseif  IsDisabledControlJustPressed(0,158) then
          hotkeyPressed(2)
        elseif  IsDisabledControlJustPressed(0,160) then
          hotkeyPressed(3)
        elseif  IsDisabledControlJustPressed(0,164) then
          hotkeyPressed(4)
        end

        if Config.ShowGroundItems then
          local pos = GetEntityCoords(PlayerPedId())

          local nearbyItems = {}
          for k,v in ipairs(groundItems) do
            local dist = #(v.pos - pos)
            if dist <= Config.PickupDistance then
              local add = true
              for key,val in ipairs(nearbyItems) do
                if #(v.pos - val) < 1.0 then
                  add = false
                  break
                end
              end

              if add then
                table.insert(nearbyItems,v.pos)
              end
            end
          end

          for k,v in ipairs(nearbyItems) do
            DrawMarker(3, v.x,v.y,v.z, 0.0,0.0,0.0, 0.0,180.0,0.0, 0.1,0.1,0.1, 255,255,255,150, false,true,2)
          end


          --[[
          local averagePos = vector3(0.0,0.0,0.0)
          local count = 0
          for k,v in ipairs(groundItems) do
            local dist = #(v.pos - pos)
            if dist <= Config.PickupDistance then
              averagePos = averagePos + v.pos
              count = count + 1
            end
          end

          if count > 0 then
            averagePos = averagePos / count
            DrawMarker(3, averagePos.x,averagePos.y,averagePos.z, 0.0,0.0,0.0, 0.0,180.0,0.0, 0.1,0.1,0.1, 255,255,255,150, false,true,2)
          end
          ]]
        end
      end
      Wait(0)
    end
  end)
end)

--[[
RegisterCommand('inventory:openCrafting',function(source,args)
  local identifier = args and args[1] or "example_recipe"
  exports["mf-inventory"]:openCrafting(identifier)
end)

RegisterCommand('inventory:openOther',function(source,args)
  local identifier = args and args[1] or "example_shop:1"
  exports["mf-inventory"]:openOtherInventory(identifier)
end)

RegisterCommand('inventory:minigame',function(source,args)
  exports["mf-inventory"]:startMinigame(4,0.6,function(res)
    print("Minigame complete",res)
  end)
end)
--]]



local backpackItemNames = {
  'backpack'
}

local backpackLookup = {}
for k,v in ipairs(backpackItemNames) do
  backpackLookup[v] = true
end

AddEventHandler("inventory:playerGotItem",function(identifier,itemName)
  local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
  if xPlayer and xPlayer.source then
    TriggerClientEvent("inventory:equipBackpack",xPlayer.source)
  end
end)

AddEventHandler("inventory:playerLostItem",function(identifier,itemName)
  local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
  if xPlayer and xPlayer.source then
    local backpackCount = 0
    for i=1,#backpackItemNames do
      backpackCount = backpackCount + xPlayer.getInventoryItem(backpackItemNames[i]).count
    end

    if backpackCount <= 0 then
      TriggerClientEvent("inventory:unequipBackpack",xPlayer.source)
    end
  end
end)
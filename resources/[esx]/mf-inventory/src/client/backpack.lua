RegisterNetEvent("inventory:equipBackpack")
AddEventHandler("inventory:equipBackpack",function()
  local backpack = GetPedDrawableVariation(ped,5)
  if backpack <= 0 then
    SetPedComponentVariation(PlayerPedId(),5,31,0,0)
  end
end)

RegisterNetEvent("inventory:unequipBackpack")
AddEventHandler("inventory:unequipBackpack",function()
  SetPedComponentVariation(PlayerPedId(),5,0,0,0)
end)
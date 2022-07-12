__Locales = {}

_T = {}

setmetatable(_T,{
  __call = function(t,k)
    if k then
      return __Locales[Config.Locale] and __Locales[Config.Locale][k] or 'UNKNOWN_STRING'
    end

    return __Locales[Config.Locale]
  end,
  __index = function(t,k)
    if not k then
      return
    end

    return __Locales[Config.Locale] and __Locales[Config.Locale][k] or 'UNKNOWN_STRING' 
  end
})
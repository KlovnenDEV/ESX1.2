fx_version 'bodacious'
games { 'rdr3', 'gta5' }

mod 'mf-inventory'
version '1.0.3'

-- Leaked By: Leaking Hub | J. Snow | leakinghub.com

ui_page 'nui/index.html'

shared_scripts {
  'locale.lua',
  'locales/en.lua',
  'config.lua',  
}

client_scripts {
  'src/client/main.lua',
  --'src/client/backpack.lua',
}

server_scripts {
  '@mysql-async/lib/MySQL.lua',
  'src/server/main.lua',
  --'src/server/backpack.lua',
}

files {
  'nui/index.html',
  'nui/items/*.png',
  'nui/icons/*.png',
}

dependencies {
  'mysql-async',
  'es_extended',
}

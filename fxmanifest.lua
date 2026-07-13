fx_version 'cerulean'
game 'gta5'

author 'RadiantCoast / FAUX'
description 'Creator, streamer, admin, and management referral system with NUI dashboard and website bridge sync.'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/app.js',
  'html/img/logo.png',
  'html/img/Logo_cropped.png',
  'html/img/contract-bg.avif'
}

shared_scripts {
  'config.lua'
}

client_scripts {
  'client/main.lua'
}

server_scripts {
  'server/main.lua'
}

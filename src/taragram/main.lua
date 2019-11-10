local fio = require('fio')
local log = require('log')
local yaml = require('yaml')
local TelegramBot
TelegramBot = require('taragram').TelegramBot
local die
die = function(...)
  log.error(...)
  return os.exit(1)
end
local configure_proxy
configure_proxy = function(proxy_url)
  os.setenv('http_proxy', proxy_url)
  return os.setenv('https_proxy', proxy_url)
end
local load_config
load_config = function()
  local config_path = os.getenv('TARAGRAM_CONFIG_PATH')
  if config_path then
    config_path = fio.abspath(config_path)
  else
    config_path = fio.pathjoin(fio.cwd(), 'config.yaml')
  end
  log.info('using config: %s', config_path)
  if not fio.path.is_file(config_path) then
    die('%s does not exist or is not a file', config_path)
  end
  local fh, err = fio.open(config_path)
  if not fh then
    die(err)
  end
  local config_content = fh:read()
  if not config_content then
    die('error reading config file')
  end
  local ok, config = pcall(yaml.decode, config_content)
  if not ok then
    die('error parsing config file: %s', config)
  end
  return config
end
local config = load_config()
if config.proxy then
  configure_proxy(config.proxy)
end
if not config.api_token then
  die('api_token is not set')
end
local bot = TelegramBot(config.api_token)
local resp, err = bot:get_me()
if not resp then
  die(err)
end
log.info('bot username: %s', resp.username)
local message_channel = bot:start_polling('polling_fiber')
while true do
  local msg = message_channel:get()
  log.info(msg)
  if msg.text == '/fin' then
    bot:stop_polling()
    break
  end
end

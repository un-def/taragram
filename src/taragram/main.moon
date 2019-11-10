fio = require 'fio'
log = require 'log'
yaml = require 'yaml'

import TelegramBot from require 'taragram'


die = (...) ->
    log.error ...
    os.exit 1


configure_proxy = (proxy_url) ->
    os.setenv 'http_proxy', proxy_url
    os.setenv 'https_proxy', proxy_url


load_config = ->
    config_path = os.getenv 'TARAGRAM_CONFIG_PATH'
    if config_path
        config_path = fio.abspath config_path
    else
        config_path = fio.pathjoin fio.cwd!, 'config.yaml'
    log.info 'using config: %s', config_path
    if not fio.path.is_file config_path
        die '%s does not exist or is not a file', config_path
    fh, err = fio.open config_path
    if not fh
        die err
    config_content = fh\read!
    if not config_content
        die 'error reading config file'
    ok, config = pcall yaml.decode, config_content
    if not ok
        die 'error parsing config file: %s', config
    return config


config = load_config!
if config.proxy
    configure_proxy config.proxy
if not config.api_token
    die 'api_token is not set'
bot = TelegramBot(config.api_token)
resp, err = bot\get_me!
if not resp
    die err
log.info 'bot username: %s', resp.username
master_id = config.master_id
message_channel = bot\start_polling 'polling_fiber'
while true
    msg = message_channel\get!
    log.info msg
    bot\send_message master_id, '```%s```'\format(yaml.encode msg), {parse_mode: 'markdown'}

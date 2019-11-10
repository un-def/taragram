local fiber = require('fiber')
local http_client = require('http.client')
local json = require('json')
local TelegramBot
do
  local _class_0
  local _base_0 = {
    url_template = 'https://api.telegram.org/bot%s/',
    call_timeout = 10,
    poll_timeout = 30,
    call = function(self, method, body, content_type, timeout)
      local url = self.base_url .. method
      local headers = {
        ['user-agent'] = 'taragram/0.0.0',
        ['content-type'] = content_type,
        ['accept'] = 'application/json'
      }
      if not timeout then
        timeout = self.call_timeout
      end
      local resp = self.client:request('POST', url, body, {
        timeout = timeout,
        headers = headers
      })
      if not resp then
        return nil, 'unknown http.client error'
      end
      local ok, decoded = pcall(json.decode, resp.body)
      if not ok then
        return nil, ('[HTTP:%s] %s'):format(resp.status, resp.reason)
      end
      if not decoded.ok then
        return nil, ('[API:%s] %s'):format(decoded.error_code, decoded.description)
      end
      return decoded.result
    end,
    call_json = function(self, method, params, timeout)
      local body = json.encode(params)
      return self:call(method, body, 'application/json', timeout)
    end,
    get_me = function(self)
      return self:call('getMe')
    end,
    send_message = function(self, chat_id, text, params)
      params = self:_prepare_params(params)
      params.chat_id = tonumber(chat_id)
      params.text = text
      return self:call_json('sendMessage', params)
    end,
    start_polling = function(self, fiber_name, allowed_updates, timeout)
      if self._polling_fiber then
        return nil, 'already polling'
      end
      if not timeout then
        timeout = self.poll_timeout
      end
      local fb = fiber.create(self._poll, self, allowed_updates, timeout)
      fb:name(fiber_name)
      self._polling_fiber = fb
      return self._message_channel
    end,
    stop_polling = function(self)
      local fb = self._polling_fiber
      if not fb then
        return nil, 'polling is not started'
      end
      fb:cancel()
      self._polling_fiber = nil
      return true
    end,
    _poll = function(self, allowed_updates, timeout)
      local offset = nil
      while true do
        fiber.testcancel()
        local messages
        messages, offset = self:_poll_once(allowed_updates, offset, timeout)
        if messages then
          for _index_0 = 1, #messages do
            local msg = messages[_index_0]
            self._message_channel:put(msg)
          end
        end
      end
    end,
    _poll_once = function(self, allowed_updates, offset, timeout)
      local res, err = self:call_json('getUpdates', {
        offset = offset,
        limit = 100,
        timeout = timeout,
        allowed_updates = allowed_updates
      }, timeout + 5)
      if not res then
        return nil, offset, err
      end
      if #res == 0 then
        return nil, offset
      end
      local messages
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #res do
          local e = res[_index_0]
          _accum_0[_len_0] = e.message
          _len_0 = _len_0 + 1
        end
        messages = _accum_0
      end
      offset = res[#res].update_id + 1
      return messages, offset
    end,
    _prepare_params = function(self, params)
      if not params then
        return { }
      end
      local _tbl_0 = { }
      for k, v in pairs(params) do
        _tbl_0[k] = v
      end
      return _tbl_0
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, api_token, call_timeout, poll_timeout)
      if call_timeout then
        self.call_timeout = call_timeout
      end
      if poll_timeout then
        self.poll_timeout = poll_timeout
      end
      self.base_url = self.url_template:format(api_token)
      self.client = http_client.new()
      self._message_channel = fiber.channel()
    end,
    __base = _base_0,
    __name = "TelegramBot"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  TelegramBot = _class_0
end
return {
  TelegramBot = TelegramBot
}

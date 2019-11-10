fiber = require 'fiber'
http_client = require 'http.client'
json = require 'json'


class TelegramBot

    url_template: 'https://api.telegram.org/bot%s/'
    call_timeout: 10
    poll_timeout: 30

    new: (api_token) =>
        @base_url = @url_template\format(api_token)
        @client = http_client.new!
        @_message_channel = fiber.channel!

    call: (method, body, content_type, timeout) =>
        url = @base_url .. method
        headers =
            ['user-agent']: 'taragram/0.0.0'
            ['content-type']: content_type
            ['accept']: 'application/json'
        if not timeout
            timeout = @call_timeout
        resp = @client\request 'POST', url, body, {
            timeout: timeout
            headers: headers
        }
        if not resp
            return nil, 'unknown http.client error'
        ok, decoded = pcall json.decode, resp.body
        if not ok
            return nil, '[HTTP:%s] %s'\format(resp.status, resp.reason)
        if not decoded.ok
            return nil, '[API:%s] %s'\format(
                decoded.error_code, decoded.description)
        return decoded.result

    call_json: (method, params, timeout) =>
        body = json.encode params
        return @call method, body, 'application/json', timeout

    get_me: => @call 'getMe'

    start_polling: (fiber_name, allowed_updates, timeout) =>
        if @_polling_fiber
            return nil, 'already polling'
        fb = fiber.create @_poll, @, allowed_updates, timeout
        fb\name fiber_name
        @_polling_fiber = fb
        return @_message_channel

    stop_polling: =>
        fb = @_polling_fiber
        if not fb
            return nil, 'polling is not started'
        fb\cancel!
        @_polling_fiber = nil
        return true

    _poll: (allowed_updates, timeout) =>
        if not timeout
            timeout = @poll_timeout
        offset = nil
        while true
            fiber.testcancel!
            messages, offset = @_poll_once allowed_updates, offset, timeout
            if messages
                @_message_channel\put msg for msg in *messages

    _poll_once: (allowed_updates, offset, timeout) =>
        res, err = @call_json 'getUpdates', {
            offset: offset
            limit: 100
            timeout: timeout
            allowed_updates: allowed_updates
        }, timeout + 5
        if not res
            return nil, offset, err
        if #res == 0
            return nil, offset
        messages = [e.message for e in *res]
        offset = res[#res].update_id + 1
        return messages, offset


:TelegramBot

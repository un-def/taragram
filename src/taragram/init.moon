fiber = require 'fiber'
http_client = require 'http.client'
json = require 'json'


table_insert = table.insert


UPDATE_TYPES = {
    MESSAGE: 'message'
    EDITED_MESSAGE: 'edited_message'
    CHANNEL_POST: 'channel_post'
    EDITED_CHANNEL_POST: 'edited_channel_post'
    INLINE_QUERY: 'inline_query'
    CHOSEN_INLINE_RESULT: 'chosen_inline_result'
    CALLBACK_QUERY: 'callback_query'
    SHIPPING_QUERY: 'shipping_query'
    PRE_CHECKOUT_QUERY: 'pre_checkout_query'
    POLL: 'poll'
}


UPDATE_TYPES_SET = {t, true for _, t in pairs UPDATE_TYPES}


class TelegramBot

    url_template: 'https://api.telegram.org/bot%s/'
    call_timeout: 10
    poll_timeout: 30

    new: (api_token, call_timeout, poll_timeout) =>
        if call_timeout
            @call_timeout = call_timeout
        if poll_timeout
            @poll_timeout = poll_timeout
        @base_url = @url_template\format(api_token)
        @client = http_client.new!
        @_update_channel = fiber.channel!

    -- generic API method calls

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

    -- concrete API method calls

    get_me: => @call 'getMe'

    send_message: (chat_id, text, params) =>
        params = @_prepare_params params
        params.chat_id = tonumber chat_id
        params.text = text
        return @call_json 'sendMessage', params

    answer_callback_query: (callback_query_id, params) =>
        params = @_prepare_params params
        params.callback_query_id = callback_query_id
        return @call_json 'answerCallbackQuery', params

    -- polling methods

    start_polling: (fiber_name, allowed_updates, timeout) =>
        if @_polling_fiber
            return nil, 'already polling'
        if not allowed_updates
            allowed_updates = {}
        if not timeout
            timeout = @poll_timeout
        fb = fiber.create @_poll, @, allowed_updates, timeout
        fb\name fiber_name
        @_polling_fiber = fb
        return @_update_channel

    stop_polling: =>
        fb = @_polling_fiber
        if not fb
            return nil, 'polling is not started'
        fb\cancel!
        @_polling_fiber = nil
        return true

    _poll: (allowed_updates, timeout) =>
        offset = nil
        while true
            fiber.testcancel!
            updates, offset = @_poll_once allowed_updates, offset, timeout
            if updates
                @_update_channel\put upd for upd in *updates

    _poll_once: (allowed_updates, offset, timeout) =>
        updates, err = @call_json 'getUpdates', {
            offset: offset
            limit: 100
            timeout: timeout
            allowed_updates: allowed_updates
        }, timeout + 5
        if not updates
            return nil, offset, err
        if #updates == 0
            return nil, offset
        extracted_updates = {}
        for update in *updates
            local update_type, object
            for key, value in pairs update
                if key ~= 'update_id' and UPDATE_TYPES_SET[key]
                    update_type = key
                    object = value
                    break
            assert object, 'cannot find any object in Update'
            table_insert extracted_updates, {type: update_type, :object}
        offset = updates[#updates].update_id + 1
        return extracted_updates, offset

    _prepare_params: (params) =>
        if not params
            return {}
        return {k, v for k, v in pairs params}


:UPDATE_TYPES, :TelegramBot

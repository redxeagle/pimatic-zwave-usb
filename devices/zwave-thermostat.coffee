# coffeelint: disable=max_line_length

module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  
  class ZwaveThermostat extends env.devices.HeatingThermostat
    constructor: (@config, @plugin, lastState) ->
      @_base = commons.base @, @config.class
      @debug = @plugin.debug || false

      @id = @config.id
      @name = @config.name
      @node = @config.node
      @value_id = null

      @_mode = "auto"
      @_setSynced(false)
      
      @responseHandler = @_createResponseHandler()
      @plugin.protocolHandler.on 'response', @responseHandler
      
      @_temperatureSetpoint = lastState?.temperatureSetpoint?.value
      @_battery = lastState?.battery?.value or "--"
      @_lastSendTime = 0

      super()

    _createResponseHandler: () ->
      return (response) =>
        _node = if @node is response.nodeid then response.nodeid else null
        data = response.zwave_response

        if _node?
          #Update the temperture
          @_base.debug "data:", @_temperatureSetpoint, data.class_id
          @value_id = data.value_id

          if data.class_id is 67
            @_base.debug "Response", response
            @_base.debug "update temperture", data.value
            @_setSetpoint(parseInt(data.value))
            @_setValve(parseInt(data.value) / 40 * 100) #40 == 100%
            @_setSynced(true)

          if data.class_id is 128
            @_base.debug "Response", response
            @_base.debug "Update battery", data.value
            battery_value = if parseInt(data.value) == 0 then 'LOW' else 'OK'
            @_setBattery(battery_value)

    _callbackHandler: () ->
      return (response) =>
        #@TODO: ???
        console.log('what is this.. when does it happen?? (_callbackHandler in ZwaveThermostat)')

    destroy: () ->
      @_base.cancelUpdate()
      @plugin.protocolHandler.removeListener 'response', @responseHandler
      super()

    changeTemperatureTo: (temperatureSetpoint) =>
      if @_temperatureSetpoint is temperatureSetpoint then return Promise.resolve()

      if(@value_id)
        @plugin.protocolHandler.sendRequest({ value_id: @value_id, node_id: @node, class_id: 67, instance:1, index:1}, parseFloat(temperatureSetpoint).toFixed(2), "thermostat")
      else
        @_base.info "Please wake up ", @name, " device has no value_id yet"

      return @_setSetpoint(parseInt(temperatureSetpoint))

    getTemperature: -> Promise.resolve(@_temperatureSetpoint)

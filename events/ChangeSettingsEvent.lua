local ChangeSettingsEvent = {}
UniversalAutoload.ChangeSettingsEvent = ChangeSettingsEvent

local ChangeSettingsEvent_mt = Class(ChangeSettingsEvent, Event)
InitEventClass(ChangeSettingsEvent, "ChangeSettingsEvent")
-- print("  UniversalAutoload - ChangeSettingsEvent")

function ChangeSettingsEvent.emptyNew()
	local self = Event.new(ChangeSettingsEvent_mt)
	return self
end

function ChangeSettingsEvent.new(vehicle)
	local self = ChangeSettingsEvent.emptyNew()
	self.vehicle = vehicle
	return self
end

function ChangeSettingsEvent:readStream(streamId, connection)
	print("Change Settings Event - readStream")

	local function recieveValues(k, v, parentKey, currentKey, currentValue, finalValue)
		if currentKey then
			local newValue = nil
			if streamReadBool(streamId) == true then
				if v.valueType == "BOOL" then
					newValue = streamReadBool(streamId)
				elseif v.valueType == "INT" then
					newValue = streamReadInt16(streamId)
				elseif v.valueType == "FLOAT" then
					newValue = streamReadFloat32(streamId)
				elseif v.valueType == "STRING" then
					newValue = streamReadString(streamId)
				elseif v.valueType == "VECTOR_TRANS" then
					local x = streamReadFloat32(streamId)
					local y = streamReadFloat32(streamId)
					local z = streamReadFloat32(streamId)
					newValue = {x, y, z} 
				end
				currentValue[v.id] = newValue
				print("  << " .. tostring(currentKey) .. " = " .. tostring(newValue))
			end
		end
	end
	
	print("RECEIVE SETTINGS")
	local vehicle = NetworkUtil.readNodeObject(streamId)
	print("vehicle: " .. tostring(vehicle))
	
	local config = {}
	print("options:")
	iterateDefaultsTable(UniversalAutoload.OPTIONS_DEFAULTS, "", ".options", config, recieveValues)

	print("loadingAreas:")
	config.loadArea = {}
	nAreas = streamReadInt8(streamId) or 0
	for j=1, nAreas do
		config.loadArea[j] = {}
		local loadAreaKey = string.format(".loadingArea(%d)", j-1)
		iterateDefaultsTable(UniversalAutoload.LOADING_AREA_DEFAULTS, configKey, loadAreaKey, config.loadArea[j], recieveValues)
	end
	
	print("CONFIG RECIEVED ON SERVER:")
	DebugUtil.printTableRecursively(config, "--", 0, 2)
	
	for id, value in pairs(deepCopy(config)) do
		vehicle.spec_universalAutoload[id] = value
	end
	vehicle.spec_universalAutoload.initialised = nil
	vehicle.spec_universalAutoload.isAutoloadAvailable = true
	
	print("VEHICLE UPDATED ON SERVER:")
	DebugUtil.printTableRecursively(vehicle.spec_universalAutoload, "--", 0, 2)

	UniversalAutoloadManager.saveVehicleConfigurationToSettings(vehicle, noEventSend)
	
end

function ChangeSettingsEvent:writeStream(streamId, connection)
	print("Change Settings Event - writeStream")

	local function sendValues(k, v, parentKey, currentKey, currentValue, finalValue)
		if currentKey then
			if finalValue == nil or finalValue == v.default then
				streamWriteBool(streamId, false)
			else
				streamWriteBool(streamId, true)
				if v.valueType == "BOOL" then
					streamWriteBool(streamId, finalValue)
				elseif v.valueType == "INT" then
					streamWriteInt16(streamId, finalValue)
				elseif v.valueType == "FLOAT" then
					streamWriteFloat32(streamId, finalValue)
				elseif v.valueType == "STRING" then
					streamWriteString(streamId, finalValue)
				elseif v.valueType == "VECTOR_TRANS" then
					local x, y, z = unpack(finalValue)
					streamWriteFloat32(streamId, x)
					streamWriteFloat32(streamId, y)
					streamWriteFloat32(streamId, z)
				end
				print("  >> " .. tostring(currentKey) .. " = " .. tostring(finalValue))
			end
		end
	end
	
	print("SEND VEHICLE CONFIG TO SERVER")
	local spec = self.vehicle.spec_universalAutoload or {}
	local _, configName, configId = UniversalAutoloadManager.getVehicleConfigNames(self.vehicle)
	
	print("vehicle: " .. tostring(self.vehicle))
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	
	print("options:")
	iterateDefaultsTable(UniversalAutoload.OPTIONS_DEFAULTS, "", ".options", spec, sendValues)

	print("loadingAreas:")
	local nAreas = #(spec.loadArea or {})
	streamWriteInt8(streamId, nAreas)
	for j, loadArea in pairs(spec.loadArea or {}) do
		local loadAreaKey = string.format(".loadingArea(%d)", j-1)
		iterateDefaultsTable(UniversalAutoload.LOADING_AREA_DEFAULTS, configKey, loadAreaKey, spec.loadArea[j], sendValues)
	end

end

function ChangeSettingsEvent.sendEvent(vehicle, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server == nil then
			print("client: Change Settings Event")
			g_client:getServerConnection():sendEvent(ChangeSettingsEvent.new(vehicle))
		end
	end
end
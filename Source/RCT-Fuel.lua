--[[
	---------------------------------------------------------
            RCT FuelDisplay for RCT Jeti FuelSensor
    ---------------------------------------------------------
    
    All-In-One app to display all information in one double
    telemetry-screen on main-screen.
    
    Features:
    - Minimal settings
    - Bar graph for fuel remaining, "Fuel tank"
    - Fuel flow as number-value
    - Fuel sonsumption as number-value
    
    German translation by Alexander Fromm - Vielen danke!
	---------------------------------------------------------
	RCT FuelDisplay is part of RC-Thoughts Jeti Tools.
	---------------------------------------------------------
	Released under MIT-license by Tero @ RC-Thoughts.com 2017
	---------------------------------------------------------
--]]
collectgarbage()
--------------------------------------------------------------------------------
-- Locals for the application
local consumption, flow, fuelRemaining, alarmVoice = 0, 0, 0, false
local playDone, sensorId, sensorPa, alarmValue
--------------------------------------------------------------------------------
-- Read translations
local function setLanguage()
    local lng=system.getLocale()
    local file = io.readall("Apps/Lang/RCT-Fuel.jsn")
    local obj = json.decode(file)
    if(obj) then
        trans18 = obj[lng] or obj[obj.default]
    end
    collectgarbage()
end
--------------------------------------------------------------------------------
local function FuelGauge(percentage, ox, oy)
    
    -- Fuel bar 
    lcd.drawRectangle (5+ox,53+oy,25,11)
    lcd.drawRectangle (5+ox,41+oy,25,11)  
    lcd.drawRectangle (5+ox,29+oy,25,11)  
    lcd.drawRectangle (5+ox,17+oy,25,11)  
    lcd.drawRectangle (5+ox,5+oy,25,11)
    -- Bar chart
    local nSolidBar = math.floor( percentage / 20 )
    local nFracBar = (percentage - nSolidBar * 20) / 20
    local i
    -- Solid bars
    for i=0, nSolidBar - 1, 1 do 
        lcd.drawFilledRectangle (5+ox,53-i*12+oy,25,11) 
    end  
    -- Fractional bar
    local y = math.floor( 53-nSolidBar*12+(1-nFracBar)*11 + 0.5)
    lcd.drawFilledRectangle (5+ox,y+oy,25,11*nFracBar) 
    -- Set fized text's
    lcd.drawText(40, 1, trans18.fuelCons, FONT_MINI)
    lcd.drawText(40, 36, trans18.fuelFlow, FONT_MINI)
    lcd.drawText(128, 15, trans18.consUnit, FONT_BOLD)
    lcd.drawText(108, 49, trans18.flowUnit, FONT_BOLD)
    -- Display flow & consumption-values
    lcd.drawText(126 - lcd.getTextWidth(FONT_BIG,string.format("%.0f",consumption)),12,string.format("%.0f",consumption),FONT_BIG)
    lcd.drawText(106 - lcd.getTextWidth(FONT_BIG,string.format("%.0f",flow)),46,string.format("%.0f",flow),FONT_BIG)
    collectgarbage()
end
--------------------------------------------------------------------------------
local function dispFuel(width, height)
    -- Set max percentage to 99 for drawing
    if( fuelRemaining > 99 ) then 
        fuelRemaining = 99
    end
    FuelGauge(fuelRemaining, 1, 0)   
    -- Field lines
    lcd.drawLine(37,2,37,66)  
    lcd.drawLine(37,35,148,35)
end
--------------------------------------------------------------------------------
-- Take care of user's settings-changes
local function sensorChanged(value)
	sensorId  = sensorsAvailable[value].id
	system.pSave("sensorId", sensorId)
end

local function alarmValueChanged(value)
    alarmValue = value
    system.pSave("alarmValue", alarmValue)
end

local function alarmVoiceChanged(value)
    alarmVoice = value
    system.pSave("alarmVoice", alarmVoice)
end
--------------------------------------------------------------------------------
-- Draw the main form (Application inteface)
local function initForm(formID)
    -- List sensors only if menu is active to preserve memory at runtime 
    -- (measured up to 25% save if menu is not opened)
    sensorsAvailable = {}
    local available = system.getSensors();
    local list={}
    local curIndex=-1
    local descr = ""
    for index,sensor in ipairs(available) do 
        if(sensor.param == 0) then
            list[#list+1] = sensor.label
            sensorsAvailable[#sensorsAvailable+1] = sensor
            if(sensor.id==sensorId ) then
                curIndex=#sensorsAvailable
            end 
        end
    end 
    
    local form, addRow, addLabel = form, form.addRow ,form.addLabel
    local addIntbox, addSelectbox = form.addIntbox, form.addSelectbox
    local addInputbox, addCheckbox = form.addInputbox, form.addCheckbox
    local addAudioFilebox, setButton = form.addAudioFilebox, form.setButton
    
	addRow(1)
	addLabel({label="---    RC-Thoughts Jeti Tools     ---", font=FONT_BIG})
    
    addRow(1)
    addLabel({label=trans18.labelSensor,font=FONT_BOLD})
    
    addRow(2)
    addLabel({label=trans18.sensorSel, width=200})
    addSelectbox(list, curIndex, true, sensorChanged)
    
    addRow(1)
    addLabel({label=trans18.labelAlarm,font=FONT_BOLD})
    
    addRow(2)
    addLabel({label=trans18.alarmValue, width=230})
    addIntbox(alarmValue, 0, 100, 0, 0, 1, alarmValueChanged)
    
    form.addRow(2)
    addLabel({label=trans18.voiceFile})
    addAudioFilebox(alarmVoice, alarmVoiceChanged)
	
	addRow(1)
	addLabel({label="Powered by RC-Thoughts.com - v."..fuelVersion.." ", font=FONT_MINI, alignRight=true})
    
    collectgarbage()
end
--------------------------------------------------------------------------------
local function loop()
    -- Read consumption
    sensor = system.getSensorByID(sensorId, 1)
    if(sensor and sensor.valid) then 
        consumption = sensor.value
    end
    -- Read current fuel flow
    sensor = system.getSensorByID(sensorId, 2)
    if(sensor and sensor.valid) then 
        flow = sensor.value
    end
    -- Read remaining percentage
    sensor = system.getSensorByID(sensorId, 3)
    if(sensor and sensor.valid) then 
        fuelRemaining = sensor.value
    end
    -- If we have consumed more than allowed sound alarmValue
    if(not playDone and fuelRemaining <= alarmValue and alarmVoice ~= "..." and sensor and sensor.valid) then
        system.playFile(alarmVoice,AUDIO_QUEUE)
        system.playNumber(fuelRemaining, 0, "%")
        playDone = true   
    end
    -- If we are above consumption alarm-level enable alarm
    if(fuelRemaining > alarmValue) then
        playDone = false
    end
    collectgarbage()
end
--------------------------------------------------------------------------------
local function init()
    local pLoad, registerForm, registerTelemetry = system.pLoad, system.registerForm, system.registerTelemetry
    sensorId = pLoad("sensorId", 0)
    alarmValue = pLoad("alarmValue", 0)
    alarmVoice = pLoad("alarmVoice", "...")
    registerForm(1, MENU_APPS, trans18.appName, initForm)
    registerTelemetry(1,trans18.appName,2,dispFuel)
    collectgarbage()
end
--------------------------------------------------------------------------------
fuelVersion = "1.2"
setLanguage()
collectgarbage()
return {init=init, loop=loop, author="RC-Thoughts", version=fuelVersion, name=trans18.appName}
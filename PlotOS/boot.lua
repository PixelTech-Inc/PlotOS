local raw_loadfile = ...

_G.OSNAME = "PlotOS"
_G.OSVERSION = "0.0.3"
_G.OSRELEASE = "alpha"
_G.OSSTATUS = 0
_G.OS_LOGGING_START_TIME = math.floor(computer.uptime() * 1000) / 1000
_G.OS_LOGGING_MAX_NUM_WIDTH = 0

local component_invoke = component.invoke

local function split(inputstr, sep)
  if sep == nil then
      sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
      table.insert(t, str)
  end
  return t
end

local function splitByChunk(text, chunkSize)
  local s = {}
  for i=1, #text, chunkSize do
      s[#s+1] = text:sub(i,i+chunkSize - 1)
  end
  return s
end

local gpu = component.proxy(component.list("gpu")())
local fs = component.proxy(computer.getBootAddress())
local w, h = gpu.getResolution()
_G.rawFs = fs
local x = 1
local y = 1

local pcps = computer.pullSignal

local logfile = 0
local logsToWrite = ""
local loggingHandle = nil

function _G.kern_info(msg, state)
    if type(state) == "nil" then
        state = "info"
    end
    if type(msg) ~= "string" then
        return
    end
    if #split(msg, "\n") > 1 then
        for k, v in ipairs(split(msg, "\n\r")) do
            kern_info(v, state)
        end
    end
    local lc = gpu.getForeground()
    local c = 0xffffff
    local pre = "[" .. computer.uptime() - OS_LOGGING_START_TIME .. "] "
    local num = math.floor(computer.uptime() * 1000) / 1000 - OS_LOGGING_START_TIME
    local num_width = #tostring(num)
    if num_width > OS_LOGGING_MAX_NUM_WIDTH then
        OS_LOGGING_MAX_NUM_WIDTH = num_width
    end

    if state == "info" then
        pre =
            "[" ..
            string.rep(" ", OS_LOGGING_MAX_NUM_WIDTH - (num_width / 2)) ..
                "" ..
                    num ..
                        "" ..
                            string.rep(" ", OS_LOGGING_MAX_NUM_WIDTH - (num_width / 2) - (num_width / 2)) ..
                                "] " .. "[OK]"
        c = 0x10ff10
    elseif state == "warn" then
        c = 0xff10ff
        pre =
            "[" ..
            string.rep(" ", OS_LOGGING_MAX_NUM_WIDTH - (num_width / 2)) ..
                "" ..
                    num ..
                        "" ..
                            string.rep(" ", OS_LOGGING_MAX_NUM_WIDTH - (num_width / 2) - (num_width / 2)) ..
                                "] " .. "[WARN]"
    elseif state == "error" then
        c = 0xff1010
        pre =
            "[" ..
            string.rep(" ", OS_LOGGING_MAX_NUM_WIDTH - (num_width / 2)) ..
                "" ..
                    num ..
                        "" ..
                            string.rep(" ", OS_LOGGING_MAX_NUM_WIDTH - (num_width / 2) - (num_width / 2)) ..
                                "] " .. "[ERROR]"
    end
    if OSSTATUS < 1 then
        logsToWrite = logsToWrite .. pre .. " " .. msg .. "\n"
        gpu.setForeground(c)

        gpu.set(x, y, pre .. " " .. msg)
        x = 1
        if y > h - 1 then
            gpu.copy(1, 1, w, h, 0, -1)
            gpu.fill(1, h, w, 1, " ")
        else
            y = y + 1
        end
        gpu.setForeground(lc)
    else
        local fs = require("fs")
        if type(loggingHandle) == "nil" then
            logsToWrite = logsToWrite .. pre .. " " .. msg .. "\n"
            return
        end

        loggingHandle:write(pre .. " " .. msg .. "\n")
        logsToWrite = ""
    end
end

gpu.fill(1, 1, w, h, " ")

function _G.kern_panic(reason)

    kern_info("KERNEL PANIC", "error")
    kern_info("A kernel panic occured! Traceback:", "error")
    kern_info("----------------------------------------------------", "error")
    kern_info(debug.traceback(), "error")
    kern_info("----------------------------------------------------", "error")
    kern_info("Panic reason: " .. reason, "error")
    while true do
        pcps()
    end
end

function _G.raw_dofile(file)
  local program, reason = raw_loadfile(file)
    --kernel_info(file.." and is the: "..program)
    kern_info("Loading file " .. file)
    if program then
        local result = table.pack(xpcall(program, debug.traceback))
        if result[1] then
            kern_info("Successfully loaded file " .. file)

            return table.unpack(result, 2, result.n)
        else
            kern_info("Error loading file " .. file, "error")

            error(result[2] .. " is the error")
        end
    else
        kern_info("Error loading file " .. file, "error")

        error(reason)
    end
end

_G.bsod = function(reason, isKern)
    if gpu then
        gpu.setBackground(0x2665ed)
        gpu.setForeground(0xffffff)
        gpu.fill(1, 1, w, h, " ")
        gpu.set(10, 10, "Oops! Something went wrong!")
        gpu.set(10, 11, "reason: ")
        local splitReason = split(reason, "\n")
        local kaka = 1
        for k, v in ipairs(splitReason) do
            gpu.set(10, 12 + k, v)
            kaka = k
        end
        gpu.set(10, 12 + kaka + 1, "Details:")
        local splitTrace = split(debug.traceback(), "\n")
        local ka = 1
        for k, v in ipairs(splitTrace) do
            gpu.set(10, 13 + ka + kaka, v)
            ka = k
        end
    end
    if not isKern then
        while true do
            pcps()
        end
    else
        return reason
    end
end

local BootTypeEnum = {
  None = "none",
  PlotOS = {
    normal = "plotos_norm",
    safe = "plotos_safe"
  }
}

local bootType = BootTypeEnum.None

local function bootSelect()
  local function gpuSetCentered(y,text)
    local x = gpu.getResolution()
    local textWidth = string.len(text)
    local xPos = math.floor((x / 2) - (textWidth / 2))
    gpu.set(xPos, y, text)
  end

  local opts = {}
  local function addOption(name, func)
    table.insert(opts, {name, func})
  end

  local function selection()
    local sel = 1

    while true do
      gpu.setForeground(0xffffff)
      gpu.setBackground(0x000000)
      gpu.fill(1, 1, w, h, " ")
      gpuSetCentered(2, "Select an option:")
      for i,v in ipairs(opts) do
        if i == sel then
          gpu.setBackground(0xeeeeee)
          gpu.setForeground(0x000000)
        else
          gpu.setBackground(0x000000)
          gpu.setForeground(0xffffff)
        end

        gpuSetCentered(i+2, v[1])
      end
      
      local ev,_,_,key = computer.pullSignal(0.5)
      if ev == "key_down" then
        if key == 200 then
          sel = sel - 1
          if sel < 1 then
            sel = #opts
          end
        elseif key == 208 then
          sel = sel + 1
          if sel > #opts then
            sel = 1
          end
        elseif key == 28 then
          gpu.setForeground(0xffffff)
          gpu.setBackground(0x000000)
          gpu.fill(1, 1, w, h, " ")
          return opts[sel][2]()
        end
      end
    end
    gpu.setForeground(0xffffff)
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, w, h, " ")
  end
  
  addOption("PlotOS", function()
    bootType = BootTypeEnum.PlotOS.normal
  end)

  addOption("PlotOS with safemode", function()
    bootType = BootTypeEnum.PlotOS.safe
  end)

  selection()
end

local doBootSelection = false
local try = 0
gpu.set(1,h, "Press delete to enter boot selection")
while true do
  if try > 4 then break end
  local ev,_,_,key = computer.pullSignal(0.5)
  if ev == "key_down" then
    if key == 211 then
      doBootSelection = true
      break
    end
  elseif ev == nil then
    try = try + 1
  end
end
gpu.fill(1, 1, w, h, " ")

if doBootSelection then
  bootSelect()
end


--[[BOOT]]--
local function boot(type)
  kern_info("Loading package managment...")
  local package = raw_dofile("/lib/package.lua")
  
  _G.package = package
  package.loaded = {}
  package.loaded.component = component
  package.loaded.computer = computer
  package.loaded.filesystem = fs
  package.loaded.package = package
  
   kern_info("Mounting system drive")
   local fs = package.require("fs")
   fs.mount(rawFs, "/")
  
   kern_info("Reading boot config file")
   local serialization = package.require("serialization")
   local ini = serialization.ini
   local data = ""
   local bootConfHandle = fs.open("/PlotOS/$BootInfo.ini", "r")
   if bootConfHandle then
       data = bootConfHandle:read(math.huge)
       bootConfHandle:close()
   end
   local bootConf = ini.decode(data)
  
   local safemode = false
  
   if type ~= BootTypeEnum.None then
    if type == BootTypeEnum.PlotOS.safe then
      safemode = true
    elseif type == BootTypeEnum.PlotOS.normal then
      safemode = false
    end
  else
    if bootConf.safemode.enable == "true" then
      safemode = true
    elseif bootConf.safemode.enable == "false" then
      safemode = false
    else
      safemode = false
    end
  end

   if safemode == "true" then
    kern_info("Safemode is enabled!", "warn")
    safemode = true
  end
  
   kern_info("Loading drivers...")
  
   local driver = package.require("driver")
  
   for ka,va in fs.list("/driver/") do
       for k,v in fs.list("/driver/"..ka) do
           kern_info("Giving direct component proxy access to driver "..ka..k)
           --computer.pullSignal(0.5)
           local d = driver.getDriver(ka..k)
           d.cp = {
               proxy = component.proxy,
               list = component.list,
               get = component.get,
               invoke = component.invoke,
               methods = component.methods,
  
           }
       end
  
   end
  
  
  kern_info("Loading other files...")
  
  
  
  local function rom_invoke(method, ...)
    return component_invoke(computer.getBootAddress(), method, ...)
  end
  
  local scripts = {}
   if not safemode then
       for _, file in ipairs(rom_invoke("list", "PlotOS/system32/boot/")) do
           local path = "PlotOS/system32/boot/" .. file
           if not rom_invoke("isDirectory", path) then
               kern_info("Indexed boot script at "..path)
               table.insert(scripts, path)
           end
       end
   else
       kern_info("Safemode is enabled, loading only critical bootscripts.")
       scripts = {"/PlotOS/system32/boot/00_base.lua","/PlotOS/system32/boot/05_OS.lua","/PlotOS/system32/boot/80_io.lua","/PlotOS/system32/safemode_component.lua","/PlotOS/system32/boot/01_overrides.lua","/PlotOS/system32/safemode_warn.lua","/PlotOS/system32/zzzz_safemode_shell.lua"}
   end
  table.sort(scripts)
  for i = 1, #scripts do
    kern_info("Running boot script "..scripts[i])
    raw_dofile(scripts[i])
  end
    kern_info("Giving special permissions to core modules.")


  
  kern_info("Starting shell...")



   _G.OSSTATUS = 1
   loggingHandle = fs.open("/logs.log", "w")
   local con = splitByChunk(logsToWrite,1024)
   for k,v in ipairs(con) do
       loggingHandle:write(v)
   end
  
  --os.sleep(2)
  require("screen").clear()
  
  
  
  local e,process = xpcall(require, function(e) bsod(e,true) end, "process")
  if not e then
    while true do pcps() end
  end
  
  local fs = require("fs")
  local logger = require("log4po")
  
   if not safemode then
       dofile("/PlotOS/cursor.lua")
       local s1,e1 = pcall(function()
           dofile("/PlotOS/systemAutorun.lua")
       end)
  
       if not s1 then
           logger.error("Error running system autorun: "..e1)
       end
   else
       kern_info("Safemode is enabled, skipping system autorun.","warn")
   end
  
   if not safemode then
       local s2,e2 = pcall(function()
           dofile("/autorun.lua")
       end)
  
       if not s2 then
           logger.error("Error running autorun: "..e2)
       end
   else
       kern_info("Safemode is enabled, skipping autorun.","warn")
   end
  
  process.autoTick()
end

boot(bootType)

computer.beep(1000)
kern_panic("System halted!")
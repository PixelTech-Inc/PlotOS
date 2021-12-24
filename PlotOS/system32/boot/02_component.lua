local cp = component.proxy
local ci = component.invoke

local security = require("security")
local process = require("process")
component.proxy = function(addr)
  if process.isProcess() then
    local proc = process.findByThread(coroutine.running())
    if proc.security.hasPermission("component.access.*") or proc.security.hasPermission("component.access."..cp(addr).type) then
      return cp(addr)
    else
      kern_info("Permission denied to access component by proxy for "..proc.pid.." ("..proc.name..")","warn")
      return nil, "EPERM", "Permission denied for accessing component"
    end
  else
    return cp(addr)
  end
end





setmetatable(component, {
  __index = function(_,k)
    return component.proxy(component.list(k)())
  end
})
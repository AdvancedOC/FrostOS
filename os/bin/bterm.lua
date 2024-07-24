-- this'll be a terminal at some point... i think

local syscalls = require("syscalls")

local screens = syscalls.graphics_getScreens()

syscalls.graphics_bind(screens[1]) -- bind default gpu to first screen

local w,h = syscalls.graphics_getResolution()
syscalls.graphics_setBackground(0x000000)
syscalls.graphics_setForeground(0xFFFFFF)
syscalls.graphics_fill(1,1,w,h,"e")
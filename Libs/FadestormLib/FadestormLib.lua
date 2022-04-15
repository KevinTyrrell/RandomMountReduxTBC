--[[
--    Copyright (C) 2021  Fadestorm - Earthfury-US
--
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]--

-- Libstub library library initialization
local MAJOR, MINOR = "FadestormLib-1", 0
local FadestormLib = LibStub:NewLibrary(MAJOR, MINOR)
if not FadestormLib then return end

-- Imported standard library functions.
local upper = string.upper


local function main()
    
    --[[
    -- =======================================
    -- LIBRARY CORE
    -- =======================================
    ]]--
    
    --[[ MODULES ]]--
    local Type, Stream
    --[[ Functions ]]--
    local throw
    
    --[[
    -- Registers an FSL event to be handled.
    --
    -- @param string name Name of the event (without 'FSL_', case insensitive)
    -- @param function definition Implementation of the event.
    -- @return function Definition parameter.
    ]]--
    local FSL_events = setmetatable({}, {
            __call = function(self, name, definition)
                self["FSL_" .. upper(name)] = definition
                return definition
            end
    })
    
    --[[
    -- Indicates the presence of a FSL WA to all other FSL clients.
    --
    -- If a higher-version FSL is discovered, this version suspends.
    -- Upon loading for the first time, this FSL is broadcasted.
    --
    -- @param string ver Version of the discovered FSL.
    -- @param function me Function pointer intended to identify each FSL uniquely.
    ]]--
    FSL_events("suspend", function(ver, me)
            -- Ignore events sent from myself.
            if me == FSL_events then return end
            -- Ignore events if we are already suspended.
            if aura_env.handle == nil then return end
            local x, y, z = Version.parse(ver)
            if x == nil then return end
            if Version.check(x, y, z) then
                if not Version.match(x, y, z) or not aura_env.loaded then
                    -- Broadcast to other FSL's that our version exists.
                    return
                    --return WeakAuras.ScanEvents("FSL_SUSPEND", tostring(Version), FSL_events)
                end
            end
            
            aura_env.handle = nil -- Suspend this FSL.
    end)
    
    --[[
    -- Throws an error to the chat and error frame.
    --
    -- @param [string] aura Name of the aura throwing the error.
    -- @param [string] throwable Error message to be thrown.
    ]]--
    local function throw(aura, throwable)
        throwable = "WeakAura [ " .. WrapTextInColorCode(aura, "ffce2525") .. " ] raised error: " .. WrapTextInColorCode(throwable, "ffeadf48") .. "."
        print(throwable)
        error(throwable)
    end
    Type = { FUNCTION = function(a) return a end } -- Forward declaration & workaround.
    FSL_events("throw", function(callback) Type.FUNCTION(callback)(throw) end)
    
    Type = (function()
            local function constructor(name)
                return setmetatable({}, {
                        __tostring = function() return name end,
                        __call = function(_, var)
                            local t = type(var)
                            if t ~= name then
                                throw(aura_env.id, "Type mismatch, expected: " .. name .. ", found: " .. t)
                            end
                            return var
                        end
                })
            end
            
            return {
                NIL = constructor("nil"),
                STRING = constructor("string"),
                BOOLEAN = constructor("boolean"),
                NUMBER = constructor("number"),
                FUNCTION = constructor("function"),
                USERDATA = constructor("userdata"),
                THREAD = constructor("thread"),
                TABLE = constructor("table")
            }
    end)()
    FSL_events("type", function(callback) Type.FUNCTION(callback)(Type) end)
    
    --[[
    -- =======================================
    -- STREAMING API
    -- =======================================
    ]]--
    local Stream = { 
        --[[
        -- Filters an iterable, iterating over a designated subset of elements.
        --
        -- @param iterable iterable Table or iterator in which to iterate.
        -- @param function callback Callback filter function.
        -- @param function Iterator function.
        ]]--
        filter = function(iterable, callback)
            -- Tables must use 'next' while iterators can use themselves.
            local iterator = type(iterable) == "table" and next or iterable
            local key = nil -- Iterator key parameter cannot be trusted due to key re-mappings.
            return function(iter)
                local value 
                repeat key, value = iterator(iterable, key)
                until key == nil or callback(key, value) == true
                return key, value
            end, iterable, nil
        end,
        --[[
        -- Maps an iterable, translating elements into different elements.
        --
        -- @param iterable iterable Table or iterator in which to iterate.
        -- @param function callback Callback mapping function.
        -- @return function Iterator function.
        ]]--
        map = function(iterable, callback)
            -- Tables must use 'next' while iterators can use themselves.
            local iterator = type(iterable) == "table" and next or iterable
            local key = nil -- Iterator key parameter cannot be trusted due to key re-mappings.
            return function(iter)
                local value
                key, value = iterator(iterable, key)
                if key ~= nil then
                    return callback(key, value)
                end
            end, iterable, nil
        end,
        --[[
        -- Merges two streams in parallel into one.
        --
        -- Streams of non-matching sizes will yield nil data for one of the key/value pairs.
        -- @param iterable iter1 Table or iterator in which to iterate.
        -- @param iterable iter2 Table of iterator in which to iterate.
        -- @param function callback Callback function (k1,v1,k2,v2) --> (key,value).
        -- @return function Iterator function.
        ]]--
        merge = function(iter1, iter2, callback)
            local i1 = type(iter1) == "table" and next or iter1
            local i2 = type(iter2) == "table" and next or iter2
            local k1, k2 -- Iterator key parameter cannot be trusted due to key re-mappings.
            return function(iter)
                local v1, v2
                k1, v1 = i1(iter1, k1)
                k2, v2 = i2(iter2, k2) 
                if k1 ~= nil or k2 ~= nil then
                    return callback(k1, v1, k2, v2) 
                end
            end, nil, nil
        end,
        --[[
        -- Peeks an iterable, viewing each element as it is iterated.
        --
        -- @param iterable iterable Table or iterator in which to iterate.
        -- @param function callback Callback peeking function.
        -- @return function Iterator function.
        ]]--
        peek = function(iterable, callback)
            -- Tables must use 'next' while iterators can use themselves.
            local iterator = type(iterable) == "table" and next or iterable
            local key = nil -- Iterator key parameter cannot be trusted due to key re-mappings.
            return function(iter)
                local value
                key, value = iterator(iterable, key)
                if key ~= nil then
                    callback(key, value)
                    return key, value
                end
            end, iterable, nil
        end,
        --[[
        -- Collects an iterator into a table.
        --
        -- @param iterable Table or iterator in which to iterate.
        -- @return table Table of elements provided by the iterator.
        ]]--
        collect = function(iterable)
            -- Tables must use 'next' while iterators can use themselves.
            local iterator = type(iterable) == "table" and next or iterable
            local t = { }
            for k, v in iterator do
                t[k] = v end
            return t
        end
    }
    FSL_events("stream", function(callback) Type.FUNCTION(callback)(Stream) end)
    
    -- General event handler.
    aura_env.handle = function(event, ...)
        if event ~= nil then
            local handler = FSL_events[event]
            if handler ~= nil then
                return handler(...)
            else throw(aura_env.id, "Event \"" .. tostring(event) .. "\" was unrecognized") end
        else throw(aura_env.id, "Event required parameter was nil") end
    end
    
    -- Contact other FSL's in hopes we are told whether or not we must suspend.
    WeakAuras.ScanEvents("FSL_SUSPEND", tostring(Version), FSL_events)
    aura_env.loaded = true -- Used as a sentinel for FSL_suspend.
end


main()


-- Minimal Penlight implementation for Kahlua (Project Zomboid)
-- Only provides: pl.class and pl.tablex.deepcopy
-- No dependency on package.searchers or package.loaders

-- =============================================================================
-- pl.compat - Compatibility layer
-- =============================================================================
local compat = {}

compat.lua51 = _VERSION == 'Lua 5.1'
compat.jit = (tostring(assert):match('builtin') ~= nil)

if compat.jit then
    compat.jit52 = not loadstring("local goto = 1")
end

-- Kahlua compatibility: package.config may not be available
-- Project Zomboid runs on Windows, so hardcode Windows path separator
compat.dir_separator = '\\'
compat.is_windows = true

-- getfenv/setfenv for Lua 5.2+
if compat.lua51 then
    compat.setfenv, compat.getfenv = setfenv, getfenv
else
    function compat.setfenv(f, t)
        f = (type(f) == 'function' and f or debug.getinfo(f + 1, 'f').func)
        local name
        local up = 0
        repeat
            up = up + 1
            name = debug.getupvalue(f, up)
        until name == '_ENV' or name == nil
        if name then
            debug.upvaluejoin(f, up, function() return name end, 1)
            debug.setupvalue(f, up, t)
        end
        if f ~= 0 then return f end
    end

    function compat.getfenv(f)
        local f = f or 0
        f = (type(f) == 'function' and f or debug.getinfo(f + 1, 'f').func)
        local name, val
        local up = 0
        repeat
            up = up + 1
            name, val = debug.getupvalue(f, up)
        until name == '_ENV' or name == nil
        return val
    end
end

if not table.unpack then
    table.unpack = unpack
end

if not table.pack then
    function table.pack (...)
        return {n=select('#',...); ...}
    end
end

-- =============================================================================
-- pl.utils - Minimal utilities needed
-- =============================================================================
local utils = { _VERSION = "1.14.0" }

-- Copy compat functions to utils
for k, v in pairs(compat) do 
    utils[k] = v  
end

utils.pack = table.pack

function utils.unpack(t, i, j)
    local _unpack = table.unpack
    return _unpack(t, i or 1, j or t.n or #t)
end

function utils.assert_arg(n, val, tp, verify, msg, lev)
    if type(val) ~= tp then
        error(("argument %d expected a '%s', got a '%s'"):format(n, tp, type(val)), lev or 2)
    end
    if verify and not verify(val) then
        error(("argument %d: '%s' %s"):format(n, val, msg), lev or 2)
    end
    return val
end

function utils.function_arg(idx, f, msg)
    utils.assert_arg(1, idx, 'number')
    local tp = type(f)
    if tp == 'function' then return f end
    -- For Kahlua, we'll just require functions - no operator strings
    if not msg then msg = " must be callable" end
    if idx > 0 then
        error("argument "..idx..": "..msg, 2)
    else
        error(msg, 2)
    end
end

-- =============================================================================
-- pl.types - Type checking functions
-- =============================================================================
local types = {}

types.is_type = utils.is_type or function(obj, tp)
    if type(tp) == 'string' then return type(obj) == tp end
    local mt = getmetatable(obj)
    return tp == mt
end

local function check_meta(val)
    if type(val) == 'table' then return true end
    return getmetatable(val)
end

function types.is_indexable(val)
    local mt = check_meta(val)
    if mt == true then return true end
    return mt and mt.__len and mt.__index and true
end

function types.is_iterable(val)
    local mt = check_meta(val)
    if mt == true then return true end
    return mt and mt.__pairs and true
end

function types.is_writeable(val)
    local mt = check_meta(val)
    if mt == true then return true end
    return mt and mt.__newindex and true
end

-- =============================================================================
-- pl.class - Class implementation
-- =============================================================================
local error, getmetatable, io, pairs, rawget, rawset, setmetatable, tostring, type =
    _G.error, _G.getmetatable, _G.io, _G.pairs, _G.rawget, _G.rawset, _G.setmetatable, _G.tostring, _G.type

-- Lazy load compat for getfenv (only needed for named class syntax)
local _compat_getfenv = nil
local function get_compat_getfenv()
    if not _compat_getfenv then
        _compat_getfenv = compat.getfenv
    end
    return _compat_getfenv
end

local function call_ctor(c, obj, ...)
    local init = rawget(c, '_init')
    local parent_with_init = rawget(c, '_parent_with_init')

    if parent_with_init then
        if not init then
            init = rawget(parent_with_init, '_init')
            parent_with_init = rawget(parent_with_init, '_parent_with_init')
        end
        if parent_with_init then
            rawset(obj, 'super', function(obj, ...)
                call_ctor(parent_with_init, obj, ...)
            end)
        end
    else
        rawset(obj, 'super', nil)
    end

    local res = init(obj, ...)
    if parent_with_init then
        rawset(obj, 'super', nil)
    end

    return res
end

local function is_a(self, klass)
    if klass == nil then
        return getmetatable(self)
    end
    local m = getmetatable(self)
    if not m then return false end
    while m do
        if m == klass then return true end
        m = rawget(m, '_base')
    end
    return false
end

local function class_of(klass, obj)
    if type(klass) ~= 'table' or not rawget(klass, 'is_a') then return false end
    return klass.is_a(obj, klass)
end

local function cast(klass, obj)
    return setmetatable(obj, klass)
end

local function _class_tostring(obj)
    local mt = obj._class
    local name = rawget(mt, '_name')
    setmetatable(obj, nil)
    local str = tostring(obj)
    setmetatable(obj, mt)
    if name then str = name .. str:gsub('table', '') end
    return str
end

local function tupdate(td, ts, dont_override)
    for k, v in pairs(ts) do
        if not dont_override or td[k] == nil then
            td[k] = v
        end
    end
end

local function _class(base, c_arg, c)
    local mt = {}
    local plain = type(base) == 'table' and not getmetatable(base)
    if plain then
        c = base
        base = c._base
    else
        c = c or {}
    end

    if type(base) == 'table' then
        tupdate(c, base, plain)
        c._base = base
        if rawget(c, '_handler') then mt.__index = c._handler end
    elseif base ~= nil then
        error("must derive from a table type", 3)
    end

    c.__index = c
    setmetatable(c, mt)
    if not plain then
        if base and rawget(base, '_init') then c._parent_with_init = base end
        c._init = nil
    end

    if base and rawget(base, '_class_init') then
        base._class_init(c, c_arg)
    end

    mt.__call = function(class_tbl, ...)
        local obj
        if rawget(c, '_create') then obj = c._create(...) end
        if not obj then obj = {} end
        setmetatable(obj, c)

        if rawget(c, '_init') or rawget(c, '_parent_with_init') then
            local res = call_ctor(c, obj, ...)
            if res then
                obj = res
                setmetatable(obj, c)
            end
        end

        if base and rawget(base, '_post_init') then
            base._post_init(obj)
        end

        return obj
    end

    c.catch = function(self, handler)
        if type(self) == "function" then
            handler = self
        end
        c._handler = handler
        mt.__index = handler
    end
    c.is_a = is_a
    c.class_of = class_of
    c.cast = cast
    c._class = c

    if not rawget(c, '__tostring') then
        c.__tostring = _class_tostring
    end

    return c
end

local class
class = setmetatable({}, {
    __call = function(fun, ...)
        return _class(...)
    end,
    __index = function(tbl, key)
        if key == 'class' then
            io.stderr:write('require("pl.class").class is deprecated. Use require("pl.class")\n')
            return class
        end
        -- Lazy load getfenv only when needed for named class syntax
        local getfenv_fn = get_compat_getfenv()
        if not getfenv_fn then
            error("getfenv not available - cannot use named class syntax", 2)
        end
        local env = getfenv_fn(2)
        return function(...)
            local c = _class(...)
            c._name = key
            rawset(env, key, c)
            return c
        end
    end
})

class.properties = class()

function class.properties._class_init(klass)
    klass.__index = function(t, key)
        local v = klass[key]
        if v then return v end
        v = rawget(klass, 'get_'..key)
        if v then
            return v(t)
        end
        return rawget(t, '_'..key)
    end
    klass.__newindex = function(t, key, value)
        local p = 'set_'..key
        local setter = klass[p]
        if setter then
            setter(t, value)
        else
            rawset(t, key, value)
        end
    end
end

-- =============================================================================
-- pl.tablex - Minimal table operations (only deepcopy)
-- =============================================================================
local tablex = {}

local getmetatable = getmetatable
local setmetatable = setmetatable
local pairs = pairs
local type = type

local function complain(idx, msg)
    error(('argument %d is not %s'):format(idx, msg), 3)
end

local function assert_arg_iterable(idx, val)
    if not types.is_iterable(val) then
        complain(idx, "iterable")
    end
end

local function cycle_aware_copy(t, cache)
    if type(t) ~= 'table' then return t end
    if cache[t] then return cache[t] end
    assert_arg_iterable(1, t)
    local res = {}
    cache[t] = res
    local mt = getmetatable(t)
    for k, v in pairs(t) do
        k = cycle_aware_copy(k, cache)
        v = cycle_aware_copy(v, cache)
        res[k] = v
    end
    setmetatable(res, mt)
    return res
end

function tablex.deepcopy(t)
    return cycle_aware_copy(t, {})
end

-- =============================================================================
-- Return module table compatible with goap.00_pl usage
-- =============================================================================
return {
    class = class,
    tablex = tablex
}

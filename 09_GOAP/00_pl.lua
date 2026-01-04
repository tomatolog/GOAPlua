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

function utils.assert_string(n, val)
    return utils.assert_arg(n, val, 'string', nil, nil, 3)
end

function utils.writefile(filename, str, is_bin)
    local mode = is_bin and 'b' or ''
    utils.assert_string(1, filename)
    utils.assert_string(2, str)
    local f, err = io.open(filename, 'w'..mode)
    if not f then return nil, err end
    local ok, write_err = f:write(str)
    f:close()
    if not ok then
        return nil, filename..": "..write_err
    end
    return true
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
-- pl.lexer - Minimal lexer support for pretty module
-- =============================================================================
local lexer = {}

local lua_keyword

function lexer.get_keywords()
    if not lua_keyword then
        lua_keyword = {
            ["and"] = true, ["break"] = true,  ["do"] = true,
            ["else"] = true, ["elseif"] = true, ["end"] = true,
            ["false"] = true, ["for"] = true, ["function"] = true,
            ["if"] = true, ["in"] = true,  ["local"] = true, ["nil"] = true,
            ["not"] = true, ["or"] = true, ["repeat"] = true,
            ["return"] = true, ["then"] = true, ["true"] = true,
            ["until"] = true,  ["while"] = true
        }
    end
    return lua_keyword
end

-- =============================================================================
-- pl.pretty - Pretty printing module
-- =============================================================================
local pretty = {}

-- Helper function for quote_string (Kahlua-compatible version without capture references)
local function has_lquote(s)
    local max_equals = 0
    local i = 1
    local len = #s
    
    while i <= len do
        local char = s:sub(i, i)
        if char == '[' or char == ']' then
            -- Check for long bracket pattern: [=...=] or ]=...=[
            local j = i + 1
            local eq_count = 0
            -- Count equals signs
            while j <= len and s:sub(j, j) == '=' do
                eq_count = eq_count + 1
                j = j + 1
            end
            -- Check if next char matches the bracket
            if j <= len and s:sub(j, j) == char then
                if eq_count > max_equals then
                    max_equals = eq_count
                end
            end
        end
        i = i + 1
    end
    
    return max_equals > 0 and max_equals or nil
end

-- Quote string function (simplified from pl.stringx)
local function quote_string(s)
    utils.assert_string(1, s)
    -- Find out if there are any embedded long-quote sequences that may cause issues.
    -- This is important when strings are embedded within strings, like when serializing.
    -- Append a closing bracket to catch unfinished long-quote sequences at the end of the string.
    local equal_signs = has_lquote(s .. "]")

    -- Note that strings containing "\r" can't be quoted using long brackets
    -- as Lua lexer converts all newlines to "\n" within long strings.
    if (s:find("\n") or equal_signs) and not s:find("\r") then
        -- If there is an embedded sequence that matches a long quote, then
        -- find the one with the maximum number of = signs and add one to that number.
        equal_signs = ("="):rep((equal_signs or -1) + 1)
        -- Long strings strip out leading newline. We want to retain that, when quoting.
        if s:find("^\n") then s = "\n" .. s end
        local lbracket, rbracket =
            "[" .. equal_signs .. "[",
            "]" .. equal_signs .. "]"
        s = lbracket .. s .. rbracket
    else
        -- Escape funny stuff. Lua 5.1 does not handle "\r" correctly.
        s = ("%q"):format(s):gsub("\r", "\\r")
    end
    return s
end

local function quote_if_necessary(v)
    if not v then return ''
    else
        if v:find(' ') then v = quote_string(v) end
    end
    return v
end

local keywords

local function is_identifier(s)
    return type(s) == 'string' and s:find('^[%a_][%w_]*$') and not keywords[s]
end

local function quote(s)
    if type(s) == 'table' then
        return pretty.write(s, '')
    else
        return quote_string(s)
    end
end

local function index(numkey, key)
    if not numkey then
        key = quote(key)
        key = key:find("^%[") and (" " .. key .. " ") or key
    end
    return '['..key..']'
end

--- Create a string representation of a Lua table.
-- This function never fails, but may complain by returning an
-- extra value. Normally puts out one item per line, using
-- the provided indent; set the second parameter to an empty string
-- if you want output on one line.
-- @tab tbl Table to serialize to a string.
-- @string[opt] space The indent to use.
-- Defaults to two spaces; pass an empty string for no indentation.
-- @bool[opt] not_clever Pass `true` for plain output, e.g `{['key']=1}`.
-- Defaults to `false`.
-- @return a string
-- @return an optional error message
function pretty.write(tbl, space, not_clever)
    if type(tbl) ~= 'table' then
        local res = tostring(tbl)
        if type(tbl) == 'string' then return quote(tbl) end
        return res, 'not a table'
    end
    if not keywords then
        keywords = lexer.get_keywords()
    end
    local set = ' = '
    if space == '' then set = '=' end
    space = space or '  '
    local lines = {}
    local line = ''
    local tables = {}

    local append = table.insert
    local concat = table.concat

    local function put(s)
        if #s > 0 then
            line = line..s
        end
    end

    local function putln(s)
        if #line > 0 then
            line = line..s
            append(lines, line)
            line = ''
        else
            append(lines, s)
        end
    end

    local function eat_last_comma()
        local n = #lines
        local lastch = lines[n]:sub(-1, -1)
        if lastch == ',' then
            lines[n] = lines[n]:sub(1, -2)
        end
    end

    local writeit
    writeit = function(t, oldindent, indent)
        local tp = type(t)
        if tp ~= 'string' and tp ~= 'table' then
            putln(quote_if_necessary(tostring(t))..',')
        elseif tp == 'string' then
            putln(quote_string(t) ..",")
        elseif tp == 'table' then
            if tables[t] then
                putln('<cycle>,')
                return
            end
            tables[t] = true
            local newindent = indent..space
            putln('{')
            local used = {}
            if not not_clever then
                for i, val in ipairs(t) do
                    put(indent)
                    writeit(val, indent, newindent)
                    used[i] = true
                end
            end
            local ordered_keys = {}
            for k, v in pairs(t) do
               if type(k) ~= 'number' then
                  append(ordered_keys, k)
               end
            end
            table.sort(ordered_keys, function(a, b)
                if type(a) == type(b) then
                    return tostring(a) < tostring(b)
                else
                    return type(a) < type(b)
                end
            end)
            local function write_entry(key, val)
                local tkey = type(key)
                local numkey = tkey == 'number'
                if not_clever then
                    key = tostring(key)
                    put(indent..index(numkey, key)..set)
                    writeit(val, indent, newindent)
                else
                    if not numkey or not used[key] then -- non-array indices
                        if tkey ~= 'string' then
                            key = tostring(key)
                        end
                        if numkey or not is_identifier(key) then
                            key = index(numkey, key)
                        end
                        put(indent..key..set)
                        writeit(val, indent, newindent)
                    end
                end
            end
            for i = 1, #ordered_keys do
                local key = ordered_keys[i]
                local val = t[key]
                write_entry(key, val)
            end
            for key, val in pairs(t) do
               if type(key) == 'number' then
                  write_entry(key, val)
               end
            end
            tables[t] = nil
            eat_last_comma()
            putln(oldindent..'},')
        else
            putln(tostring(t)..',')
        end
    end
    writeit(tbl, '', space)
    eat_last_comma()
    return concat(lines, #space > 0 and '\n' or '')
end

--- Dump a Lua table out to a file or stdout.
-- @tab t The table to write to a file or stdout.
-- @string[opt] filename File name to write too. Defaults to writing
-- to stdout.
function pretty.dump(t, filename)
    if not filename then
        print(pretty.write(t))
        return true
    else
        return utils.writefile(filename, pretty.write(t))
    end
end

--- Dump a series of arguments to stdout for debug purposes.
-- Any `nil` entries will be printed as `"<nil>"` to make them explicit.
-- @param ... the parameters to dump to stdout.
function pretty.debug(...)
    local n = select("#", ...)
    local t = { ... }
    for i = 1, n do
        local value = t[i]
        if value == nil then
            value = "<nil>"
        end
        t[i] = nil
        t["arg " .. i] = value
    end

    print(pretty.write(t))
    return true
end

-- =============================================================================
-- Return module table compatible with goap.00_pl usage
-- =============================================================================
return {
    class = class,
    tablex = tablex,
    pretty = pretty
}

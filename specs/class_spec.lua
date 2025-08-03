local class = require("class")

describe("class.lua", function()
  it("creates a simple class with ctor and methods", function()
    local Foo = class()
    function Foo:ctor(a) self.a = a end
    function Foo:get() return self.a end

    local f = Foo.new(42)
    assert.equals(42, f:get())
  end)

  it("supports inheritance and super ctor chaining", function()
    local A = class()
    function A:ctor(x) self.x = x end
    function A:getx() return self.x end

    local B = class(A)
    function B:ctor(x, y) self.y = y end
    function B:gety() return self.y end

    local b = B.new(7, 9)
    assert.equals(7, b:getx())
    assert.equals(9, b:gety())
  end)

  it("method lookup is inherited lazily", function()
    local A = class()
    function A:foo() return "a" end
    local B = class(A)
    local b = B.new()
    assert.equals("a", b:foo())
    function A:foo() return "a2" end
    assert.equals("a2", b:foo())
  end)

  it("copyTable deep copies nested tables", function()
    local t = { a = 1, b = { c = 2 } }
    local copy = copyTable(t)
    assert.not_same(t, copy)
    assert.not_same(t.b, copy.b)
    t.b.c = 3
    assert.equals(2, copy.b.c)
  end)
end)
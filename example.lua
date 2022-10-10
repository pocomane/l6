
local last_print = os.clock()
print=function(...)
  local function op(...) for k = 1, select('#', ...) do io.write(" ",tostring(select(k, ...))) end end
  op(...)
  local c = os.clock()
  io.write(" [line:",debug.getinfo(2).currentline,", ",tostring(c-last_print)," s]\n")
  last_print = c;
  return nil
end

-- check for crash
print("wrong",sym())
print("wrong",sym(nil))
print("wrong",sym'')
print("wrong",sym'xx')
print("wrong",sym'w')
print("wrong",sym(1))
local x = sym'x'
print("wrong",sym('square',x,x))
print("wrong",sym('square'))
print("wrong",sym('square',nil))
print("wrong",sym('square',true))
print("wrong",sym('add',x))
print("wrong",sym('add',x,nil))
print("wrong",sym('add',x,true))
print("wrong",sym('add',true,x))
print("wrong",sym('add',nil,x))
print("wrong",pcall(function() return x(x) end))
print("wrong",pcall(function() return x(x,x,x,x) end))
print("good",x)
print("good",sym('x'))
print("good",sym('y'))
print("good",sym('z'))
print("good",sym('const',1))
print("good",sym('square', x))
print("good",sym('sqrt', x))
print("good",sym('neg', x))
print("good",sym('sin', x))
print("good",sym('cos', x))
print("good",sym('tan', x))
print("good",sym('asin', x))
print("good",sym('acos', x))
print("good",sym('atan', x))
print("good",sym('exp', x))
print("good",sym('abs', x))
print("good",sym('log', x))
print("good",sym('recip', x))
print("good",sym('add', x, x))
print("good",sym('mul', x, x))
print("good",sym('min', x, x))
print("good",sym('max', x, x))
print("good",sym('sub', x, x))
print("good",sym('div', x, x))
print("good",sym('atan2', x, x))
print("good",sym('pow', x, x))
print("good",sym('nth-root', x, x))
print("good",sym('mod', x, x))
print("good",sym('nanfill', x, x))
print("good",sym('compare', x, x))
print("good",sym('remap', x, x, x, x))
print("good",x + x)
print("good",x + 1)
print("good",1 + x)
print("good",x - x)
print("good",x * x)
print("good",x / x)
print("good",x >> x)
print("good",x << x)
print("good",-x)
print("good",x(x,x,x))
print("good",sym('add',x,x,x))
print("good",sym('add',1,-2))
print("good",sym('add',x,1,-2))
print("good",sym('remap',x,x,x,x))

local function translate(f, x, y, z) return sym('remap', f, sym'x' - x, sym'y' - y, sym'z' - z) end
local function scale(f, x, y, z) return sym('remap', f, sym'x' / x, sym'y' / y, sym'z' / z) end
local function rotate(f, ax, ay, az)
  local x,y,z=sym'x',sym'y',sym'z'
  ax, ay, az = math.pi*ax/180, math.pi*ay/180, math.pi*az/180
  if 0 ~= ax then
    f = sym('remap', f,
      x,
      math.sin(ax)*z +math.cos(ax)*y,
      math.cos(ax)*z -math.sin(ax)*y)
  end
  if 0 ~= ay then
    f = sym('remap', f,
      math.cos(ay)*x -math.sin(ay)*z,
      y,
      math.sin(ay)*x +math.cos(ay)*z)
  end
  if 0 ~= az then
    f = sym('remap', f,
      math.sin(az)*y +math.cos(az)*x,
      math.cos(az)*y -math.sin(az)*x,
      z)
  end
  return f
end
local function union(...) return sym('min', ...) end
local function intersection(...) return sym('max', ...) end
local function difference(a, ...) return -sym('min', -a, ...) end
local function bend(a, b, m) return -sym('log', sym('exp', -m*a) + sym('exp', -m*b))/m end
local function loft(a, b, zmin, zmax)
  local z = sym'z'
  return z - zmax >> zmin - z >> (((z - zmin)*b + (zmax - z)*a) / (zmax - zmin))
end
local function norm_comp(vec_x, vec_y, vec_z)
  local norm = vec_x * vec_x + vec_y * vec_y + vec_z * vec_z
  return vec_x/norm, vec_y/norm, vec_z/norm
end
local function linaux(v, min, max)
  local a, b = (max-min) /2 , (max+min) /2
  return v * a + b 
end
local function drag(s, wx, wy)
  local x, y, z = sym'x', sym'y', sym'z'
  return sym('remap', s, x -linaux(z, -wx/2, wx/2), y -linaux(z, -wy/2, wy/2), z)
end
local function widen(s, wx, wy)
  local x, y, z = sym'x', sym'y', sym'z'
  return sym('remap', s, x/linaux(z, 1, wx), y/linaux(z, 1, wy), z)
end
local function twist(s, a)
  local x, y, z = sym'x', sym'y', sym'z'
  local zt = linaux(z, -a/2 /180 * math.pi, a/2 /180 *math.pi)
  return sym('remap', s,
    sym('sin',zt)*y +sym('cos',zt)*x,
    sym('cos',zt)*y -sym('sin',zt)*x,
    z)
end
local function revolve(f)
  local x, y, z = sym'x', sym'y', sym'z'
  return union(
    sym('remap', f,
      sym('sqrt', x^2 + z^2),
      y, z),
    sym('remap', f,
      -sym('sqrt', x^2 + z^2),
      y, z)
    )
end
local function semispace(nx, ny, nz)
  local norm_x, norm_y, norm_z = norm_comp(nx, ny, nz)
  local result = 0
  if norm_x ~= 0 then result = result + sym'x' * norm_x end
  if norm_y ~= 0 then result = result + sym'y' * norm_y end
  if norm_z ~= 0 then result = result + sym'z' * norm_z end
  return result
  -- return 0
  --      + sym'x' * norm_x
  --      + sym'y' * norm_y
  --      + sym'z' * norm_z
end
local function rectangle()
  local x, y, z = sym'x', sym'y', sym'z'
  return -1-x >> x-1 >> -1-y >> y-1
end
local function extrude2d(a, m, M)
  local x, y, z = sym'x', sym'y', sym'z'
  return a >> m - z >> z - M
end
local function sphere()
  local x, y, z = sym'x', sym'y', sym'z'
  return x^2 + y^2 + z^2 -1
end
local function cylinder()
  local x, y, z = sym'x', sym'y', sym'z'
  return x^2 + y^2 -1 >> z -1 >> -1 -z
end
local function box()
  local x, y, z = sym'x', sym'y', sym'z'
  local dx = sym('abs', x) - 1
  local dy = sym('abs', y) - 1
  local dz = sym('abs', z) - 1
  return (dx >> dy >> dz << 0) + sym('sqrt', (dx >> 0)^2 + (dy >> 0)^2 + (dz >> 0)^2)
end

local x, y, z = sym'x', sym'y', sym'z'
local s = sym("add", x^2, y*y + z^2, - 1) -- trying several syntaxes, x^2+y^2+z^2-1 works too !
--s = s << s(x, y, z+1) -- << = min = union, () = remap = translation (in this case)
s1 = sphere()(x,y,z-0.3)
s2 = sphere()(x,y,z+0.3)
s = box()
s = loft(s,s(x*2, y*2, z),-0.5,0.5)
-- s = extrude2d(rectangle(),-1,1) - 1
-- s = box() - 1

local a_cube = intersection(
  translate(semispace(-1,0,0), -1,0,0),
  translate(semispace(1,0,0),  1,0,0),
  translate(semispace(0,-1,0), 0,-1,0),
  translate(semispace(0,1,0),  0,1,0),
  translate(semispace(0,0,-1), 0,0,-1),
  translate(semispace(0,0,1),  0,0,1)
)

local xxx = intersection(
  translate(semispace(-1,0,0), -1,0,0),
  translate(semispace(1,0,0),  1,0,0),
  translate(semispace(0,-1,0), 0,-1,0),
  translate(semispace(0,1,0),  0,1,0)
)


print(save_stl(revolve(translate(xxx, -1,0,0)), 5, 20))

-- better fstl integration: do not update 
-- until the rendering end
os.execute("mv init.stl example_view.stl")


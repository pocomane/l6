
# libfive + lua = l6

This repository contains a [lua](https://www.lua.org/) binding for
[libfive](https://github.com/libfive/libfive), plus a script to build a static
executable. It also provides [pre-built
binaries](https://github.com/pocomane/l6/releases) for all the supported
architectures (just amd64-linux for the moment, but we hope to add windows and
mac soon).

This is in prototype stage. It has the minimal features needed to evaluate it
as a replacement of [openscad](https://openscad.org/).

# build

If you want to build `l6` by yourself instead, run the script:

```
./build.sh
```

It will take a while since it will build a static version of all the needed
dependencies too.

# How to use

`l6` is a "Programmatic CAD", it means that you describe the geometry in a programming
language. It then provide functions to export it as an `stl`. It is a command line
tool; if for example the code is in a `my_model.lua` file, the command

```
./l6.exe my_model.lua
```

will execute the code. This normally means that a `my_model.stl` file will be generated,
but this may be changed with special functions in the code (details in the following).

To see the result you can use any `stl` viewer or you can import it in a graphical
CAD. We suggest to use [fstl](https://github.com/fstl-app/fstl):

```
fstl my_model_stl
```

To speedup the development, you can use the `fstl` auto reload feature to have the
view updated automatically when you run `l6`. You can also setup a inotify script to
run `l6` automatically when the file changes. In this way you get a worflow very similar
to integrated IDE, like the one of `openscad`.

# l6 basic

`l6` uses the [implict surface](https://en.wikipedia.org/wiki/Implicit_surface)
representation of 3D object. This means that internally every object is
represented by a continuous matemathical function of the three variables `x`,
`y` and `z`; the surface we are describing is the one on wich the function has
a zero value. Values < 0 are the internal of the object while values > 0 are
the outside. Actually it is usefull to think to this function as a "Distance
field", however we leave out this aspect for now.

So to make a sphere, lets make a `example.lua` file and write in it the following
code:

```
local x = sym('x')
local y = sym('y')
local z = sym('z')
local sphere = x^2 + y^2 + z^2 -1
save_stl(sphere, 2, 10)
```

The language used to describe the geometry is `lua`, you can
refer to its manual for the detail, however we will se here the basics.

`local x = ...` is the way to declare a variable. `sym` is one of the `l6`
specific functions that returns basic objects or operations. `'x'` is the
string "x", so we are passing this string to the `sym` function. When `sym`
found such string it returns an object representing the matematical expression
'x'. For what we said this represents also the surface for which 'x = 0', but
here we want to use it just to write more complex expessions.

Actually these first three lines can be written more compactly:

```
local x, y, z = sym'x', sym'y', sym'z'
```
Since `lua` allow to declare multiple variable on a single line, and let you to
omit the `()` when call a function with a single non-numeric "Literal" argument.

Expressions can be combined with classical matematic operation, for example in
the `sphere` variable we are placing the implicit expression of a sphere:
'x^2 + y^2 + z^2 -1'.  We note that these are just shortcut for `sym`
arguments. For example the power of an expression can be introduced both with
`x^2` that with `sym('pow', x, 2)`, the sum with `x+y` or `sym('add',x,y)`, ad
so on.  The `sym` syntax is more verbose but allow you to use other
matemathical operaions, like `sym('abs',x)` or `sym('min',x,y)`, and so on.

The last line, `save_stl`, will generate the `stl` file coresponding to the
expression in the `sphere` variable. The `2` is the range of the generation,
i.e. it will found the surface in a cube between -2 and 2 in any axis. This is
enough to view all the sphere since it has a radius of 1. By default it will
save the result in a file with the same name of the input, i.e. `example.stl`;
to give another name you can add it as last argument: `save_stl(sphere, 2, 10,
'a_sphere.stl')`.

The other argument to `save_stl` is the quality of the output `stl`. Bigger means
more details. To precisely know what it represents, please refers to the
`libfive` documentation.

Practically, at this point, `l6` just adds the two functions `sym` and `save_stl`
to `lua`, plus some magic to automatically call `sym` when an aritmetic operation
is found.

# Translation and substraction

Next very common operation is to move an object. Matematically, to move the sphere
of 1 unit on x you should write something like

```
local sphere = (x-1)^2 + y^2 + z^2 -1
```

`l6` offers a shortcut to perform such transformations after the object was already
created:

```
local sphere = x^2 + y^2 + z^2 -1
local sphere2 = sym('remap', sphere, x-1, y ,z)
```

`sym('remap')` will return a new expression that is like the original one but with
some substitutions, in this case `x -> x-1`, `y -> y` and `z -> z`.

Now that we have two object, a sphere and a traslated sphere, let's se how to
join them to show their union. In the implicit surfaces formalism this is performed
taking the minumum of two expressions:

```
local x, y, z = sym'x', sym'y', sym'z'
local sphere = x^2 + y^2 + z^2 -1
local sphere2 = sym('remap', sphere, x-1, y ,z)
local two_spheres = sym('min', sphere, sphere2)
save_stl(two_sphere, 2, 10)
```

The intersection is instead done with the maximum:

```
local inter_sphere = sym('max', sphere, sphere2)
```

Since all the object are "First class" in `l6`, i.e. you can put it in
variables or pass to functions, etc, you could also define more readable names
for such operations:

```
local function union(a, b) return sym('min', a, b) end
local function inter(a, b) return sym('max', a, b) end
```

`function` is the `lua` keyword that let's you to define new function. In this
exaple we created a function `union` that returns the `min` of its two
arguments, and a `inter` one that returns the `max`. From now on we are able to
write in our code stuff like:

```
local two_spheres = union(sphere, sphere2)
local inter_sphere = inter(sphere, sphere2)
```

What about the substraction? It is just an union with one of the two expression
negated:

```
local function diff(a, b) return sym('min', a, -b) end
local cut_sphere = diff(sphere, sphere2)
```

# Supported operation

`sym` understands the following codes (mainly the `libfive` opcodes):
- witout arguments: x, y, z
- with a single argument: const, square, sqrt, neg, sin, cos, tan, asin, acos, atan, exp,
  abs, log, recip
- with two or more arguments: add, mul, min, max, sub, div, atan2, pow, nth-root,
  mod, nanfill, compare
- with four arguments: remap

Automatically it will be recalled:
- canst is also automatically implied when using a number where an expression is expected
- `-x` is the same as `sym('neg', x)`
- `x+y` is the same as `sym('add', x, y)`
- `x-y` is the same as `sym('sub', x, y)`
- `x*y` is the same as `sym('mul', x, y)`
- `x/y` is the same as `sym('div', x, y)`
- `x^y` is the same as `sym('pow', x, y)`
- `x<<y` is the same as `sym('min', x, y)`
- `x>>y` is the same as `sym('max', x, y)`

# Describe complex models in multiple files

When the project grows, it became useful to divide the code among multiple files.
In `lua` you can execute external files using the `require` function. So, for
example we can place in a `boolean_operation.lua` file the following code:

```
local function union(a, b) return sym('min', a, b) end
local function inter(a, b) return sym('max', a, b) end
local function diff(a, b) return sym('min', a, -b) end
return {
  intersection = inter,
  union = union,
  difference = differ,
}
```

and recall it from `example.lua` with

```
local bo = require 'boolean_operation'
local two_spheres = bo.union(sphere, sphere2)
local inter_sphere = bo.intersection(sphere, sphere2)
local cut_sphere = bo.difference(sphere, sphere2)
```

Since the variables defined with `local` are visible only in declaring scope,
i.e.  the whole `boolean_operation.lua` file for `intersection`, `union`, etc,
we need to use the `return` keyword, as the file was a `function` (it actually
is), to expose the function in the rquiring file. The `{}` constructor
geneare a `lua` table containing a reference to `inter` into the
`intersection` field, a reference to `union` into the `union` field, and so
on. Table field can be access with the `.` operator.

The first time `require` is called with a specific argument, its result is
cached; when called again with the same argument the file is not
actually executed again. So you can call `require` without worring too much
about performance, dependency graph or wierd side effects.


#include <stdlib.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"
#include "libfive.h"

#define LIBFIVE_TREE_METATABLE "libfive.tree.mt"

// TODO : REMOVE !!! debug purpose !
#define DEBUG(F,...) do{printf("%s:%d - " F "\n", __FILE__,__LINE__, __VA_ARGS__);fflush(stdout);}while(0)
static void print_lua_stack(lua_State *L){
  printf("lua stack base -> ");
  for(int i = 1; i <= lua_gettop(L); i += 1) {
      lua_pushvalue(L, i);
      const char *str = lua_tostring(L, -1);
      printf("%c", *luaL_typename(L, i));
      lua_pop(L, 1);
  }
  printf(" <- top\n");
}

static int finalize_tree(lua_State *L){
  libfive_tree * to_finalize = lua_touserdata(L, -1);
  libfive_tree_delete(*to_finalize);
  return 0;
}

#define LUA_RES(N) (N)
#define LUA_ERR LUA_RES(2)
#define LUA_PUSHERR(L, S) (lua_pushnil(L), lua_pushstring(L,S), 1)

static char* default_name = 0;

static libfive_tree * new_uvtree_or_die(lua_State *L, size_t naux){
  libfive_tree * result = lua_newuserdatauv(L, sizeof(libfive_tree), naux);
  if(NULL == result){
    fprintf(stderr, "memory error\n");
    exit(13);
  }
  return result;
}

static int is_uvtree(lua_State *L, size_t index){
  if (LUA_TUSERDATA != lua_type(L, index))
    return 0;
  lua_getmetatable(L, index);
  luaL_getmetatable(L, LIBFIVE_TREE_METATABLE);
  int result = lua_rawequal(L, -1, -2);
  lua_pop(L, 2);
  return result;
}

static int convert_to_uvtree(lua_State *L, size_t index){
  if (is_uvtree(L, index)) return 1;
  if (LUA_TNUMBER != lua_type(L, index)) return 0;
  double c = lua_tonumber(L, index);
  lua_remove(L, index);
  libfive_tree * x = new_uvtree_or_die(L, 0);
  *x = libfive_tree_const(c);
  luaL_setmetatable(L, LIBFIVE_TREE_METATABLE);
  if(index != lua_gettop(L) && index != -1)
    lua_insert(L, index);
  return 1;
}

// --------------------------------------------------------------------------------

static int sym0(lua_State *L, const char* op){
  size_t len = strlen(op);
  libfive_tree s;
  if (1 != len && LUA_PUSHERR(L, "invalid symbol name")) return LUA_ERR;
  switch (op[0]){
    break; default: LUA_PUSHERR(L, "invalid symbol name"); return LUA_ERR;
    break; case 'x': case 'X': s = libfive_tree_x();
    break; case 'y': case 'Y': s = libfive_tree_y();
    break; case 'z': case 'Z': s = libfive_tree_z();
  }
  libfive_tree* ud = new_uvtree_or_die(L, 0);
  luaL_setmetatable(L, LIBFIVE_TREE_METATABLE);
  *ud = s;
  return LUA_RES(1);
}

static int symC(lua_State *L, size_t base){
  if (LUA_TNUMBER != lua_type(L, base) && LUA_PUSHERR(L, "const symbol expects a number"))
    return LUA_ERR;
  double c = lua_tonumber(L, base);
  libfive_tree * x = new_uvtree_or_die(L, 0);
  *x = libfive_tree_const(c);
  luaL_setmetatable(L, LIBFIVE_TREE_METATABLE);
  return LUA_RES(1);
}

static int sym12(lua_State *L, size_t arg, int is_binary, const char* op){
  int opc = libfive_opcode_enum(op);
  if(-1== opc && LUA_PUSHERR(L, "invalid unary operation"))
    return LUA_ERR;
  libfive_tree * a = lua_touserdata(L, arg);
  libfive_tree s;
  if(!is_binary){
    s = libfive_tree_unary(opc, *a);
    if(NULL == s && LUA_PUSHERR(L, "invalid unary operation"))
      return LUA_ERR;
  } else {
    libfive_tree * b = lua_touserdata(L, arg+1);
    s = libfive_tree_binary(opc, *a, *b);
    if(NULL == s && LUA_PUSHERR(L, "invalid binary operation"))
      return LUA_ERR;
  }
  libfive_tree * t = new_uvtree_or_die(L, is_binary ? 2 : 1);
  luaL_setmetatable(L, LIBFIVE_TREE_METATABLE);
  *t = s;

  // Add child nodes as values to the userdata in order to avoid their
  // gc-collection while the parent is still around
  lua_pushvalue(L, arg);
  lua_setiuservalue(L, -2, 1);
  if(is_binary){
    lua_pushvalue(L, arg+1);
    lua_setiuservalue(L, -2, 2);
  }

  return LUA_RES(1);
}

static int remap(lua_State *L, size_t first){
  libfive_tree * f = lua_touserdata(L, first+0);
  libfive_tree * x = lua_touserdata(L, first+1);
  libfive_tree * y = lua_touserdata(L, first+2);
  libfive_tree * z = lua_touserdata(L, first+3);
  libfive_tree fm = libfive_tree_remap(*f, *x, *y, *z);
  if(NULL == fm && LUA_PUSHERR(L, "invalid remap operation"))
    return LUA_ERR;
  libfive_tree * ud = new_uvtree_or_die(L, 0);
  luaL_setmetatable(L, LIBFIVE_TREE_METATABLE);
  *ud = fm;
  return LUA_RES(1);
}

static int symN(lua_State *L, size_t first, size_t last, const char* op){

  size_t argn = last-first+1;

  // special op handling
  switch(argn){
    break; case 0: return sym0(L, op);
    break; case 1: if(!strcmp("const", op)) return symC(L, first);
    break; case 4: if(!strcmp("remap", op)) return remap(L, first);
  }

  int opc = libfive_opcode_enum(op);
  int opa = libfive_opcode_args(opc);
  if((-1== opc || -1== opa) && LUA_PUSHERR(L, "invalid operation"))
    return LUA_ERR;
  if( 2 != opa && argn != opa && LUA_PUSHERR(L, "wrong argument number"))
    return LUA_ERR;
  if( 2 == opa && argn < 2 && LUA_PUSHERR(L, "wrong argument number"))
    return LUA_ERR;
  for (size_t i = first; i <= last; i += 1){
    if(!convert_to_uvtree(L, i) && LUA_PUSHERR(L, "argument must be a symbolic expression")){
      return LUA_ERR;
    }
  }

  switch(argn){
    break; case 1:  return sym12(L, first, 0, op);
    break; case 2:  return sym12(L, first, 1, op);
  }
  for(size_t i = first; i < last; i += 1) {
    int resn = sym12(L, i, 1, op);
    if(1 != resn) return resn;
    lua_remove(L, i+1);
    lua_insert(L, i+1);
  }
  return LUA_RES(1);
}

static int sym(lua_State *L){
  int argn = lua_gettop(L);
  if (0>= argn && LUA_PUSHERR(L, "at least one argument is needed"))
    return LUA_ERR;
  if (LUA_TSTRING != lua_type(L, 1) && LUA_PUSHERR(L, "first argument must be a string"))
    return LUA_ERR;
  const char* op = lua_tostring(L, 1);
  return symN(L, 2, argn, op);
}

static int save_stl(lua_State *L){
  if(!is_uvtree(L, 1) && LUA_PUSHERR(L, "first argument must be symbolic expression"))
    return LUA_ERR;
  if(LUA_TNUMBER != lua_type(L, 2) && LUA_PUSHERR(L, "second argument must be a number"))
    return LUA_ERR;
  if(LUA_TNUMBER != lua_type(L, 3) && LUA_PUSHERR(L, "third argument must be a number"))
    return LUA_ERR;
  char* path;
  if(lua_gettop(L) < 4 || LUA_TNIL == lua_type(L, 4)){
    path = default_name;
  } else {
    if(LUA_TSTRING != lua_type(L, 4) && LUA_PUSHERR(L, "forth argument must be a string"))
      return LUA_ERR;
    path = (char*)lua_tostring(L, 4);
  }
  if( 0 == path){
    LUA_PUSHERR(L, "missing forth argument");
    return LUA_ERR;
  }
  libfive_tree * shape = lua_touserdata(L, 1);
  double a = lua_tonumber(L, 2);
  double b = lua_tonumber(L, 3);
  libfive_region3 r = {0};
  r.X.lower = -a;
  r.X.upper = a;
  r.Y.lower = -a;
  r.Y.upper = a;
  r.Z.lower = -a;
  r.Z.upper = a;
  libfive_tree_save_mesh(*shape, r, b, path);
  return LUA_RES(0);
}

static int symNE(lua_State *L, size_t argn, const char* op){
  if(argn != lua_gettop(L)){
    lua_pushstring(L, "too few arguments");
    lua_error(L);
  }
  int res = symN(L, 1, argn, op);
  if(1 != res) lua_error(L);
  return res;
}

// NODE : these must rise error since only one arg can be returned
static int sym_add(lua_State *L){ return symNE(L, 2, "add"); }
static int sym_sub(lua_State *L){ return symNE(L, 2, "sub"); }
static int sym_div(lua_State *L){ return symNE(L, 2, "div"); }
static int sym_mul(lua_State *L){ return symNE(L, 2, "mul"); }
static int sym_pow(lua_State *L){ return symNE(L, 2, "pow"); }
static int sym_unm(lua_State *L){ lua_pop(L, 1); return symNE(L, 1, "neg"); }
static int sym_max(lua_State *L){ return symNE(L, 2, "max"); }
static int sym_min(lua_State *L){ return symNE(L, 2, "min"); }
static int sym_remap(lua_State *L){ return symNE(L, 4, "remap"); }

// --------------------------------------------------------------------------------

static int put_cfunc_in_table(lua_State *L, const char * key, lua_CFunction value){
  lua_pushstring(L, key);
  lua_pushcfunction(L, value);
  lua_settable(L, -3);
  return 0;
}

static int put_string_in_table(lua_State *L, const char * key, const char * value){
  lua_pushstring(L, key);
  lua_pushstring(L, value);
  lua_settable(L, -3);
  return 0;
}

int luaopen_libfive(lua_State *L){
  
  luaL_newmetatable(L, LIBFIVE_TREE_METATABLE);
  put_string_in_table(L, "__metatable", "private");
  put_cfunc_in_table(L, "__gc", finalize_tree);
  put_cfunc_in_table(L, "__add", sym_add);
  put_cfunc_in_table(L, "__sub", sym_sub);
  put_cfunc_in_table(L, "__div", sym_div);
  put_cfunc_in_table(L, "__mul", sym_mul);
  put_cfunc_in_table(L, "__pow", sym_pow);
  put_cfunc_in_table(L, "__unm", sym_unm);
  put_cfunc_in_table(L, "__shl", sym_min);
  put_cfunc_in_table(L, "__shr", sym_max);
  put_cfunc_in_table(L, "__call", sym_remap);
  lua_pop(L, 1);

  lua_newtable(L); // result table

  put_cfunc_in_table(L, "sym", sym);
  put_cfunc_in_table(L, "save_stl", save_stl);

  return 1; // return the resul ttable
}

int set_default_name(const char* name){
  if (0!= default_name) free(default_name);
  default_name = strdup(name);
  if (0 == default_name) return -1;
  return 0;
}


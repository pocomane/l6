#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

int luaopen_libfive(lua_State *L);
int set_default_name(const char* name);

static int l_report (lua_State *L, int status) {
  if (status != LUA_OK) {
    const char *msg = lua_tostring(L, -1);
    lua_writestringerror("%s\n", msg);
    lua_pop(L, 1);  /* remove message */
  }
  return status;
}

static int msghandler (lua_State *L) {
  const char *msg = lua_tostring(L, 1);
  if (msg == NULL) {  /* is error object not a string? */
    if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
        lua_type(L, -1) == LUA_TSTRING)  /* that produces a string? */
      return 1;  /* that is the message */
    else
      msg = lua_pushfstring(L, "(error object is a %s value)",
                               luaL_typename(L, 1));
  }
  luaL_traceback(L, L, msg, 1);  /* append a standard traceback */
  return 1;  /* return the traceback */
}

static int l_main (lua_State *L) {

  luaL_openlibs(L);
  luaopen_libfive(L);
  lua_setglobal(L, "l6");
  
  // copy all the content of the libfive binding to the toplevel
  lua_getglobal(L, "l6");
  lua_pushnil(L);
  while(0 != lua_next(L, -2)){  // the key will be at index -2, the 'value' at index -1
    if(LUA_TSTRING != lua_type(L, -2)){
      lua_pop(L, 1); // removes the value; keeps the key for next iteration
    } else {
      const char* key = lua_tostring(L, -2);
      const char* valtyp = lua_typename(L, lua_type(L, -1));
      lua_setglobal(L, key); // this pops also an iteme from the stack
    }
  }
  lua_pop(L, 1);

  lua_gc(L, LUA_GCGEN, 0, 0);  /* GC in generational mode */
 
  if (set_default_name("init.stl")){
    lua_writestringerror("can not set default name '%s' - unrecoverable memory allocation error\n", "init.stl");
    lua_pushboolean(L, 0);  /* signal errors */
    return 1;
  }

  lua_pushcfunction(L, &msghandler);  /* handler for error print */
  luaL_loadfile(L, "init.lua");
  if (LUA_TFUNCTION != lua_type(L, -1)) {
    lua_writestringerror("%s\n", lua_tostring(L, -1));
    lua_pushboolean(L, 0);  /* signal errors */
  } else {
    if (LUA_OK != lua_pcall(L, 0, 0, 1)){
      lua_writestringerror("%s\n", lua_tostring(L, -1));
      lua_pushboolean(L, 0);  /* signal errors */
    } else {
      lua_pushboolean(L, 1);  /* signal no errors */
    }
  }
  return 1;
}

int main (int argc, char **argv) {
  int status, result;
  lua_State *L = luaL_newstate();
  if (L == NULL) {
    lua_writestringerror("%s", "cannot create state: not enough memory\n");
    return 13;
  }
  lua_pushcfunction(L, &msghandler);  /* handler for error print */
  lua_pushcfunction(L, &l_main);  /* to call 'l_main' in protected mode */
  status = lua_pcall(L, 0, 1, 1);  /* do the call */
  result = lua_toboolean(L, -1);  /* get result */
  l_report(L, status);
  lua_close(L);
  return (result && status == LUA_OK) ? 0 : 13;
}


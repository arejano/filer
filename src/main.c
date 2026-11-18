/* base-bui-lua: host Lua 5.4 com BUI + SQLite3 + lfs embutidos.
 *
 * Baseado no host do bui-lua, com:
 *   - binding BUI registrado como `require("bui")`;
 *   - lsqlite3 registrado como `require("lsqlite3")` e alias `require("sqlite3")`;
 *   - LuaFileSystem registrado como `require("lfs")`.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later */
#include "BUI_kit.h"
#include "linenoise.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "sqlite3.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define setenv(name, value, overwrite) _putenv_s((name), (value))
#endif

int luaopen_bui(lua_State *L);
int luaopen_lsqlite3(lua_State *L);
int luaopen_lfs(lua_State *L);

static void print_help(void) {
  printf("Usage: base-bui-lua [options] [script [args...]]\n");
  printf("\n");
  printf("Options:\n");
  printf("  -e <expr>       Execute inline Lua code\n");
  printf("  --headless      Force software raster mode (no display needed)\n");
  printf("  --theme <name>  Set initial theme (dark | light)\n");
  printf("  --scale <n>     Set UI scale factor\n");
  printf("  --version       Print version and exit\n");
  printf("  --help          Print this help and exit\n");
  printf("\n");
  printf("Script mode:\n");
  printf("  base-bui-lua app/main.lua     Run the app\n");
  printf("  base-bui-lua -e \"code\"        Run inline code\n");
  printf("\n");
  printf("REPL mode:\n");
  printf("  base-bui-lua                  Interactive REPL prompt\n");
}

static void register_modules(lua_State *L) {
  luaL_requiref(L, "bui", luaopen_bui, 1);
  lua_pop(L, 1);

  luaL_requiref(L, "lsqlite3", luaopen_lsqlite3, 1);
  lua_pop(L, 1);

  luaL_requiref(L, "lfs", luaopen_lfs, 1);
  lua_pop(L, 1);

  lua_getglobal(L, "package");
  if (lua_istable(L, -1)) {
    lua_getfield(L, -1, "loaded");
    if (lua_istable(L, -1)) {
      lua_getfield(L, -1, "lsqlite3");
      lua_setfield(L, -2, "sqlite3");
    }
    lua_pop(L, 1);
  }
  lua_pop(L, 1);
}

static int run_eval(lua_State *L, const char *code) {
  if (luaL_dostring(L, code) != LUA_OK) {
    fprintf(stderr, "base-bui-lua: %s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
    return 1;
  }
  return 0;
}

static int try_exec(lua_State *L, const char *buf, size_t len) {
  int load_status = luaL_loadbuffer(L, buf, len, "=stdin");
  if (load_status == LUA_ERRSYNTAX) {
    const char *msg = lua_tostring(L, -1);
    if (msg) {
      size_t msglen = strlen(msg);
      if (msglen >= 11 && strcmp(msg + msglen - 11, "near '<eof>'") == 0) {
        lua_pop(L, 1);
        return 0;
      }
    }
    fprintf(stderr, "error: %s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
    return 1;
  }
  if (load_status != LUA_OK) {
    fprintf(stderr, "error: %s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
    return 1;
  }
  if (lua_pcall(L, 0, LUA_MULTRET, 0) != LUA_OK) {
    fprintf(stderr, "error: %s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
    return 1;
  }
  int n = lua_gettop(L);
  for (int i = 1; i <= n; i++) {
    if (i > 1) printf("\t");
    switch (lua_type(L, i)) {
      case LUA_TNIL:     printf("nil"); break;
      case LUA_TBOOLEAN: printf("%s", lua_toboolean(L, i) ? "true" : "false"); break;
      case LUA_TNUMBER:  printf("%.14g", lua_tonumber(L, i)); break;
      case LUA_TSTRING:  printf("%s", lua_tostring(L, i)); break;
      default:           printf("%s: %p", lua_typename(L, lua_type(L, i)),
                                lua_topointer(L, i)); break;
    }
  }
  if (n > 0) printf("\n");
  lua_settop(L, 0);
  return 1;
}

static void run_repl(lua_State *L) {
  linenoiseHistorySetMaxLen(100);
  linenoiseHistoryLoad("~/.base-bui-lua-history");

  char *multiline = NULL;
  size_t multiline_len = 0;
  char *line;

  while ((line = linenoise("lua> ")) != NULL) {
    if (strcmp(line, "exit") == 0 || strcmp(line, "quit") == 0) {
      free(line);
      break;
    }
    linenoiseHistoryAdd(line);
    linenoiseHistorySave("~/.base-bui-lua-history");

    size_t line_len = strlen(line);
    char *newbuf = (char *)realloc(multiline, multiline_len + line_len + 2);
    if (!newbuf) {
      free(line);
      break;
    }
    multiline = newbuf;
    if (multiline_len > 0) {
      multiline[multiline_len] = '\n';
      multiline[multiline_len + 1] = '\0';
      multiline_len++;
    } else {
      multiline[0] = '\0';
    }
    memcpy(multiline + multiline_len, line, line_len + 1);
    multiline_len += line_len;

    if (try_exec(L, multiline, multiline_len)) {
      free(multiline);
      multiline = NULL;
      multiline_len = 0;
    }
    free(line);
  }
  free(multiline);
  printf("\n");
}

int main(int argc, char **argv) {
  const char *script = NULL;
  const char *eval_code = NULL;
  const char *theme = NULL;
  int headless = 0;
  float scale = 0;

  int i = 1;
  while (i < argc && argv[i][0] == '-') {
    if (strcmp(argv[i], "--help") == 0) {
      print_help();
      return 0;
    } else if (strcmp(argv[i], "--version") == 0) {
      printf("base-bui-lua (BUI %s, %s, SQLite %s)\n",
             BK_version_string(), LUA_RELEASE, sqlite3_libversion());
      return 0;
    } else if (strcmp(argv[i], "--headless") == 0) {
      headless = 1;
      i++;
    } else if (strcmp(argv[i], "--theme") == 0 && i + 1 < argc) {
      theme = argv[++i];
      i++;
    } else if (strcmp(argv[i], "--scale") == 0 && i + 1 < argc) {
      scale = (float)atof(argv[++i]);
      i++;
    } else if (strcmp(argv[i], "-e") == 0 && i + 1 < argc) {
      eval_code = argv[++i];
      i++;
    } else {
      fprintf(stderr, "base-bui-lua: unknown option '%s'\n", argv[i]);
      fprintf(stderr, "Try 'base-bui-lua --help' for usage.\n");
      return 1;
    }
  }

  if (i < argc && !eval_code) {
    script = argv[i];
    i++;
  }

  if (headless) {
    setenv("BUI_HEADLESS", "1", 1);
  }

  lua_State *L = luaL_newstate();
  if (!L) {
    fprintf(stderr, "base-bui-lua: failed to create Lua state\n");
    return 1;
  }
  luaL_openlibs(L);
  register_modules(L);

  if (theme && !BK_set_theme(theme)) {
    fprintf(stderr, "base-bui-lua: unknown theme '%s', using default\n", theme);
  }
  if (scale > 0) {
    BK_set_scale(scale);
  }

  int status = 0;

  if (eval_code) {
    status = run_eval(L, eval_code);
  } else if (script) {
    lua_createtable(L, argc - i, 0);
    for (int j = i; j < argc; j++) {
      lua_pushstring(L, argv[j]);
      lua_rawseti(L, -2, j - i + 1);
    }
    lua_setglobal(L, "arg");

    if (luaL_dofile(L, script) != LUA_OK) {
      fprintf(stderr, "base-bui-lua: %s\n", lua_tostring(L, -1));
      lua_pop(L, 1);
      status = 1;
    }
  } else {
    printf("base-bui-lua (BUI %s, %s, SQLite %s)\n",
           BK_version_string(), LUA_RELEASE, sqlite3_libversion());
    printf("Type 'exit' to quit\n");
    run_repl(L);
  }

  lua_close(L);
  return status;
}

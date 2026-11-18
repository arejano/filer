# base_bui_lua - boilerplate BUI + Lua + SQLite
#
# O BUI e construido junto com o projeto. Este CMake baixa o BUI, o lsqlite3
# e o LuaFileSystem no primeiro configure e compila o host `base-bui-lua`,
# que embute Lua 5.4, o kit de UI, SQLite3 e lfs.
#
# SPDX-License-Identifier: GPL-3.0-or-later

cmake_minimum_required(VERSION 3.20)
project(base_bui_lua LANGUAGES C CXX)

# Versao do BUI fixada para builds reproduziveis.
set(BUI_GIT_TAG "v0.5.0" CACHE STRING "Tag/commit do BUI")

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

include(FetchContent)

# --- BUI ---------------------------------------------------------------------
set(BUI_BUILD_LUA_BINDINGS     ON  CACHE BOOL "" FORCE)
set(BUI_BUILD_TESTS            OFF CACHE BOOL "" FORCE)
set(BUI_BUILD_EXAMPLES         OFF CACHE BOOL "" FORCE)
set(BUI_BUILD_PYTHON_BINDINGS  OFF CACHE BOOL "" FORCE)
set(BUI_BUILD_QT_BACKEND       OFF CACHE BOOL "" FORCE)
set(BUI_BUILD_IMGUI            OFF CACHE BOOL "" FORCE)

# Offline / fonte local:
#   cmake -S . -B build -DFETCHCONTENT_SOURCE_DIR_BUI=/caminho/para/BUI
FetchContent_Declare(bui
  GIT_REPOSITORY https://github.com/ppmpreetham/BUI.git
  GIT_TAG        ${BUI_GIT_TAG}
  GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(bui)

if(TARGET bui_lua)
  set(APP_LUA_TARGET bui_lua)
elseif(TARGET bui_lua_sys)
  set(APP_LUA_TARGET bui_lua_sys)
else()
  message(FATAL_ERROR "Alvo Lua do BUI nao encontrado")
endif()

# --- SQLite3 + lsqlite3 ------------------------------------------------------
FetchContent_Declare(lsqlite3
  URL      https://lua.sqlite.org/home/zip/lsqlite3-0.9.6.zip
  URL_HASH SHA256=2127f7b034c7651aa408882d484523dc34c0832b4e4c5a73b50153b000ab8dc8
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
FetchContent_MakeAvailable(lsqlite3)

# --- LuaFileSystem -----------------------------------------------------------
FetchContent_Declare(luafilesystem
  GIT_REPOSITORY https://github.com/lunarmodules/luafilesystem.git
  GIT_TAG        v1_9_0
  GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(luafilesystem)

find_package(Threads REQUIRED)

add_library(app_sqlite3 STATIC ${lsqlite3_SOURCE_DIR}/sqlite3.c)
target_include_directories(app_sqlite3 PUBLIC ${lsqlite3_SOURCE_DIR})
target_compile_definitions(app_sqlite3 PRIVATE
  SQLITE_THREADSAFE=1
  SQLITE_DQS=0
  SQLITE_ENABLE_FTS5
  SQLITE_ENABLE_RTREE
)
if(NOT MSVC)
  target_compile_options(app_sqlite3 PRIVATE -w)
endif()

add_library(app_lsqlite3 STATIC ${lsqlite3_SOURCE_DIR}/lsqlite3.c)
target_include_directories(app_lsqlite3 PRIVATE ${lsqlite3_SOURCE_DIR})
target_compile_definitions(app_lsqlite3 PRIVATE LSQLITE_VERSION="0.9.7")
target_link_libraries(app_lsqlite3 PUBLIC app_sqlite3 ${APP_LUA_TARGET})
if(NOT MSVC)
  target_compile_options(app_lsqlite3 PRIVATE -w)
endif()

add_library(app_lfs STATIC ${luafilesystem_SOURCE_DIR}/src/lfs.c)
target_include_directories(app_lfs PRIVATE ${luafilesystem_SOURCE_DIR}/src)
target_link_libraries(app_lfs PUBLIC ${APP_LUA_TARGET})
if(NOT MSVC)
  target_compile_options(app_lfs PRIVATE -w)
endif()

# --- Host --------------------------------------------------------------------
set(LUABUI_SRC
  ${bui_SOURCE_DIR}/bindings/lua/src/bui_lua.c
  ${bui_SOURCE_DIR}/bindings/lua/src/bui_node.c
  ${bui_SOURCE_DIR}/bindings/lua/src/bui_context.c
  ${bui_SOURCE_DIR}/bindings/lua/src/bui_window.c
  ${bui_SOURCE_DIR}/bindings/lua/src/bui_image.c)

add_executable(base-bui-lua src/main.c ${LUABUI_SRC})
target_include_directories(base-bui-lua PRIVATE
  ${bui_SOURCE_DIR}/bindings/lua/src
  ${lsqlite3_SOURCE_DIR}
)
target_link_libraries(base-bui-lua PRIVATE
  app_lsqlite3
  app_lfs
  ${APP_LUA_TARGET}
  linenoise
  bui::kit
  bui::gpu
  bui::core
  bui_api
  Threads::Threads
  ${CMAKE_DL_LIBS}
)
if(UNIX AND NOT APPLE)
  target_link_libraries(base-bui-lua PRIVATE m)
endif()

file(GENERATE
  OUTPUT  ${CMAKE_CURRENT_BINARY_DIR}/base-bui-lua.path
  CONTENT "$<TARGET_FILE:base-bui-lua>"
)

add_custom_target(run
  COMMAND        $<TARGET_FILE:base-bui-lua> ${CMAKE_CURRENT_SOURCE_DIR}/app/main.lua
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  DEPENDS        base-bui-lua
  USES_TERMINAL
)

add_custom_target(smoke
  COMMAND        $<TARGET_FILE:base-bui-lua> --headless ${CMAKE_CURRENT_SOURCE_DIR}/tests/smoke.lua
  COMMAND        $<TARGET_FILE:base-bui-lua> --headless ${CMAKE_CURRENT_SOURCE_DIR}/tests/libs.lua
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  DEPENDS        base-bui-lua
  USES_TERMINAL
)

add_custom_target(screenshot
  COMMAND        $<TARGET_FILE:base-bui-lua> --headless ${CMAKE_CURRENT_SOURCE_DIR}/scripts/screenshot.lua
                 ${CMAKE_CURRENT_BINARY_DIR}/screenshot.ppm
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  DEPENDS        base-bui-lua
  USES_TERMINAL
)

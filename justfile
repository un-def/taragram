project := 'taragram'

export PATH := `echo "$(pwd)/.rocks/bin:$PATH"`
export LUA_PATH := 'src/?.lua;src/?/init.lua'

_list:
  @just --list

install-deps:
  tarantoolctl rocks install https://raw.githubusercontent.com/un-def/httoolsp/master/httoolsp-scm-1.rockspec

install-dev-deps: install-deps
  for dep in moonscript moonpick luacheck; do tarantoolctl rocks install --server=https://luarocks.org "$dep"; done

build:
  moonc src/

watch: build
  moonc src/ -w

lint: build
  find src/ -name '*.moon' -print -exec moonpick {} \;
  luacheck src/

run: build
  tarantool src/{{project}}/main.lua

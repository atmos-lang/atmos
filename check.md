- Version:
    - GitHub:   `vATM_LUA`
    - LuaRocks: `vATMxLUA`
    - ex: `v0.2_0.2.1`
        - Atmos: `v0.2`
        - lua-Atmos: `v0.2.1`

- Self tests:

```
cd tst/
lua5.4 all.lua
```

- Projects
    - `sdl-birds/`
        - `atmos birds-11.atm`
    - `sdl-rocks/`
        - `atmos main.atm`
    - `iup-7guis/`
        - `atmos 03-flight.atm`
        - `lua5.4 server.lua` + `atmos 01-counter-net.atm`

```
git branch              # should be in `main`
git pull                # ensure newest `main`
git branch v-NEW
git checkout v-NEW
git push --set-upstream origin v-NEW
```

- Docs

```
git difftool v-OLD       # examine all diffs
```

- Branch

```
git branch              # should be in `main`
git pull                # ensure newest `main`
git branch v-NEW
git checkout v-NEW
git push --set-upstream origin v-NEW
```

- LuaRocks

```
cp atmos-lang-OLD.rockspec atmos-lang-NEW.rockspec
vi atmos-lang-NEW.rockspec
    # set version, source.branch
luarocks upload atmos-lang-NEW.rockspec --api-key=...
```

- Install

```
lua5.4 /x/lua-atmos/atmos/atmos/env/clock/exs/hello.lua
    # works

cd /usr/local/share/lua/5.4/
ls -l atmos         # check if link to dev
sudo rm atmos

lua5.4 /x/lua-atmos/atmos/atmos/env/clock/exs/hello.lua
    # fails

sudo luarocks install atmos --lua-version=5.4  # check if atmos-NEW

lua5.4 /x/lua-atmos/atmos/atmos/env/clock/exs/hello.lua
    # works
```

- Develop

```
git checkout main
git merge v-NEW
git push

lua5.4 /x/lua-atmos/atmos/atmos/env/clock/exs/hello.lua
    # works

cd /usr/local/share/lua/5.4/
sudo rm -Rf atmos/

lua5.4 /x/lua-atmos/atmos/atmos/env/clock/exs/hello.lua
    # fails

sudo ln -s /x/lua-atmos/atmos/atmos

lua5.4 /x/lua-atmos/atmos/atmos/env/clock/exs/hello.lua
    # works
```

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

- Examples:

```
cd exs/
atmos hello.atm
atmos click-drag-cancel.atm
atmos layout.atm
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
atmos /x/atmos-lang/atmos/exs/hello.atm
    # works

# remove lua-atmos-dev
# install lua-atmos

atmos /x/atmos-lang/atmos/exs/hello.atm
    # fails

sudo luarocks install atmos-lang --lua-version=5.4  # check if atmos-lang-NEW

atmos /x/atmos-lang/atmos/exs/hello.atm
    # works
```

- Develop

```
git checkout main
git merge v-NEW
git push

atmos /x/atmos-lang/atmos/exs/hello.atm
    # works

cd /usr/local/share/lua/5.4/
sudo rm -Rf atmos/

atmos /x/atmos-lang/atmos/exs/hello.atm
    # fails

sudo ln -s /x/lua-atmos/atmos/atmos

atmos /x/atmos-lang/atmos/exs/hello.atm
    # works
```

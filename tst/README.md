Assumes this directory structure:

```
atmos-lang
└── atmos
    ├── src         <-- should be linked from lua-atmos/atmos/atmos/lang
    └── tst         <-- we are here
lua-atmos
├── atmos
│   ├── atmos
│   │   └── lang    <-- should link to atmos-lang/atmos/src
│   └── tst
└── f-streams
    ├── streams
    └── tst
```

```bash
LUA_PATH="../../../lua-atmos/f-streams/?/init.lua;../../../lua-atmos/atmos/?.lua;../../../lua-atmos/atmos/?/init.lua;;" lua5.4 all.lua
```

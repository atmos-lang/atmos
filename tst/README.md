Assumes this directory structure:

```
atmos-lang/
└── atmos/
    ├── lua@        <-- should link to lua-atmos/
    ├── src/        <-- should be linked from lua-atmos/atmos/atmos/lang
    └── tst/        <-- we are here
lua-atmos/
├── atmos/
│   ├── atmos/
│   │   └── lang@   <-- should link to atmos-lang/atmos/src
│   └── tst/
└── f-streams/
    ├── streams/
    └── tst/
```

```bash
LUA_PATH="../lua/f-streams/?/init.lua;../lua/atmos/?.lua;../lua/atmos/?/init.lua;;" lua5.4 all.lua
```

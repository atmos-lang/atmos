# Examples

## pico-sdl

The following examples require `pico-sdl`:

- `clicks.atm`
- `click-drag-cancel.atm`

If testing from sources:

```bash
sudo luarocks --lua-version=5.4 install pico-sdl
```

If testing from full installation:

```bash
sudo luarocks --lua-version=5.4 install atmos-env-pico
```

## Source

Assumes this directory structure:

```
.
├── atmos-lang/
│   └── atmos/
│       └── exs/   <-- we are here
└── lua-atmos/
    └── atmos/
```

```bash
LUA_PATH="../../../lua-atmos/atmos/?.lua;../../../lua-atmos/atmos/?/init.lua;;" ../atmos hello.atm
```

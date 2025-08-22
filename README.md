# What's that?

The nvim plugin to automatically generate valid jedi-language-server LSP configuration for ya.make build system. It honours `NAMESPACE` override in `PY_SRC`.

# Quickstart 

## Installation 

Install the plugin via the following command in `init.lua`:

```lua
Plug('segoon/yamake-python-lspconfig.nvim')
...

require('yamake-python-lspconfig').setup({
  -- autorestart LSP after pyrightconfig.json (re)generation
  autorestart_lsp = true,
  -- do not ask for "generate config?" if it is missing
  autogenerate_config = false,
  -- root directory for dummy vscode ide project
  ide_rootdir = os.getenv('HOME') .. '/.local/share/nvim/yamake-python-lspconfig',
  -- if true, generate pyrightconfig.json file near ya.make
  -- if false, generate it in `ide_rootdir` subdirectory
  is_config_in_arcadia = false,
})
```

## Manual config file regeneration

It is possible to regenerate `pyrightconfig.json` with the following command:

```
:GeneratePyrightconfig
```

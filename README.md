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
})
```

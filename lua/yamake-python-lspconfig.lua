local vim = vim

local wait_restart_clients = {}

local function locate_pyright_config_json(yamake_module)
  local dir = vim.fs.root(yamake_module, 'pyrightconfig.json')
  if dir then
    return dir .. '/pyrightconfig.json'
  else
    return nil
  end
end

local function array_equal(a, b)
  if #a ~= #b then
    return false
  end

  for i = 1, #a do
    if a[i] ~= b[i] then
      return false
    end
  end

  return true
end

local function read_file(filename)
  local file = io.open(filename)
  if not file then
    return nil
  end
  local content = file:read('a')
  file:close()
  return content
end

local function setup_lsp(pyright_config)
  -- https://github.com/microsoft/pyright/blob/main/docs/configuration.md
  -- extraPaths [array of strings, optional]: Additional search paths that
  -- will be used when searching for modules imported by files.
  local content = read_file(pyright_config)
  local json = vim.fn.json_decode(content)
  local extra_paths = json['extraPaths']
  if extra_paths == nil then
    return
  end

  local lsp_clients = vim.lsp.get_clients({ bufnr = 0 })
  for _, client in ipairs(lsp_clients) do
    local name = client['name']
    if name == 'jedi_language_server' then
      local init_options = client.config.init_options
      local workspace = nil
      if init_options then
	workspace = init_options['workspace']
      end
      if workspace and array_equal(workspace['extraPaths'], extra_paths) then
	-- OK, we've already restarted the client with the fixed config
	goto continue
      end

      print('restarting LSP server to apply extraPaths...')
      wait_restart_clients[client.id] = true
      vim.schedule(
	function()
	  vim.lsp.config(
	    'jedi_language_server',
	    {
	      init_options = {
		jediSettings = {
		  debug = true
		},
		workspace = {
		  extraPaths = extra_paths
		}
	      }
	    }
	  )

	  vim.schedule(
	    function()
	      vim.lsp.stop_client(client['id'])
	    end
	  )
	end
      )
    end

    ::continue::
  end
end

local function generate_project(yamake_module, callback)
  local on_exit = function(obj)
    if obj.code ~= 0 then
      error('"ya ide vscode" exited with status code ' .. obj.code)
      return
    end

    -- TODO: signal

    -- TODO: config: allow storing pyrightconfig.json in plugin's directory
    local pyright_config = yamake_module .. '/pyrightconfig.json'
    vim.schedule(
      function()
	callback(pyright_config)
      end
    )
  end

  -- TODO: generate in a unique subdirectory of plugin's directory
  vim.system(
    {'ya', 'ide', 'vscode', '--py3', '-P', '~/ide'},
    {
      text = true,
      cwd = yamake_module,
    },
    on_exit
  )
end

local function on_attach(_)
  local yamake_module = vim.fs.root(0, 'ya.make')
  if not yamake_module then
    -- Not in Arcadia
    return
  end

  local pyright_config = locate_pyright_config_json(yamake_module)
  if pyright_config then
    setup_lsp(pyright_config)
    return
  else
    -- TODO: config: autogenerate and don't ask
    vim.ui.input(
      {
	prompt = 'Generate "pyrightconfig.json" for ' .. yamake_module .. '? [Y/n]',
      },
      function(input)
	if input == '' or input == 'y' or input == 'Y' then
	  generate_project(
	    yamake_module,
	    function(created_pyright_config)
	      setup_lsp(created_pyright_config)
	    end
	  )
	end
      end
    )
  end
end

local function on_detach(args)
  local bufnr = args['buf']
  local client_id = args.data.client_id
  if wait_restart_clients[client_id] then
    wait_restart_clients[client_id] = nil

    local config = vim.deepcopy(vim.lsp.config.jedi_language_server)
    config.root_dir = vim.fs.root(bufnr, config.root_markers)
    vim.schedule(
      function()
	vim.lsp.start(
	  config,
	  {
	    bufnr = bufnr,
	    reuse_client = false,
	  }
	)
	print('LSP server is restarted')
      end
    )
  end
end


local M = {}

function M.setup()
  vim.api.nvim_create_autocmd({'LspAttach'}, {
    pattern = '*.py',
    callback = on_attach
  })

  vim.api.nvim_create_autocmd({'LspDetach'}, {
    pattern = '*.py',
    callback = on_detach
  })
end

return M

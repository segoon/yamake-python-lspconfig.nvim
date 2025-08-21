local vim = vim

local wait_restart_clients = {}

local function locate_pyright_config_json(yamake_module)
  local dir = vim.fs.root(0, 'pyrightconfig.json') 
  if dir then
    return dir .. '/pyrightconfig.json'
  else
    return nil
  end
end

local function array_equal(a, b)
  if #a ~= #b then
    print('1')
    return false
  end

  for i = 1, #a do
    if a[i] ~= b[i] then
    print('2')
      return false
    end
  end

    print('3')
  return true
end

local function setup_lsp(bufnr, pyright_config)
  -- print(pyright_config)
  local file = io.open(pyright_config)
  if not file then
    return
  end
  --print(file)
  local content = file:read('a')
  --print(content)
  file:close()
  local json = vim.fn.json_decode(content)
  local extra_paths = json['extraPaths']
  -- print('extra_paths', vim.inspect(extra_paths))
  if extra_paths == nil then
    return
  end

  local lsp_clients = vim.lsp.get_clients({ bufnr = 0 })
  for _, client in ipairs(lsp_clients) do
    local name = client['name']
    if name == 'jedi_language_server' then
      --print(vim.inspect(client))
      -- client.config.init_options = vim.tbl_deep_extend('force', client.config.init_options, { workspace = { extraPaths = extra_paths } })
      -- print(vim.inspect(client))
      --print('client', vim.inspect(client))
      --print('init_options', vim.inspect(client.config.init_options))

      local config = client.config
      local init_options = config['init_options']
      print('init_options', vim.inspect(init_options))
      print('...config', vim.inspect(vim.lsp.config.jedi_language_server))
      local workspace = nil
      if init_options then
	workspace = init_options['workspace']
      end
      if workspace and array_equal(workspace['extraPaths'], extra_paths) then
	-- OK, we've already restarted the client with the fixed config
	print('continue')
	goto continue
      end

      -- Set extraPaths in init_options

	  -- print('restart')
	  wait_restart_clients[client.id] = true
	  vim.defer_fn(
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

	      vim.defer_fn(
		function()

		  vim.lsp.stop_client(client['id'])
		end,
		1000
	      )
	    end,
	    1000
	  )

	  -- on_detach() will re-start the client
    end

    ::continue::
  end
  -- print('end of loop')
end

local function generate_project(yamake_module, callback)
end

local function on_attach(attach_args)
  local yamake_module = vim.fs.root(0, 'ya.make')
  if not yamake_module then
    -- Not in Arcadia
    return
  end

  local pyright_config = locate_pyright_config_json(yamake_module)
  if pyright_config then
    setup_lsp(attach_args['buf'], pyright_config)
    return
  else
    vim.ui.input(
      { prompt = 'Generate "pyrightconfig.json" for ' .. yamake_module .. '? [Y/n]' },
      function(input)
	if input == '' or input == 'y' or input == 'Y' then
	  generate_project(
	    yamake_module,
	    function(created_pyright_config)
	      setup_lsp(attach_args['buf'], created_pyright_config)
	    end
	  )
	end
      end
    )
  end
end

local function on_detach(args)
  --print('on_detach', vim.inspect(args))

  local bufnr = args['buf']
  local client_id = args.data.client_id
  if wait_restart_clients[client_id] then
    print('starting in detach...')
    wait_restart_clients[client_id] = nil

    print('config', vim.inspect(vim.lsp.config.jedi_language_server))

    local config = vim.deepcopy(vim.lsp.config.jedi_language_server)
    config.root_dir = vim.fs.root(bufnr, config.root_markers)
    vim.defer_fn(
      function()
	vim.lsp.start(
	  config,
	  {
	    bufnr = bufnr,
	  }
	)
      end,
      1000
    )
  end
end

vim.api.nvim_create_autocmd({'LspAttach'}, {
  pattern = '*.py',
  callback = on_attach
})

vim.api.nvim_create_autocmd({'LspAttach'}, {
  pattern = '*.py',
  callback = function(_)
    print('LspAttach')
  end
})
vim.api.nvim_create_autocmd({'LspDetach'}, {
  pattern = '*.py',
  callback = on_detach
})

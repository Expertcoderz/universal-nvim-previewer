# 👁️ universal-nvim-previewer

A dead-simple Neovim plugin for previewing files, supporting arbitrary
filetypes.

## Features

- written in 100% Lua
- platform-independent
- doesn't invoke the shell or any external commands other than those used for
  processing and previewing
- cleans up temporary files on keymap trigger and upon buffer close
- compatible with previewer applications that fork after opening (e.g. some web
  browsers)

## How It Works

1. Upon keymap trigger (`start`), run a *processor* application, chosen based
   on the current filetype, to generate the temporary file used for the preview.
   A preview is now considered to be active.
2. Run a *previewer* application, chosen based on the current filetype, to
   preview the file. This step is omitted if a preview is already active, in
   which case the user can manually refresh the file from the previewer.
3. Upon keymap trigger (`stop`), or when the buffer is closed, clean up the
   temporary file used for the preview. The preview is now no longer active.

Note that universal-nvim-previewer doesn't care about the state of the previewer
application after it has been launched. To see changes in the preview, the user
must manually refresh it (in a way specific to the application); to close the
preview, the user must manually close the application. This is an intentional
design choice to accomodate web browsers that don't provide a means of being
notified when the file changes (making automatic refresh difficult or kludgy to
implement) and don't necessarily close the correct tab upon SIGTERM due to
their multi-process design (preventing the preview from being closed from nvim).

## Installation

Example setup with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "Expertcoderz/universal-nvim-previewer",
    opts = {}, -- mandatory; leave blank to use the defaults
}
```

## Configuration

universal-nvim-previewer is configured by defining certain values under the
`opts` table (which is passed to the `setup` function of the plugin module).

### Processors

Processor applications are configured by specifying the dictionary `processors`
under `opts`. In this dictionary, each filetype (based on the value of
`vim.bo.filetype`) is mapped to a function that takes in the path to a temporary
preview file (`outputPath`) and optionally the filetype itself (`filetype`),
returning a table of the command to run plus the arguments to supply to it.
This command is expected to accept the current Neovim buffer's contents from
standard input and place the processed output at `outputPath`; previewing will
fail if no file at `outputPath` is readable after the processor command exits.

The default setting of the `processors` dictionary is:

```lua
{
    ["markdown"] = function(outputPath)
        return { "pandoc", "-f", "commonmark_x", "-t", "html", "-o", outputPath }
    end,
    ["rst"] = function(outputPath)
        return { "pandoc", "-f", "rst", "-t", "html", "-o", outputPath }
    end,

    -- Default processor for other filetypes
    -- (If no default is set, previewing will be disabled for such filetypes.)
    [""] = function(outputPath, filetype)
        if filetype == "make" then
            filetype = "makefile"
        end
        return { "highlight", "-S", filetype, "-O", "html", "-k", "monospace", "-o", outputPath }
    end,
}
```

### Previewers

Previewer applications are configured similarly to processor applications; the
default setting of the `previewers` dictionary is:

```lua
{
    -- Default previewer (opens the default web browser on the temporary file)
    -- (If no default is set, previewing will be disabled for such filetypes.)
    -- (The second argument is the filetype but it is unused in this example.)
    [""] = function(outputPath, _)
        return { vim.env.BROWSER, outputPath }
    end,
}
```

### Keymaps

Keymaps can be customized in the `keymaps` dictionary under `opts`. The default
setting is:

```lua
{
    start = "+",
    stop = "-",
    stopAll = "_",
}
```

## License

universal-nvim-previewer is licensed under the MIT License. See the LICENSE
file for more information.

# my-lisp LSP for the FPGA toolchain

`assembler.my` is edited as ordinary my-lisp source and can use the
canonical `my-lisp-lsp` server. The FPGA repository does not introduce a
second parser or language server.

## Editor command

Configure the editor's LSP command as:

```text
/home/agents/GitHub/my-lisp/target/release/my-lisp lsp
```

The server speaks JSON-RPC over stdio with `Content-Length` framing. Set the
workspace root to this repository so the server indexes `*.my` files,
including `assembler.my` and `docs/reference/my-lisp-lib/*.my`.

The equivalent debug build command is `target/debug/my-lisp lsp` from the
`my-lisp` repository. The standalone `my-lisp-lsp` binary is equivalent, but
the CLI subcommand is the preferred stable entrypoint.

## Verified connection

On 2026-08-24 the release binary completed a real `initialize` handshake for
the `fpga-lisp` workspace and advertised diagnostics, document symbols,
hover, definition, completion, references, and rename capabilities. The
server is therefore an editor integration path, not just a library build.

## Boundary

LSP provides language feedback for `assembler.my`; it does not replace the
host-side UART tools. `upload.py` and `monitor.py` remain Python because they
control physical serial hardware rather than transform my-lisp data.

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

---

# Інтеграція my-lisp LSP для інструментарію FPGA (Ukrainian)

`assembler.my` редагується як звичайний сирцевий код `my-lisp` і може 
використовувати канонічний сервер `my-lisp-lsp`. Репозиторій FPGA не вводить 
другий парсер чи мовний сервер (language server).

## Команда для редактора

Налаштуйте команду LSP у вашому редакторі так:

```text
/home/agents/GitHub/my-lisp/target/release/my-lisp lsp
```

Сервер спілкується через JSON-RPC по `stdio` із кадруванням `Content-Length`. 
Встановіть корінь робочого простору (workspace root) на цей репозиторій, 
щоб сервер проіндексував файли `*.my`, включно з `assembler.my` та 
`docs/reference/my-lisp-lib/*.my`.

Еквівалентна команда для дебаг-білда — `target/debug/my-lisp lsp` з репозиторію 
`my-lisp`. Окрема бінарна програма `my-lisp-lsp` є еквівалентною, але 
підкоманда CLI є рекомендованою стабільною точкою входу.

## Підтвердження підключення

2026-08-24 релізний бінарник успішно завершив справжнє рукостискання (handshake) 
`initialize` для робочого простору `fpga-lisp` і заявив про підтримку 
діагностики, символів документа, наведення миші (hover), переходів до визначень 
(definition), автодоповнення (completion), пошуку посилань (references) та 
перейменування (rename). Таким чином, сервер є реальним шляхом інтеграції з 
редактором, а не просто бібліотечним білдом.

## Межі відповідальності

LSP надає мовний зворотний зв'язок (language feedback) для `assembler.my`; 
він не замінює хостові інструменти UART. Скрипти `upload.py` та `monitor.py` 
залишаються на Python, оскільки вони керують фізичним послідовним обладнанням 
(serial hardware), а не трансформують дані my-lisp.

# Evidence protocol

See `my-lisp`'s [`evidence/README.md`](../../my-lisp/evidence/README.md) (commit
`f96936d`) for the full schema — this is fpga-lisp's copy of the same
convention, not a fork of it. One evidence file per (requirement,
implementation, commit) triple at `evidence/<requirement-id>/fpga-lisp/<short-sha>.my`,
keyed by the `G1`-`G8`/`S1`-`S3` requirement IDs from my-lisp's
`docs/language-core-axioms.md`. Data only — read via `(read-file ...)`,
never `(load ...)`.

This replaces hand-copying "PASSED" into `docs/lisp-machine-plan.md`'s
prose or a cross-session message asserting a result. Those docs still
narrate the *how* and *why*; this directory is the checkable *fact*.

---

# Протокол доказів (Ukrainian)

Дивіться [`evidence/README.md`](../../my-lisp/evidence/README.md) 
у репозиторії `my-lisp` (коміт `f96936d`) для повного опису схеми — 
це копія тієї самої конвенції для `fpga-lisp`, а не її форк. Один 
файл доказів створюється на кожну трійку (вимога, реалізація, коміт) 
за шляхом `evidence/<requirement-id>/fpga-lisp/<short-sha>.my`, і 
ключем виступають ідентифікатори вимог `G1`-`G8`/`S1`-`S3` з 
`docs/language-core-axioms.md` репозиторію my-lisp. Це виключно дані — 
читати через `(read-file ...)`, ніколи не використовувати `(load ...)`.

Це замінює ручне копіювання слова "PASSED" у текст `docs/lisp-machine-plan.md` 
або міжсесійні повідомлення, які стверджують результат. Ті документи досі 
розповідають *як* і *чому*; ця директорія містить *факт*, який можна перевірити.

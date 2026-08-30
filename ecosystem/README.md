# ecosystem/ scaffold (Swarm Contract v0.1, FPGA-SWARM-CONTRACT-01)

Per `repo.my`'s `(imports language-contract compatibility)`: fpga-lisp
doesn't track cross-repo state as versioned epistemic "claims" the way
`shiva-sutras`/`my-lisp-panini` do (see their `ecosystem/imports/*.my`
files, `(claim ID (revision ...) (status ...))` shape) -- fpga-lisp's
imports are contracts, not hypotheses: `isa-contract.my` and
`compatibility.my` are git-tracked, versioned, and either match or
don't (no "supported"/"disputed" gradient). The durable record of
whether an import is currently honored lives in commit history and
`ecosystem-status.md`, not a separate claims file here.

No `imports/*.my` files are populated in this scaffold as of this
writing -- an empty placeholder would be worse than an explanation of
why it's empty, per the same "don't fabricate to fill a template"
principle this repo already applies elsewhere (see
`fixture_coverage.py`'s UNCLASSIFIED category, `docs/hardware-setup.md`'s
"not yet tried" notes).

---

# ecosystem/ scaffold (Swarm Contract v0.1, FPGA-SWARM-CONTRACT-01) (Ukrainian)

Згідно з `(imports language-contract compatibility)` з `repo.my`: 
fpga-lisp не відстежує міжрепозиторний стан як версіоновані епістемічні "твердження" 
(`claims`) у той спосіб, як це роблять `shiva-sutras`/`my-lisp-panini` 
(див. їхні файли `ecosystem/imports/*.my`, формат `(claim ID (revision ...) (status ...))`). 
Імпорти fpga-lisp — це контракти, а не гіпотези: `isa-contract.my` та 
`compatibility.my` відстежуються в git, мають версії і або збігаються, або ні 
(немає градієнта "supported"/"disputed"). Довговічний запис про те, чи виконується 
імпортований контракт наразі, зберігається в історії комітів та 
`ecosystem-status.md`, а не в окремому файлі тверджень тут.

Жодних файлів `imports/*.my` у цьому каркасі (scaffold) на момент написання 
не заповнено — порожня заглушка (placeholder) була б гіршою, ніж пояснення, 
чому тут порожньо, згідно з тим самим принципом "не вигадуй заради заповнення 
шаблону", який цей репозиторій вже застосовує в інших місцях 
(див. категорію UNCLASSIFIED у `fixture_coverage.py`, або примітки 
"not yet tried" у `docs/hardware-setup.md`).

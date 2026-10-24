# Лицензии / Licenses

- CheatKit trainer, bridge and scripts: jestelf, [MIT](../LICENSE).
- Cyber Engine Tweaks 1.37.1 with experimental local 2.5 changes: [upstream](https://github.com/maximegmd/CyberEngineTweaks), [MIT](CET-MIT.txt). Runtime third-party/font notices are retained. Source changes: [ports/cet25](../ports/cet25/README.md).
- RED4ext 1.30.0: [upstream](https://github.com/wopss/RED4ext), runtime `LICENSE.txt` and `THIRD_PARTY_LICENSES.txt` retained.
- RED4ext SDK: [upstream](https://github.com/wopss/RED4ext.SDK), [MIT](RED4ext-SDK-MIT.txt), source patches under `ports`.
- redscript 1.0.0-preview.22: [upstream](https://github.com/jac3km4/redscript), [MIT](redscript-LICENSE.txt).
- Ultimate ASI Loader: [upstream](https://github.com/ThirteenAG/Ultimate-ASI-Loader), runtime `bin/x64/LICENSE` retained.
- CET name dictionaries: standard community runtime resources distributed by CET/WolvenKit; retained with upstream notices. No game textures, localization archives, scripts cache or executable is included.

Наш CET — экспериментальная адаптация, а не официальный релиз 2.5. Лицензия CheatKit не заменяет лицензии зависимостей.

В комплектных PE зависимостей удалены CodeView-метаданные и абсолютные пути в диагностических строках; исполняемые секции сохранены. Поэтому хеши могут отличаться от исходных upstream архивов. Метод очистки открыт в `tools/clean_pe_paths.py`.

Our CET is an experimental adaptation, not an official 2.5 release. CheatKit's license does not replace dependency licenses.

Bundled dependency PE files have CodeView metadata and absolute diagnostic paths removed while preserving executable sections. Their hashes may therefore differ from original upstream archives. The cleanup method is available in `tools/clean_pe_paths.py`.

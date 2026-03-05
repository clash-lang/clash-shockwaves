## How to set up Shockwaves

To start using shockwaves, you need three things:
- the latest version of [Surfer](https://gitlab.com/surfer-project/surfer)
- the Shockwaves Surfer extension (see the `surfer_shockwaves` folder; compiled versions can be found as artefacts under the Actions tab)
- the `Clash.Shockwaves` Haskell library (this repo, in `/shockwaves/`)

Install Surfer (available [here](https://surfer-project.org/)) and add the Shockwaves extension (instructions below).
If the extension is installed correctly, Surfer's console output should clearly show it
logging messages.

Add the repository `clash-lang/clash-shockwaves` to your Haskell project (instructions below).

### GETTING AND INSTALLING THE SURFER EXTENSION

To use Shockwaves, you need the Shockwaves translator extension WASM file.
Precompiled version can be found on this github's Actions page, under `> surfer-release-compile`
([here](https://github.com/clash-lang/clash-shockwaves/actions/workflows/surfer-release.yml)).
Make sure to unzip the artefact - you need `surfer_shockwaves.wasm`.

The `.wasm` file needs to be placed in Surfer's translators directory.
This is `~/.local/share/surfer/translators` on Linux.
If you do not have any other Surfer extensions, you will need to create this folder yourself.

Alternatively, you can compile `surfer_shockwaves/`  yourself.
The `compile.sh` script in `surfer_shockwaves/` performs compilation with the right settings.
You can supply the script with the options `linux` or `windows` to automatically copy the
translator to the right directory.

The correct location of the file is also printed by Surfer when it looks for extensions.
The output should contain a message like this, indicating the right folder.

```
INFO libsurfer::translation::wasm_translator: Looking for translators in /home/Me/.local/share/surfer/translators
```

If the translator is found, the output should look like this:
```
INFO libsurfer::translation::wasm_translator: Found /home/Me/.local/share/surfer/translators/surfer_shockwaves.wasm
```

> Note: some of the logging statements may be changed by the Surfer devs!


### ADDING SHOCKWAVES TO YOUR PROJECT

For Stack, add the following to your `stack.yaml` file:

```yml
- git: https://github.com/clash-lang/clash-shockwaves.git
  commit: <commit name>
  subdirs:
  - shockwaves
```

For Cabal, add the following to your `cabal.project` file:

```yml
source-repository-package
  type: git
  location: https://github.com/clash-lang/clash-shockwaves.git
  tag: 8bac2a6ee1dbc6bb5018bd749bb86a8b9663b020
  subdir:
    shockwaves
```

Finally, add `shockwaves` as a dependency to your `<project>.cabal` file.

For simple usage, you just need to import `Clash.Shockwaves`.
Since both `Clash.Shockwaves` and `Clash.Prelude` export tracing functions,
you might want to use a qualified import of `Clash.Shockwaves.Trace`,
or hide the functions exported by the prelude.

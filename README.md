![logo](docs/shockwaves_logo.svg)

# clash-shockwaves

Shockwaves is a typed waveform viewer solution for Clash. It consists of two parts:

1. A Haskell library (`Clash.Shockwaves`) that provides tools for representing Haskell types as waveforms,
   customizing the appearance, and performing tracing simulations that store additional translation information.
2. An extension to the Surfer waveform viewer, that can use this additional information to display the waveforms.

To get started with Shockwaves, see the [HOWTO guides](docs/howto/README.md).

## Features

Some of the features of Shockwaves:

- Automatically derived waveform representations
- Native support for all standard Clash types
- Easily customizable styling
- Modular translator system that gives you full control over the translation
- Direct replacement for `Clash.Signal.Trace`
- Waveforms for clock, reset and enable signals
- Advanced customization through config files

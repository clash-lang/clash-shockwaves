



This is an attempt at a flowchart decision tree for creating `Waveform` instances.


? Simple translation (sum, product, subtypes with `Waveform`)?
Y:  Derive `Waveform` / create `Waveform` instance (see [this](WAVEFORM.md))
    ? Standard structure ok?
    Y:  Keep most defaults.
        ? Do you want custom styles per constructor?
        Y: Overwrite `constructorStyles` (see [this](STYLES.md))
        N: Don't change a thing.
    N:  Overwrite `translator` with a custom implementation that matches the `BitPack` representation.
        Use functions like `tRef`, `tConst`, `tStyled`, `tDup` to make your life easier.
N:  ? Is the type anteger?
    Y:  Use `WaveformForNumber` (see [this](NUMBERS.md))
    N:  ? Constant?
        Y:  Use `WaveformConst` (see [this](CONSTANT.md))
        N:  Use WaveformLUT (see [this](LUTS.md))
            ? Only minor change to text value?
            Y:  Standard derive, overwrite `Show`.
            N:  ? Simple atomic?
                Y:  Use one of the atomic functions.
                    ? Are you displaying a signed number?
                    Y:  Use `translateAtomSigWith` or `translateAtomSigShow`.
                    N:  Use `translateAtomWith` or `translateAtomShow`.
                N:  Use `translateWith`.
                    ? Standard `show`, `WSNormal`, standard precedence?
                        Y:  Use `displayShow`.
                        N:  Use `displayWith` with a custom function.
                    ? Custom style?
                        Y:  Use a custom function (see [this](STYLES.md)).
                        N:  Use `const WSNormal`.
                    ? Custom operator precedence?
                        Y:  Use a custom function for the precedence, like `const 11`.
                        N:  Use `precL`.
                    ? Standard subsignals?
                        Y:  Use `splitG`.
                        N:  Use custom implementation and overwrite `structureL` accordingly.
                            Use `translateFieldsG` from `WaveformG` if possible to make life easier.
                            
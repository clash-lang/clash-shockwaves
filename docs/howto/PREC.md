## How to use the precedence system

Haskell operators have a precedence to control the order of operations.
For example, `a*b+c*d` is evaluated as `(a*b)+(c*d)`.
If you want to evaluate `a*(b+c)*d`, you need to add parentheses.

Shockwaves is designed to produce valid Haskell values, which includes taking
into account these precedences.

Each value is accompanied by a precedence value. This value indicates the lowest
precedence of the relevant operators in the string representation.
When the value is embedded in the string of a parent signal, parentheses
are added if the precedence of operators in the string is equal of higher.

Let's say we have a value that looks like `MyType (4 :> Nil)`. The `:>` operator
has precedence `5`, but has already been wrapped in parentheses and is thus not relevant.
The operator we're interested in is the space between `MyType` and the vector.
This has a precedence of `10`.

If we were to put this value inside another vector, the operator of the vector
would have precedence `5`, which is lower than `10`, so no parentheses are added:
`MyType (4 :> Nil) :> Nil`. However, if it's another unnamed field, spaces are used
there too, and the value requires additional parentheses:
`MyOtherType (MyType (4 :> Nil))`.

But what if there are no operators at all? In that case, the correct value depends
on whether it is related to the value we are embedding, or the context it is placed
in.

If a value has no operators, we never want to add parentheses, and thus we need
to set the precedence above the highest operator precedence allowed in Haskell.
Operator precedences range from `0` to `10`, so we use `11`.
For example, in `LampOn Red`, the value `Red` with precedence `11` gets places in
a context `LampOn _` with precedence `10` (due to the space operator).

If the context has no operators, we need the exact opposite: to never add parentheses,
we set the precedence to `-1`. For example, in `MyType{vec = 4 :> Nil}`,
the value `4 :> Nil` with precedence `5` is placed inside the context `MyType{vec = _}`
which uses precedence `-1`, because there are no operators. The resulting value
`MyType{vec = 4 :> Nil}` has no
exposed operators, and thus uses precedence `11` again.

In a product translator, the "inner" precedence refers to the precedence value that is
used for the context of its subvalues, and the "outer" precedence is the precedence
of the resulting value.


Thus, for creating custom values and implementations:
- for a value, pick the lowest predecence amongst operators in the outermost "scope"
- for a context, pick the highest precedence amongst operators that are in the same "scope"
  as the values
- for atomic values (without operators), use precedence `11`
- for contexts without operators, use `-1`

These rules are also used by the automatically derived `Waveform` instances.

> **Note:** Signed numbers are a bit of an exception. While negative values might
> *seem* like atomics, in Haskell the `-` sign is actually a prefix operator with
> precedence `6`. The Number translator, when using the signed format, will use
> precedence `6` for negative numbers (regardless of any prefix).

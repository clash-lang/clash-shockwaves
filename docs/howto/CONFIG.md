
## How to customize Shockwaves behaviour
It is possible to further communicate the behaviour of Shockwaves through
the use of configuration files. This guide shows you how to set up the configuration
files and their options.

### SETTING UP CONFIG FILES
The first step is to create configuration files.
There are two places to add these files: the global configuration directory for
Surfer extensions, and the folder that VCD files are opened in.

To find the global configuration folder, simply look at the logging output of
Surfer:
```
SHOCKWAVES: Looking for global config file: Looking for global config file: /home/me/.config/surfer/translators/shockwaves/config.toml
```

A similar message appears indicating the local directory whenever a file is opened.
Create a file called `config.toml` in the global Shockwaves config directory,
or a file called `shockwaves.toml` in the same folder as the VCD file.
If the file is found and readable, the logs will look something like this:

```
 INFO extism::pdk: SHOCKWAVES: Parsed config file
```

The following sections explain how to add settings. Keep in mind that local settings
overwrite global settings. A good default configuration file template can be found [here](config/shockwaves.toml).

### ERROR PROPAGATION

By default, Shockwaves will propagate the `Error` style all the way to the toplevel.
This style is used for values that are undefined (but shouldn't be), and thus any
data containing the value is also not fully defined. Without this, it would
be relatively hard to track down undefined values.

There may, however, be cases where this is unwanted behaviour. You might want
to be able to see normal styles even if some subvalue is undefined. Thus, you
can turn it off:

```t
propagate_errors = false
```


### NUMBER FORMAT AND SPACER SETTINGS

You may run into a situation where the default number format or spacers do not suit your needs,
particularly when using a predefined numerical type.
In this case, you can override the format and spacers used for numbers.
The latter can be done per number format.

To override the number format for all numbers, use:
```
override_number_format = 'S'
```
Options are `S`/`Sig`, `U`/`Uns`, `H`/`Hex`, `O`/`Oct`, `B`/`Bin`.
Keep in mind that this will produce values that no longer match Haskell.

> **Note:** Overriding the format resets the spacer options; you can still use the method
> described below to get back the spacers.

If you want unsigned numbers to be separated by `'` insted of `_`, write:
```
override_uns_spacer = [3,"'"]
```

Alternatively, to remove the spacers alltogether, set the number of digits between spacers
to `0`:

```
override_uns_spacer = [0,""]
```

Keep in mind that data types using LUTs are not translated by Surfer, and as such
these settings will have no effect.

### STYLES

Finally, you might want to configure styles without changing the Haskell code.
The configuration files can specify a list of style files containing style variables,
and alternatively specify style rules directly.

For example, Haskell's `Either` is often used to denote results that might be
either some error value (`Left`) or a success value (`Right`). For this reason,
you might want to change whether `Either` uses colors that indicate this, or
some other arbitrary colors that indicate the constructor, or just keep both values
plain.

Let's set up styles for this specific instance. First create a global configuration file.
Then, add these lines:

```t
styles = ["either_normal"]
# styles = ["either_result"]
```

Then, in the configuration folder, create the directory `shockwaves/styles/` and
create the files `either_normal.toml` and `either_result.toml`.

In `either_normal.toml`, we can define both values to be normal:
```t
either_left = "N"
either_right = "N"
```

> Using `"NORMAL"`/`"N"`, `"ERROR"`/`"E"`, `"HIDDEN"`/`"H"`, `"INHERIT"`/`"I"`,
> `"WARN"`/`"W"`, `"UNDEF"`/`"U"`, `"HIGHIMP"`/`"Z"` `"WEAK"`/`"Q"`, `"DONTCARE"`/`"X"`,
> you can use any of the other standard styles.
> `"INHERIT"`/`"I"` defaults to `WSInherit 0`; to use other subsignals as a style source,
> write `"I n"` where `n` is the index of the subsignal
> 
> The default style variables are `either_left`, `either_right`, `bool_true`, `bool_false`, `maybe_nothing` and `maybe_just`.

Actually, let's give them slightly different colors - not something that screams
"bad" and "good", but something different nonetheless. We can write colors using hexadecimal values:

```t
either_left  = "#007600"
either_right = "#43ba43"
```

Now, in `either_result.toml`, we can define some other colors. But let's make
these colors reusable - we might want to use these colors later, and copying
the hex codes gets rather tedious. So first, let's add some custom colors to
the global configuration file. At the bottom, put:

```t
[style]
color_good = "#0c0"
color_bad  = "#c60"
```

and in `either_result.toml`, we refer to these by prefixing the variable name with `$`:

```t
either_left="$color_bad"
either_right="$color_good"
```

Shockwaves reads all variables, in the order in which the style files are listed,
overwriting older definitions of variables with new ones. Only then does it compute any
of the actual colors. This let's you use multiple style templates, predefined colors,
etc. To select the `either_normal` and `either_result` styles, you can uncomment one line
in the global config file, or you can select one and temporarily add the other to
the local config file - both will be loaded, but the variables in the style file specified
locally will overwrite those in the style file added in the global config file.

> **Important:** Recursive definitions will crash Surfer!

Generally, a good way to set up style configurations is to have some files
for one or more themes that you might want to switch between. Similarly, you could
add a local style file. If you then wish to switch to a different theme, you can
add it to the local config file and reload, or add some small tweaks.

If you *really* want to be fancy, you can define named colors in style files
for all of Surfer's own themes, and select one in the global configuration.
You can then add a local configuration file, in which you can select another style
file, overwriting the variables, while also adding some style variables directly
for data types in your design.

You can even add *multiple definitions* in case variables fail. The following
style will first try to evaluate `var1`, then `var2`, and finally default to
magenta. Really, anything is possible.

```t
var = ["$var1","$var2","#f0f"]
```

> **Note:** Style files are reread whenever a VCD file is opened, and so is the
> local configuration file. The global configuration file, however, is not;
> as such styles specified directly in this file do not get updated.


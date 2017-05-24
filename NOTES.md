# lips internal architecture

…since i'm new to parsers and doomed to forget how my own programs work.

## public interface

(note: this should be moved to the readme or something)

in the simplest case, you just call the table returned by
`require 'lips.init'` as seen in `example.lua`.

lips also returns, in said table: the usual package metadata,
and a `writers` table of pre-defined writers.

in the call interface,
a `writer` function and a table of `options` may be passed
as further arguments after `fn_or_asm`.

```
TODO: example
```

`writer` could be one of the `lips.writers` provided,
after instantiating with a call (it makes use of closure locals).

```
TODO: example
```

options is a table of string keys and any type of value.
currently there is:
```
.unsafe (default false)
    if set, don't wrap the main assembler call in a pcall().
    i want to deprecate this, because it's unnecessary code
    that the user could handle just as well from outside the interface.
.offset (deprecated)
    sets options.origin and options.base simultaneously.
    since the address-base feature was added,
    the preferred way of doing this is by setting them individually,
    so this option is deprecated.
.origin (default 0)
    where to initially start writing in the file.
    this simply tacks on an .org directive
    to the start of the internal assembly.
.base (default 0)
    how far to offset the assembler in where it thinks it's writing.
    this is incredibly important for writing code in ROM
    that is read into a static place in RAM.
    this simply tacks on a .base directive
    to the start of the internal assembly.
.path (default containing directory of assembly file, if applicable)
    primarily used internally for handling relative imports.
.labels (default {})
    note: lips modifies the argument in-place.
    allows for exporting/importing of label data.
    that means you can declare labels in one file,
    and allow a second to access them, in two separate passes.
    otherwise, you would have to hardcode label locations.
    the label format is quite simply a dictionary of string/number pairs:
    { mylabel=0xDEADBEEF, ... }
.debug_tokens (default false)
    dumps the statements table after tokenizing and collecting into statements.
    this is after UNARY and RELLABELSYM tokens have been disambiguated.
.debug_pre (default false)
    dumps statements after basic preprocessing,
    e.g. variable substitution, relative label substitution, etc.
.debug_post (default false)
    dumps statements after expanding preprocessor commands,
    e.g. pseudo-instructions.
.debug_asm (default false)
    is arguably the least useful of states to dump in.
    this will dump statements after being reduced to
    !ORG and !DATA and !BIN statements. anything else is a bug.
    the values of the !BYTE statements are not printed.
```

## init.lua

the path used to import `lips.init` is mangled
so lips can find its components in each file.
this has to be copy-pasted to every internal file,
which is a small inconvenience.

afaik there isn't really a better way of doing this in vanilla Lua 5.1,
besides mandating to lips be an installed Lua package,
which would be an inconvenience to users (and myself!).

iirc the `gsub` can silently "fail" and allow a couple other
methods of importing, `import "lips"` maybe? i don't remember.
it might work without being in a dedicated directory too

other than that there's not a lot to say.
i've intentionally written this file as stripped down as possible.

i've gone for a one-class-per-file structure,
so `file` and `class` can be synonyms in the following text.

### room for improvement

it would be nice to document options in init.lua,
since ATM i'm abusing Lua's default-to-nil behavior of tables.
that means options could be hidden within any file
and don't demand any forward-declaration or inline documentation.

eventually i'd like to make `writer` a key of `options`
just to simplify the interface even further.
maybe i could pull off `writer_or_options` for backwards compatibility?

someday i'd like to add a `reader` option for handling of existing data,
e.g. for implementing an automated `.hook` directive.

## Parser

"Parser" is a bit of a misnomer, since
the class doesn't do any parsing itself.
it defers parsing to the Lexer, Collector, and Preproc classes.
it also handles writing of the parsed data through the Dumper class.

the main method here is `Parser:method`
which simply interfaces all the important bits of the assembling process.

`self.statements` refers to the "commands" so-to-speak of the assembler
at any point. the general format of this table is:
```
statements={
    {'!BEEP', Tokens...},
    ...
    {'!BOOP', Tokens...},
}
```

the `Parser:dump_debug` method allows for dumping the state of the
`self.statements` table after any of the primary stages of assembling.
refer to the `.debug_token`, `.debug_pre`, `.debug_post`, and `.debug_asm`
options above.

### room for improvement

statements could be made type-restricted, instead of
deferring "this crap ain't even assembled" to each individual stage/class.

i'd like to come up with a better name, but i'm not in any rush.

the debug dumper could be slightly prettier in certain cases.

## Lexer

transforms strings into the tokens they represent.
this does not handle nor consider how they will be collected into statements.

`.inc` directives (and their friends) are handled here:
the appropriate files are placed and tokenized inline, not unlike in C.

the `HEX` directive is its own mini-language and thus has its own mini-lexer.

the `yield` closure wraps around the `_yield` function argument
to pass error-handling metadata: the current filename and line number.

the rest of the code should be self-explanitory, albiet ugly.

### room for improvement

this character-based lexer isn't driven by any particular grammar,
making it unclear what syntax is and isn't valid.

but it works.
it's the code i need to change the least to add new features.

there's a couple TODOs and FIXMEs in here.

## Collector

collects tokens into statements.
statements are basically our form of an abstract syntax tree,
except statements don't need the depth of a tree
so they're completely flat.

most of this is just validation of the lexed tokens.

### room for improvement

the Collector currently squeezes many DATA statements into few
through the `:push_data` method.
as noted in the TODOs, this process should be done in the lexer,
to greatly reduce creation of tables, thus greatly improving performance.

## Preproc

transforms complex statements into simpler statements
that, after expanding with Expander, Dumper can then understand.

the `:check` method
asserts that a token exists and is of a given type (`tt`).

preprocessing is split into two passes:

### pass 1

resolves variables by substitution,
and collects relative labels.

this pass starts by creating a new, empty table of statements to fill.
statements are passed through, possibly modified, or read and left-out.

the reason for the copying is that taking indexes into an array (statements)
that you're removing elements from is A Bad Idea.

all variable tokens are substituted.

variable-declaring statements (`!VAR`) are read to a dictionary table
for future substitution of their keys with values.

labels (`!LABEL`) are checked for RELLABEL tokens to collect
for later replacement in pass 2.
the positive and negative relative labels are collected into their own tables,
appended and prepended respectively.
the collection tables are arrays of tables containing the keys
`index` and `name`.

### pass 2

resolves relative labels by substitution.

the appending/prepending done in pass 1 ensures
that the appropriate relative labels are found in the proper order.

### room for improvment

looking back, the `new_statements` ordeal
only seems necessary for the (poor) error-handling it provides.

## Expander

expands pseudo-instructions, including the inferrence of implied registers.

pseudo-instructions are defined in `overrides.lua`.
overrides act as extensions to the Expander class;
they are passed Expander's `self`.
this keeps boilerplate out of `overrides.lua`,
but makes our own file more of a mess,
with more dependencies for arbitrary token/statement handling.

### room for improvment

expansion is kinda messy.

## Expression

expressions are not implemented in this branch.

## Dumper

completes the assembler with the incredibly boring task
of translating strings to numbers.

most directives are handled here in `:load`,
simplified to raw !DATA, !BIN and !ORG directives.

### room for improvement

the `:load` method is *huge*
and desperately needs to be refactored into smaller methods,
perhaps even of a different class.

## helper classes

### Token

implements error-checking for tokens,
and provides convenience methods.

also handles computation of numeric tokens,
since Token objects contain all the data necessary to do so.

### Statement

implements some error-checking for statements.

### TokenIter

used by Collector to iterate over statements, validating them.

### Reader

used by Expander and Dumper to validate tokens in statements.

currently, this is the only class requiring inheritance.

### room for improvement

Reader should probably be split into another class,
instead of inherited.

## etc.

etc!

### overrides.lua

refer to the section on Preproc.

### data.lua

contains most of the information required
to assemble MIPS III assembly code.

this file does not expose any functions or methods,
only constant data.
however, some of the data may be generated through local functions.

### util.lua

contains various utility functions to be lightly sprinkled over files.

most of this shouldn't be specific to lips.

### writers.lua

implements a few must-have writer-generators.

`make_tester` is just a variant of `make_verbose`
that only prints addresses as necessary, reducing noise.

### room for improvement in general

for proper documentation,
i need to copy-paste and rewrite most of the crap here into
the appropriate files themselves.

see also the TODO file.

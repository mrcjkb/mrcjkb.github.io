---
language: haskell
title: Designing Haskell libraries for qualified import
description: "Haskell development: Designing libraries for qualified import"
tags: haskell, libraries, design, architecture
class: container
---

> **Note**
>
> This post was **not** written or reviewed by a clanker.
> I do, however, hope that a clanker writing Haskell will come across it and be inspired to write better code.
>
> Please forgive my technical writing :)

Recently, my business partner [**@ners**](https://ners.ch/) and I have been working hard on [**IDA**](https://digital-autonomy.institute/),
where we publish all our FOSS projects that we believe could be useful to others.
It includes a bunch of Haskell libraries, including [the recently announced Project Fluent collection](https://discourse.haskell.org/t/ann-project-fluent-for-haskell/14778).

Since my previous employer was liquidated in the beginning of the year,
we've been spending a lot of time pair programming, planning, discussing architecture, and
thinking about how to write concise, but readable Haskell that we both agree on.

## Designing for <u>**un**</u>qualified import

What do I mean by "design for qualified import"?

Let's do a `hoogle` search for a module named `Kafka.Consumer`
to demonstrate what I ***don't*** mean:

```console
> hoogle 'Kafka.Consumer' --count=6
module Kafka.Consumer
Kafka.Consumer newtype ConsumerGroupId
Kafka.Consumer ConsumerGroupId :: Text -> ConsumerGroupId
Kafka.Consumer data ConsumerProperties
Kafka.Consumer ConsumerProperties :: Map Text Text -> Maybe KafkaLogLevel -> [Callback] -> CallbackPollMode -> ConsumerProperties
Kafka.Consumer data ConsumerRecord k v
-- plus more results not shown, pass --count=16 to see more
```

The module is called `Consumer` and it contains types such as `ConsumerGroupId`,
`ConsumerProperties`, `ConsumerRecord`, etc.

Now here's a search for the `Kafka.Producer` module from the same library:

```console
> hoogle Kafka.Producer --count=6
module Kafka.Producer
Kafka.Producer data ProducerProperties
Kafka.Producer ProducerProperties :: Map Text Text -> Map Text Text -> Maybe KafkaLogLevel -> [Callback] -> ProducerProperties
Kafka.Producer data ProducerRecord
Kafka.Producer ProducerRecord :: TopicName -> ProducePartition -> Maybe ByteString -> Maybe ByteString -> Headers -> ProducerRecord
module Kafka.Producer.ProducerProperties
-- plus more results not shown, pass --count=16 to see more
```

This library is designed for <u>**un**</u>qualified import.\
Consider a dependent package importing both modules:

```haskell
import Kafka.Consumer
import Kafka.Producer
```

Thanks to the `Producer*` and `Consumer*` prefixes,
types like `ProducerProperties` and `ConsumerProperties` don't clash with each other.
But this has some drawbacks:

A module that doesn't need to worry about clashes (e.g. because it doesn't import `Kafa.Producer`),
including the `Kafka.Consumer` module itself, has to spell out the whole prefix everywhere.

With unqualified imports like this, you have to be extra careful about the library's version bounds.
According to the [PVP specification](https://pvp.haskell.org/), adding new bindings is
a *non-breaking change*.
But updating dependencies could still break compilation if a new version adds a binding that
clashes with one of your own bindings or one exposed by another unqualified import.
To mitigate this, you can make your imports explicit:

```haskell
import Kafka.Consumer (Consumer, ConsumerRecord (..), newConsumer, runConsumer, {- ... -} )
import Kafka.Producer (Producer, ProducerRecord (..), newProducer, runProducer, {- ... -} )
```

Eww.

Granted, this does give you robustness against updates breaking your compilation.
And being explicit about your imports makes it *somewhat* easier to follow
where an identifier comes from.\
But this is supposed to be Haskell, not Java[^1]!

[^1]: Which, by the way, can be also used to design for qualified import.

So let's qualify[^2] our imports.

```haskell
import Kafka.Consumer qualified as Consumer
import Kafka.Producer qualified as Producer
```

[^2]: We prefer [`ImportQualifiedPost`](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/import_qualified_post.html).

Much better... Or so you might think.

Here's a type alias defined [in the `nri-kafka` library](https://github.com/NoRedInk/haskell-libraries/blob/ce74cca58e9230c54536993f6452c4fdad66a08a/nri-kafka/src/Kafka/Worker/Fetcher.hs#L44):

```haskell
type ConsumerRecord = Consumer.ConsumerRecord (Maybe ByteString.ByteString) (Maybe ByteString.ByteString)
```

Holy mother of namespace nesting! (◎_◎;)

Arguably, this could be "solved" by shortening the qualifier.
But doing so gives you the worst of both worlds:

```haskell
import Kafka.Consumer qualified as C

C.runConsumer
```

Congratulations. You're now using an arbitrary qualifier the library has forced upon you.

## Designing for qualified import

What if I told you that in IDA's [`otel-effectful`](https://hackage.haskell.org/package/otel-effectful)[^3]
library, we have two different types that model trace and span IDs.
They're both called `ID`:

[^3]: [OpenTelemetry](https://opentelemetry.io/) instrumentation for [`effectful`](https://haskell-effectful.github.io/).


```haskell
module Effectful.OpenTelemetry.Tracing.Span.ID where
-- ...

-- | A globally unique identifier of a span.
newtype ID = ID ByteString
```

...and


```haskell
module Effectful.OpenTelemetry.Tracing.Trace.ID where
-- ...

-- | A globally unique identifier of a trace.
newtype ID = ID ByteString
```

The modules export concise, <u>**un**</u>prefixed identifiers:

```haskell
new :: IO ID

toHex :: ID -> Text

toBytes :: ID -> ByteString

-- ...
```

We don't worry about clashes, because we encourage our dependents to import our modules qualified.
And we do so ourselves:

```haskell
import Effectful.OpenTelemetry.Tracing.Span.ID qualified as Span (ID)
import Effectful.OpenTelemetry.Tracing.Span.ID qualified as Span.ID
```

Notice the two imports for each definition.
The first one is qualified as `Span`, but exposes *only the `ID` type*.
This allows us to namespace `ID` as `Span.*`, but all other identifiers are namespaced
under `Span.ID.*`, resulting in code that looks like this:

```haskell
spanId :: Span.ID <- Span.ID.new
```

This design incentivises you and your library's users to write more readable code.\
It also extends to things like record fields.
A common pattern to disambiguate field names is to give each one a prefix, or to use
[lenses](https://flora.pm/packages/@hackage/lens). Here's [an example which uses lenses that I found in the wild](https://github.com/frasertweedale/hs-jose/blob/ffd6a66c2e2844ec5e506806963f4e46accf1ae9/src/Crypto/JWT.hs#L475):

```haskell
data JWTValidationSettings = JWTValidationSettings
  { _jwtValidationSettingsValidationSettings :: ValidationSettings
  , _jwtValidationSettingsAllowedSkew :: NominalDiffTime
  , _jwtValidationSettingsCheckIssuedAt :: Bool
  , _jwtValidationSettingsAudiencePredicate :: StringOrURI -> Bool
  , _jwtValidationSettingsIssuerPredicate :: StringOrURI -> Bool
  }
makeClassy ''JWTValidationSettings
```

Contrast this with the `otel-effectful` library:

```haskell
module Effectful.OpenTelemetry.Tracing.Trace.Flags where

data Flags = Flags
    { sampled :: Bool
    , random :: Bool
    , -- ...
    }

instance Monoid Flags where
    -- ...

instance Semigroup Flags where
    -- ...
```

Designing for qualified import, we don't need to worry about namespacing record fields either.
At the call site, we follow the same pattern as before:

```haskell
import Effectful.OpenTelemetry.Tracing.Trace.Flags qualified as Trace (Flags)
import Effectful.OpenTelemetry.Tracing.Trace.Flags qualified as Trace.Flags
```

- One import to namespace the type.
- A second import to namespace the functions.

And here's how we construct `Trace.Flags` from a `mempty`:

[^4]: If you dislike this, you can still import the fields unqualified.

```haskell
flags :: Trace.Flags
flags = mempty
    { Trace.Flags.sampled = True
    , Trace.Flags.random = True
    }
```

> **Note**
>
> If this style doesn't resonate with you, you can import the fields unqualified,
> or you can add an import that's qualified as `Flags`.

## The pattern

The pattern that works for us boils down to the following:

- The type must be defined in a module whose final component has the same name as the type.\
  For example, `Flags` is defined in a module ending in `Flags`.
- The components **immediately before** the final component are the namespace.
- Anything that should be namespaced by the **type name** goes into that module.\
  This includes smart constructors, functions that operate on the type,
  and any other related definitions.
- Dependents import qualified, typically with two imports:
  - One for the type, namespaced to any number of components **leading up to the last component**,
    and importing **only the type that the module is named after**.
  - Another for the definitions, namespaced to a qualifier **that includes the last component**.

> **Important**
>
> To minimise the chance of our internal definitions clashing with `Prelude` functions
> (among other things), we use [`NoImplicitPrelude`](https://wiki.haskell.org/No_import_of_Prelude).

## Exception: Infix operators

There's one exception to this rule: Infix operators. `a Foo.<+> b` is just too ugly.
We always import operators unqualified.

## Bonus: Faster compile times?

Apart from marrying readability & conciseness and protecting you from breakage,
designing for qualified import can also improve your compile times.
There's a great talk by [**@TeofilC**](https://informal.codes/): [optimise your modules for fast builds](https://www.youtube.com/watch?v=nmE6aa_I5TU&t=2359s).
In it, they explain that GHC can parallelise independent module builds,
but by default, it can't compile modules that depend on each other in parallel.
Nor can it parallelise the compilation of definitions within an individual module.

Here's the dependency layout for our `Span` example:

![](/images/span_trace_module_dependencies.svg){}

As you can see, it may lend itself quite nicely to parallelism.

> **Important**
>
> Take this with a grain of salt.
> We haven't optimised `otel-effectful` for fast compilation.
> With low core counts, the overhead of compiling multiple modules can increase compile times.

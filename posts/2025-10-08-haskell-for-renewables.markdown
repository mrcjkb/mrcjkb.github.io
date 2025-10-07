---
title: Why Haskell is the perfect fit for renewable energy tech
tags: haskell, cleantech, renewables, energy, climatetech
class: container
---

My educational background isn't that of your typical software engineer.
I didn't study computer science;
instead, I completed a bachelor's and master's in Renewable Energy Systems at HTW Berlin.
Recently, as I explored the clean tech job market in Europe, I noticed a pattern:
most companies rely on Java or .NET, while Haskell seems reserved for blockchain and finance.

Yet, through a twist of fate, I became a professional Haskell developer in February 2022,
and discovered that this functional programming language is an unexpectedly perfect fit
for renewable energy technology.
Let me share why.

## Don't panic about thermodynamics

During my university years, thermodynamics and energy process engineering
were notorious among students.
The courses were packed with daunting formulas - far too many to memorize,
and far too complex to reference in the heat of an exam.

But one piece of advice from our professor changed everything for me.
She encouraged us to truly understand the international system of units (SI),
especially by practicing how to juggle and decompose them into their seven base units[^1].

[^1]: second, metre, kilogram, ampere, kelvin, mole and candela.

For instance, instead of memorizing the formula for power, I’d break down the unit Watt (power)
into its base components: kilogram, metre, and second (`W = kg · m² / s³`).
With this trick, I could solve problems by letting the units guide me,
rather than relying on rote memorization.
I minimized what I needed to write down and found myself finishing exams with plenty
of time to spare, and scoring perfectly every time.

What I didn't realise at the time, was that this mindset of letting structure and units
guide my reasoning was strikingly similar to type-driven development,
a concept I’d only discover years later.

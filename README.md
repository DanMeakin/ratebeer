# RateBeer [![Build Status](https://travis-ci.org/DanMeakin/ratebeer.svg?branch=master)](https://travis-ci.org/DanMeakin/ratebeer) [![Code Climate](https://codeclimate.com/github/DanMeakin/ratebeer/badges/gpa.svg)](https://codeclimate.com/github/DanMeakin/ratebeer) [![Test Coverage](https://codeclimate.com/github/DanMeakin/ratebeer/badges/coverage.svg)](https://codeclimate.com/github/DanMeakin/ratebeer/coverage)
A Ruby scraper for RateBeer.com

## Introduction

RateBeer is a scraper for RateBeer.com. At present, the library can be used to access data on beers, breweries, styles, countries and regions which are listed at RateBeer.com.

This library has been influenced by the [great Python RateBeer scraper by ajila](https://github.com/alilja/ratebeer).

## Usage

The library provides access to a REPL which can be used to query RateBeer.com for the information accessible through this library. This is found at `/bin/ratebeer`. Alternatively, you can `require 'lib/ratebeer'` to use the library in your code.

A number of classes are provided by the library:-

  * Beer;
  * Brewery;
  * Style;
  * Country;
  * Region; and
  * Search.

The first five classes represent a details of that particular thing as provided by RateBeer.com. Each of these is lazy and will only retrieve data from the site when that data is requested (and where that data is not already present within the object - it is possible to pass known data to the constructor).

The search class represents a search conducted at the site, and will return beers and breweries which are matched.

## Example

To conduct a search:-

```ruby
> s = RateBeer::Search.new("punk ipa")
> s.beers
 => [#<RateBeer::Beer #98939 - Berwick Atomic Punk IPA>,
     #<RateBeer::Beer #72423 - BrewDog Punk IPA  (6%)>,
     #<RateBeer::Beer #135361 - BrewDog Punk IPA (5.6%)>,
     #<RateBeer::Beer #81110 - BrewDog Punk IPA Speyside>,
     #<RateBeer::Beer #193916 - Flying Dog / Brewdog / Push Brewing Punk Bitch IPA>,
     #<RateBeer::Beer #132795 - Founders Hop Spit Punk Rock IPA>,
     #<RateBeer::Beer #309419 - Fuggles & Warlock Draft Punk Rye IPA>,
     #<RateBeer::Beer #218936 - Pateros Creek Punk Rock IPA>,
     #<RateBeer::Beer #191045 - Push Brewing Knob Creek Punk Bitch IPA>,
     #<RateBeer::Beer #100638 - Berwick Atomic Punk IPL (India Pale Lager)>,
     #<RateBeer::Beer #209258 - Dieselpunk India Pale Ale>]
> s.breweries
 => nil
> s.query = "brewdog"
> s.breweries
 => [#<RateBeer::Brewery #8534 - BrewDog>]
```

To use a beer instance, you can obtain one from a search or create one from a known beer ID:-

```ruby
> b = RateBeer::Beer.new(72423)
> b.name
 => "BrewDog Punk IPA (6%)"
> b.abv
 => 6.0
> b.brewery
 => #<RateBeer::Brewery #8534 - BrewDog>
```

Accessible data keys can be found in the .data_keys method in each class.

---
layout: post
title: OXID and Symfony Part 2&#58; DependencyInjection
---

Modern PHP application has lots of objects which are responsible for various things like email sending or data retrieval from database. Chances are great that you may want to have objects inside another one, especially if you follow [Single Responsibility Principle](https://en.wikipedia.org/wiki/Single_responsibility_principle). This part of OXID and Symfony post series will focus on explaining why [Dependency Injection](https://en.wikipedia.org/wiki/Dependency_injection) and showing how to have [Symfony DependencyInjection](http://symfony.com/doc/current/components/dependency_injection/introduction.html) component in OXID eShop.

I believe learning by example is the best way to learn, so lets discuss a case for WeatherService which:

* Is able to retrieve Weather object on passing a Location object;
* Uses HTTP Client for fetching weather from weather provider;
* Has a parser that transforms HTTP response into Weather object.

---
layout: post
title: OXID and Symfony Part 3&#58; HttpKernel
---

[Symfony HttpKernel][1] component provides us with tools for handling HTTP requests and
returning a responses. But we will stick to default OXID eShop HTTP requests processing as
it is really challenging to do without loosing backwards compatibility. However, Symfony
HttpKernel component is closely associated with Symfony Bundle term.

Often Symfony Bundle is directly associated with full Symfony framework, but it is not
exactly true. Symfony Bundle in most cases is used as a package in which we register
Symfony DependencyInjection container extension. We want to be able to have Symfony
Bundles in our OXID eShop project so we could use packages that Symfony community has
created.

<!--more-->

To be continued...

[1]: http://symfony.com/doc/current/components/http_kernel/introduction.html

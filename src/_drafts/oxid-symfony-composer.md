---
layout: post
title: OXID and Symfony Part 1&#58; Composer
---

Everyone who has been developing e-commerce projects with OXID eShop knows the routine when they have to integrate third-party libraries within their modules. It's registering all files in module metadata or worse - requiring them directly. It has been always the case in PHP world because every framework had their own autoloading algorithms until [PSR-0][PSR-0] and later [PSR-4][PSR-4] came out.

OXID eShop still does not have a support for PSR-4 way of autoloading. In this part of OXID and Symfony series we are looking on the ways of having PSR-0 and PSR-4 support in OXID eShop without breaking backwards compatibility.

<!--more-->

## Symfony ClassLoader

Various organizations dedicate their time to solve lower level problems such as autoloading or logging. Symfony organization is a famous and time proven maintainer of that type of components. Lets try to implement Symfony ClassLoader into OXID.

Symfony ClassLoader provides tools to autoload your classes. Whenever you reference a class that hasn't been loaded yet, PHP uses autoloading mechanism.[^fn-symfony_classloader_intro] Symfony ClassLoader has three ways of autoloading:

* [The PSR-0 Class Loader](http://symfony.com/doc/current/components/class_loader/class_loader.html): loads classes that follow the [PSR-0][PSR-0] class naming standard;
* [The PSR-4 Class Loader](http://symfony.com/doc/current/components/class_loader/psr4_class_loader.html): loads classes that follow the [PSR-4][PSR-4] class naming standard;
* [MapClassLoader](http://symfony.com/doc/current/components/class_loader/map_class_loader.html): loads classes using a static map from class name to file path.

### Symfony ClassLoader in OXID eShop

The first thing we need to stop doing is storing all source files under document root. We are now giving ourselves a benefit of not writing custom rewriting rules for every directory or file we have. So our project directory tree would look like that:

```
|_ ...
|_ web/
|  |_ ...
|  |_ bootstrap.php
|  |_ ...
|
|_ vendor/
|  |_ Symfony/
|  |  |_ ...
|  |_ ...
|  |_ autoload.php
|
|_ ...
```

An overview of what each of these does:

| Directory/File | Description |
| -------------- | ----------- |
| `web/` | A document root which also contains the whole OXID eShop. |
| `web/bootstrap.php` | OXID file which is responsible for bootstrapping the whole shop framework. |
| `vendor/` | A directory where we store all vendor packages. |
| `vendor/autoload.php` | A file which is responsible for registering autoloader. |

Create `vendor/autoload.php` which registers an autoloader:

{% highlight php %}
<?php
// file: vendor/autoload.php

require_once __DIR__.'/Symfony/Component/ClassLoader/ClassLoader.php';

use Symfony\Component\ClassLoader\ClassLoader;

$loader = new ClassLoader();

// Enable search though include_path
$loader->setUseIncludePath(true);

// Registering few PSR-0 rules
$loader->addPrefixes(array( 
    'Symfony' => __DIR__.'/symfony/symfony/src', 
    'Monolog' => __DIR__.'/monolog/monolog/src', 
));

// Register class cloader
$loader->register();
{% endhighlight %}

[PSR-0]: http://www.php-fig.org/psr/psr-0/
[PSR-4]: http://www.php-fig.org/psr/psr-4/
[^fn-symfony_classloader_intro]: [Symfony ClassLoader Introduction](http://symfony.com/doc/current/components/class_loader/introduction.html)

---
layout: post
title: OXID and Symfony Part 1&#58; Composer
---

Everyone who has been developing e-commerce projects with OXID eShop knows the routine when they have to integrate third-party libraries within their modules. It's registering all files in module metadata or worse - requiring them directly. It has been always the case in PHP world because every framework had their own autoloading algorithms until [PSR-0][PSR-0] and later [PSR-4][PSR-4] came out.

OXID eShop still does not have a support for PSR-4 way of autoloading. In this part of OXID and Symfony series we are looking on the ways of having PSR-0 and PSR-4 support in OXID eShop without breaking backwards compatibility.

<!--more-->

## Symfony ClassLoader

Various organizations dedicate their time to solve problems such as autoloading or logging. Symfony organization is a famous and time proven maintainer of that type of components. Lets try to implement Symfony ClassLoader into OXID.

Symfony ClassLoader provides tools to autoload your classes. Whenever you reference a class that hasn't been loaded yet, PHP uses autoloading mechanism.[^fn-symfony_classloader_intro] Symfony ClassLoader has three ways of autoloading:

* [The PSR-0 Class Loader](http://symfony.com/doc/current/components/class_loader/class_loader.html): loads classes that follow the [PSR-0][PSR-0] class naming standard;
* [The PSR-4 Class Loader](http://symfony.com/doc/current/components/class_loader/psr4_class_loader.html): loads classes that follow the [PSR-4][PSR-4] class naming standard;
* [MapClassLoader](http://symfony.com/doc/current/components/class_loader/map_class_loader.html): loads classes using a static map from class name to file path.

### Symfony ClassLoader in OXID eShop

The first thing we need to do is stop storing all source files under document root. We are now giving ourselves a benefit of not writing custom rewriting rules for every directory or file we have. So our project directory tree would look like that:

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

require_once __DIR__.'/Symfony/Component/ClassLoader/Psr4ClassLoader.php';

use Symfony\Component\ClassLoader\Psr4ClassLoader;

$loader = new Psr4ClassLoader();

// Register packages following PSR-4
$loader->addPrefix('Symfony\\Component\\Yaml\\', __DIR__.'/Symfony/Component/Yaml');

// Register autoloader
$loader->register();

return $loader;
{% endhighlight %}

PHP supports multiple autoloading functions so we can have both old and new autoloading functions and not loose backwards compatibility.[^fn-php_spl_autoload_register] OXID eShop doesn't know about `autoload.php` file that we have recently created. To make shop aware of new autoloading we have to register it in `bootstrap.php`:

{% highlight php %}
<?php
// file: web/bootstrap.php

// ...

// Register Symfony ClassLoader autoloader
require_once __DIR__ . '/../vendor/autoload.php';

// custom functions file
require_once OX_BASE_PATH . 'modules/functions.php';

// ...
{% endhighlight %}

Now we have a full support for PSR-0 and PSR-4 in OXID eShop. Usage of third-party libraries is now much simplier because we do not need to adapt them to work with OXID autoloader. We put libraries in vendor directory and register them in `autoload.php`.

## Composer

To be written

[PSR-0]: http://www.php-fig.org/psr/psr-0/
[PSR-4]: http://www.php-fig.org/psr/psr-4/
[^fn-symfony_classloader_intro]: [Symfony ClassLoader Introduction](http://symfony.com/doc/current/components/class_loader/introduction.html)
[^fn-php_spl_autoload_register]: [PHP Manual: spl_autoload_register](http://php.net/manual/en/function.spl-autoload-register.php)

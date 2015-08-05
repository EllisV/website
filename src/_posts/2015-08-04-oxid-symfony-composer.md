---
layout: post
title: OXID and Symfony Part 1&#58; Composer
---

Everyone who has been developing e-commerce projects with OXID eShop knows the routine when they have to integrate third-party libraries within their modules. It's registering all files in module metadata or worse - requiring them directly. It has been always the case in PHP world because every framework had their own autoloading algorithms until [PSR-0][PSR-0] and later [PSR-4][PSR-4] came out.

OXID eShop still does not have a support for PSR-4 way of autoloading. In this part of OXID and Symfony series we are looking on the ways of having PSR-0 and PSR-4 support in OXID eShop without breaking backwards compatibility.

<!--more-->

## Symfony ClassLoader

Various organizations dedicate their time to solve problems such as autoloading or logging. Symfony organization is a famous and time proven maintainer of that type of components. Lets try to implement Symfony ClassLoader into OXID.

> **Symfony ClassLoader** provides tools to autoload your classes. Whenever you reference a class that hasn't been loaded yet, PHP uses autoloading mechanism.

Symfony ClassLoader has three ways of autoloading:

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

PHP supports multiple autoloading functions so we can have both old and new autoloading functions and not loose backwards compatibility. OXID eShop doesn't know about `autoload.php` file that we have recently created. To make shop aware of new autoloading we have to register it in `bootstrap.php`:

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

Now we have a full support for PSR-0 and PSR-4 in OXID eShop. Usage of third-party libraries is now much simpler because we do not need to adapt them to work with OXID autoloader. We put libraries in vendor directory and register them in `autoload.php`.

## Composer

To be able to register third-party library to Symfony ClassLoader you must know what kind of autoloading it uses. Fact that we need to register libraries in `autoload.php` raises the question if this can be automated.

> **Composer** is a tool for dependency management in PHP. It allows you to declare the libraries your project depends on and it will manage (install/update) them for you.

Problems that Composer solves:

* Downloads dependencies of your project;
* Those dependencies have other dependencies which will be downloaded too;
* Solves which versions of libraries to download;
* **Generates an autoloader**.

### Composer in OXID eShop

Get rid of everything you done within Symfony ClassLoader chapter except for having the whole OXID eShop in `web` directory. Now we are seeking for having following project structure:

```
|_ ...
|_ web/
|  |_ ...
|  |_ bootstrap.php
|  |_ ...
|
|_ vendor/
|  |_ ...
|  |_ autoload.php
|
|_ ...
|_ composer.json
|_ composer.lock
|_ ...
```

An overview of what each of these does:

| Directory/File | Description |
| -------------- | ----------- |
| `web/` | A document root which also contains the whole OXID eShop. |
| `web/bootstrap.php` | OXID file which is responsible for bootstrapping the whole shop framework. |
| `vendor/` | A directory which is controlled by Composer. It stores all vendor packages in there. You want this directory excluded from your version control system. |
| `vendor/autoload.php` | Composer generated file which is responsible for registering autoloader. |
| `composer.json` | A file which describes the dependencies of your project and may contain other metadata as well. |
| `composer.lock` | Composer generated file to lock versions of dependencies. This is generated on first `composer install` and on every `composer update`. |

To be able to use Composer generated autoloading we need to register it in `bootstrap.php`:

{% highlight php %}
<?php
// file: web/bootstrap.php

// ...

// Register Composer autoloader
require_once __DIR__ . '/../vendor/autoload.php';

// custom functions file
require_once OX_BASE_PATH . 'modules/functions.php';

// ...
{% endhighlight %}

Lets assume we want to use monolog in our project. So our `composer.json` would like like so:

{% highlight json %}
{
    "require": {
        "monolog/monolog": "~1.13.1"
    }
}
{% endhighlight %}

After running `composer install` or `composer update` (you have to have Composer installled in your system, read [official guide](https://getcomposer.org/doc/00-intro.md#globally) on how to do that) it downloads all dependencies in `vendor` directory (by default) and generates `autoload.php` which is responsible for registering an autoloader.

Now you are able to use any class/interface/trait which is autoloaded by Composer in your OXID project.

### Why did I bother writing about Symfony ClassLoader?

Symfony ClassLoader chapter was written for learning purpose to show what problem Composer is designed to solve.

## Integrating Symfony Debug

Chittity chattity, lets see the real benefit of that and integrate Symfony Debug component as an example. We can have all components developed outside the OXID and write a module as a bridge. We will have a symfony module to bridge various Symfony components (currently only Symfony Debug in this part). Install Symfony Debug with composer by running `composer require symfony/debug` and start writing module `metadata.php`:

{% highlight php %}
<?php
// file: web/modules/eli/symfony/metadata.php

/**
 * Metadata version
 */
$sMetadataVersion = '1.2';

/**
 * Module information
 */
$aModule = array(
    'id'          => 'elisymfony',
    'title'       => 'Symfony Bridge',
    'description' => 'Provides integration for OXID with various Symfony components',
    'thumbnail'   => 'logo.png',
    'version'     => '0.0.1-DEV',
    'author'      => 'Eligijus Vitkauskas',
    'url'         => 'https://github.com/EllisV',
    'email'       => 'eligijusvitkauskas@gmail.com',
    'extend'      => array(
        'oxshopcontrol' => 'eli/symfony/core/elisymfonyoxshopcontrol'
    )
);
{% endhighlight %}

We do not want to see debug outputs in production shop. Normally Symfony handles this by conditioning if Kernel is in develpment environment but we do yet have Symfony HttpKernel integrated. So lets rely on OXID check if shop runs in productive mode. Our `oxShopControl` extension which we specify in `elisymfonyoxshopcontrol.php` would like so:

{% highlight php %}
<?php
// file: web/modules/eli/symfony/core/elisymfonyoxshopcontrol.php

use Symfony\Component\Debug;

/**
 * Extension of oxShopControl OXID core class
 *
 * @see oxShopControl
 */
class eliSymfonyOxShopControl extends eliSymfonyOxShopControl_parent
{
    /**
     * Set default exception handler
     *
     * If shop is not in productive mode than we register
     * Symfony Debug component's Exception and Error handlers
     * and do not call parent method
     *
     * Otherwise we stick to default OXID exception handler
     */
    protected function _setDefaultExceptionHandler()
    {
        if (oxRegistry::getConfig()->isProductiveMode()) {
            parent::_setDefaultExceptionHandler();
            return;
        }

        // It would be cool to only use Debug::enable() in here
        // but it also registers a DebugClassLoader which will
        // always throw an error because OXID does not care about
        // case when refering to objects

        ini_set('display_errors', 0);
        Debug\ExceptionHandler::register();
        $handler = Debug\ErrorHandler::register();
        $handler->throwAt(0, true);
    }

    /**
     * Handle system exception.
     *
     * If shop is not in productive mode then we rethrow the exception.
     * Otherwise we call default OXID behavior
     *
     * @param oxException $oEx
     *
     * @throws oxException
     */
    protected function _handleSystemException($oEx)
    {
        if (oxRegistry::getConfig()->isProductiveMode()) {
            parent::_handleSystemException($oEx);
            return;
        }

        throw $oEx;
    }

    /**
     * Handle cookie exception.
     *
     * If shop is not in productive mode then we rethrow the exception.
     * Otherwise we call default OXID behavior
     *
     * @param oxException $oEx
     *
     * @throws oxException
     */
    protected function _handleCookieException($oEx)
    {
        if (oxRegistry::getConfig()->isProductiveMode()) {
            parent::_handleCookieException($oEx);
            return;
        }

        throw $oEx;
    }

    /**
     * Handle database connection exception.
     *
     * If shop is not in productive mode then we rethrow the exception.
     * Otherwise we call default OXID behavior
     *
     * @param oxException $oEx
     *
     * @throws oxException
     */
    protected function _handleDbConnectionException($oEx)
    {
        if (oxRegistry::getConfig()->isProductiveMode()) {
            parent::_handleDbConnectionException($oEx);
            return;
        }

        throw $oEx;
    }

    /**
     * Handle base exception.
     *
     * If shop is not in productive mode then we rethrow the exception.
     * Otherwise we call default OXID behavior
     *
     * @param oxException $oEx
     *
     * @throws oxException
     */
    protected function _handleBaseException($oEx)
    {
        if (oxRegistry::getConfig()->isProductiveMode()) {
            parent::_handleBaseException($oEx);
            return;
        }

        throw $oEx;
    }
}
{% endhighlight %}

That is it! You now have fully (except for DebugClassLoader as OXID does not respect case sensitivity) integrated Symfony Debug component without writing much code. Writing all your code outside OXID framework gives you an ability to reuse it in other projects and this makes your OXID projects more lean and maintainable as you only need modules as bridges.

## OXID and Symfony post series

This is a preparation post for having Symfony Components and Bundles. More will be covered in Part 2 and Part 3 of this post series.

## Further reading

* [Composer: What & Why](http://nelm.io/blog/2011/12/composer-part-1-what-why/)
* [Composer Introduction](https://getcomposer.org/doc/00-intro.md)
* [The composer.json Schema](https://getcomposer.org/doc/04-schema.md)
* [Composer: It's All About the Lock File](https://blog.engineyard.com/2014/composer-its-all-about-the-lock-file)

[PSR-0]: http://www.php-fig.org/psr/psr-0/
[PSR-4]: http://www.php-fig.org/psr/psr-4/

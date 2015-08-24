---
layout: post
title: OXID and Symfony Part 3&#58; HttpKernel
category: oxid
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

We install Symfony HttpKernel via Composer. Our project structure looks like so:

```
|_ app/
|  |_ cache/
|  |  |_ ...
|  |
|  |_ config/
|  |  |_ config.yml
|  |  |_ config_dev.yml
|  |  |_ config_prod.yml
|  |
|  |_ logs/
|  |  |_ ...
|  |
|  |_ AppKernel.php
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
|_ composer.json
|_ ...
```

`AppKernel.php` is a file responsible for registering Symfony Bundles and loading configuration.
This is an example of `AppKernel.php` file:

{% highlight php %}
<?php

use Symfony\Component\HttpKernel\Kernel;
use Symfony\Component\Config\Loader\LoaderInterface;

class AppKernel extends Kernel
{
    public function registerBundles()
    {
        return [
            new Ellis\Oxid\Bundle\FrameworkBundle\FrameworkBundle,
            new Symfony\Bundle\MonologBundle\MonologBundle
        ];
    }

    public function registerContainerConfiguration(LoaderInterface $loader)
    {
        $loader->load(__DIR__.'/config/config_'.$this->getEnvironment().'.yml');
    }
}
{% endhighlight %}

Building DependencyInjection Container is a responsibility of HttpKernel component. But we need
to adjust OXID to be able to use this container.

There are more than one way do this. Please read [Part 2]({% post_url 2015-08-18-oxid-symfony-dependencyinjection %})
of this blog post series for explanation on why we chose to go this way. So we create `kernelbootstrap.php` file:

{% highlight php %}
<?php
// file: web/kernelbootstrap.php

if (!class_exists('\Composer\Autoload\ClassLoader')) {
    require_once __DIR__.'/../vendor/autoload.php';
}

global $kernel;

if ($kernel === null) {
    require_once __DIR__.'/../app/AppKernel.php';

    $env = getenv('SYMFONY_ENV') ?: 'prod';
    $debug = getenv('SYMFONY_DEBUG') !== '0' && $env !== 'prod';

    $kernel = new AppKernel($env, $debug);
    $kernel->boot();
}
{% endhighlight %}

And bootstrap it in `bootstrap.php`:

{% highlight php %}
<?php
// file: web/bootstrap.php

// ...

// load composer autoloader
require_once __DIR__ . '/../vendor/autoload.php';

// initialize kernel
require_once __DIR__ . '/kernelbootstrap.php';

// ...
{% endhighlight %}

Ok. Now we have something to add to our Symfony module. We will create `oxUtilsObject` extension (or edit if you have
not deleted it from Part 2). So first register this in metadata:

{% highlight php %}
<?php
// file: web/modules/eli/symfony/metadata.php

// ...

$aModule = array(
    // ...
    extend => array(
        // ...
        'oxutilsobject' => 'eli/symfony/core/elisymfonyoxutilsobject',
        // ...
    ),
    // ...
);
{% endhighlight %}

And the extension:

{% highlight php %}
<?php
// file: web/modules/eli/symfony/core/elisymfonyoxutilsobject.php

use Symfony\Component\DependencyInjection\ContainerAwareInterface;

/**
 * Extension of oxUtilsObject OXID core class
 *
 * @see oxUtilsObject
 */
class eliSymfonyOxUtilsObject extends eliSymfonyOxUtilsObject_parent
{
    /**
     * Injects DependencyInjection container on ContainerAwareInterface
     * instances.
     *
     * oxNew() uses this method to build objects, so we are basically
     * providing a way of having a container on all OXID objects
     * which are ContainerAwareInterface instances.
     */
    protected function _getObject($sClassName, $iArgCnt, $aParams)
    {
        $oObject = parent::_getObject($sClassName, $iArgCnt, $aParams);

        if ($oObject instanceof ContainerAwareInterface) {
            global $kernel;
            $oObject->setContainer($kernel->getContainer());
        }

        return $oObject;
    }
}
{% endhighlight %}

You are now able to register Symfony Bundles and use them in your OXID project. In example below we have registered
MonologBundle, so we can get this logger by requesting `$container->get('logger')`.

There is a dedicated open source project which contains this implemention. You can see the source at
[github.com/EllisV/oxid-standard](https://github.com/EllisV/oxid-standard).

By the way, I am really sorry that I was not really descriptive in this blog post. I wanted to finish this post
before I had a talk on knowledge exchange between OXID Core and OXID Professional Services teams.


[1]: http://symfony.com/doc/current/components/http_kernel/introduction.html

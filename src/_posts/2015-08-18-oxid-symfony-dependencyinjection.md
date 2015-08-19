---
layout: post
title: OXID and Symfony Part 2&#58; DependencyInjection
---

Modern PHP application has lots of objects which are responsible for various things like email sending or data retrieval from database. Chances are great that you may want to have objects inside inside other objects, especially if you follow [Single Responsibility Principle](https://en.wikipedia.org/wiki/Single_responsibility_principle). This part of OXID and Symfony post series will focus on explaining why to use [Dependency Injection](https://en.wikipedia.org/wiki/Dependency_injection) and showing how to have [Symfony DependencyInjection](http://symfony.com/doc/current/components/dependency_injection/introduction.html) component in OXID eShop.

I believe learning by example is the best way to learn, so lets discuss a case for WeatherService which:

* Is able to retrieve Weather object on passing a Location object;
* Uses HTTP Client for fetching weather from weather provider;
* Has a parser that transforms HTTP response into Weather object.

<!--more-->

Our concrete `YahooWeatherService` would look like so:

{% highlight php %}
<?php

class YahooWeatherService implements WeatherServiceInterface
{
    protected $httpClient;

    protected $parser;

    public function __construct()
    {
        $this->httpClient = new HttpClient;
        $this->parser = new YahooDataParser;
    }

    public function getWeatherForLocation(Location $location)
    {
        $data = $this->httpClient->get(static::URL, [
            'longitude' => $location->getLongitude(),
            'latitude'  => $location->getLatitude()
        ]);

        return $this->parser->parseWeather($data);
    }
}

$weatherService = new YahooWeatherService;
{% endhighlight %}


DO NOT rush to facepalm just yet. First we are going to do this a wrong way so we would know a reason why it shouldn't be that way.

It is easy to create objects if you do it like in the example above but it is really hard to configure objects that this service depends on. What if `HttpClient` and `YahooDataParser` requires some parameters while constructing them. Everything would be hard coded into `YahooWeatherService` class. Also, every new instance of `YahooWeatherService` would create new instances for classes that it depends on (yes, `YahooWeatherService` is not that good of an example for this point, but `Product` class would be). We could solve this problem by using [registries](https://github.com/domnikl/DesignPatternsPHP/tree/master/Structural/Registry):

{% highlight php %}
<?php

class YahooWeatherService implements WeatherServiceInterface
{
    // ...

    public function __construct()
    {
        $this->httpClient = Registry::get('http_client');
        $this->parser = Registry::get('yahoo_data_parser');
    }

    // ...
}
{% endhighlight %}

Now we do not have to care about configuration of `HttpClient` or `YahooDataParser`. Also we can easily switch concrete implementations of `HttpClient` as long as it has same interface. But still `YahooWeatherService` depends on a whole registry so your components can not be shared between projects that do not have this registry and it is really difficult to unit-test this class.

Lets go back to `YahooWeatherService` class. Instead of constructing object dependencies inside the object we inject them as construct parameters.

{% highlight php %}
<?php

class YahooWeatherService implements WeatherServiceInterface
{
    // ...

    public function __construct(HttpClientInterface $httpClient, YahooDataParser $parser)
    {
        $this->httpClient = $httpClient;
        $this->parser = $parser;
    }

    // ...
}

$httpClient = new HttpClient;
$parser = new YahooDataParser;

$weatherService = new YahooWeatherService($httpClient, $parser);
{% endhighlight %}

Now this weather service depends only on necessary classes or interfaces instead of depending on the whole registry. Also unit-testing became easier because we can pass mocks while constructing objects. But creating a new object became more complex, therefor we need object container.

## Object container

Object container is an object which is aware of other objects and their dependencies which are created on demand. Other objects must not know that they are being controlled by object container. Lets create very primitive object container:

{% highlight php %}
<?php

class Container
{
    protected $services = [];

    public function setService($key, Closure $service)
    {
        $this->services[$key] = $service;
    }

    public function getService($key)
    {
        return $this->services[$key]($this);
    }
}
{% endhighlight %}

Maybe you have noticed that `setService` expects a function as a second parameter but not an actual object. This is that way because we want to create object only on demand. There is an example of usage:

{% highlight php startinline=true %}
$container = new Container;

$container->setService('http_client', function ($container) {
    static $httpClient;
    if (null === $httpClient) {
        $parser = new HttpClient;
    }
    return $httpClient;
});

$container->setService('yahoo_weather_parser', function ($container) {
    static $parser;
    if (null === $parser) {
        $parser = new YahooWeatherParser;
    }
    return $parser;
});

$container->setService('yahoo_weather_service', function ($container) {
    static $weatherService;

    if (null !== $weatherService) {
        return $weatherService;
    }

    $httpClient = $container->getService('http_client');
    $parser = $container->getService('yahoo_weather_parser');

    return new YahooWeatherService($httpClient, $parser);
});

$weatherServce = $container->getService('yahoo_weather_service');
{% endhighlight %}

Now we can easily get objects which are in object container without caring about dependencies. Code becomes more maintainable because we have only the one place where we write a recipe how those objects are dependent on each other.

## Symfony DependencyInjection Component

As we have mentioned in the first part of this post series, there are dedicated projects which tackles specific problems and helps us not to reinvent the wheel. We have described a very simple usage of object container above but in most cases we want more from our object container, e.g. pass and use parameters or create object container from configuration file.

> Symfony DependencyInjection component allows you to standardize and centralize the way objects are constructed in your application.

Or to put this in other words: Symfony DependencyInjection provides us with tools to create object container. We install this component via Composer (if you do not have Composer in your project read [Part 1]({% post_url 2015-08-04-oxid-symfony-composer %}) of this post series) by requiring `symfony/dependency-injection`. Example usage of Symfony DependencyInjection:

{% highlight php startinline=true %}
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\DependencyInjection\Reference;

$container = new ContainerBuilder();

$container->register('http_client', 'HttpClient');
$container->register('yahoo_weather_parser', 'YahooWeatherParser');

$container
    ->register('yahoo_weather_service', 'YahooWeatherService')
    ->addArgument(new Reference('http_client'))
    ->addArgument(new Reference('yahoo_weather_parser'));

$weatherService = $container->get('yahoo_weather_service');
{% endhighlight %}

Now we can simply not worry about technical implementation of object container on your own. As we have a huge community doing maintenance for us.

### Container From Configuration File

We can use configuration files instead of describing object relations in PHP code. It is recommended to describe object relations in configuration files even for small applications as it is more readable. To be able to achieve that we must install Symfony Config component and Symfony Yaml if you want your configration to be in yaml format. Example code:

{% highlight php startinline=true %}
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\Config\FileLocator;
use Symfony\Component\DependencyInjection\Loader\YamlFileLoader;

$container = new ContainerBuilder();
$loader = new YamlFileLoader($container, new FileLocator(__DIR__));
$loader->load('services.yml');
{% endhighlight %}

And configuration file:

{% highlight yaml %}
services:
  http_client:
    class: HttpClient

  yahoo_weather_parser:
    class: YahooWeatherParser

  yahoo_weather_service:
    class: YahooWeatherService
    arguments: ['@http_client', '@yahoo_weather_parser']
{% endhighlight %}

We can have lots of configuration files. This gives us an ability to group them.

### Container Compilation and Extensions

Symfony DependencyInjection component allows us to compile object container. There are various of reasons why we want to do this, such as: better performance or checking for potential errors.

Object container can be compiled by calling `compile` method on `ContainerBuilder` object.

If we are compiling our container we have an ability to have extensions. The main purpose of extension is to register new services. Extensions gives us an ability to have modular application.

## Symfony DependencyInjection in OXID

Symfony DependencyInjection component has way more capabilities than we have reviewed so far. We only did brief introduction to make you understand why and how to use it. Read more about Symfony DependencyInjection component at [official website](http://symfony.com/doc/current/components/dependency_injection/introduction.html).

Spoiler alert! We will end up not using an implementation which is described below. Container building is a responsibility of HttpKernel component. But it is still good to read an implementation to get the idea why you may want to use HttpKernel.

We want to have some sort of a kernel class where we will register dependency injection container extensions and compiler passes. Lets start from top to bottom. Create `app` directory. It will have main configuration files and `ContainerKernel.php` file. Directory tree:

```
|_ app/
|  |_ config/
|  |  |_ config.yml
|  |
|  |_ ContainerKernel.php
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

So our goal for `ContainerKernel.php` is that we could register extensions like so:

{% highlight php %}
<?php

use Ellis\Oxid\Bridge\DependencyInjection\ContainerKernel as BaseContainerKernel;

class ContainerKernel extends BaseContainerKernel
{
    protected function registerExtensions()
    {
        return [
            new ExtensionOne,
            new ExtensionTwo
        ];
    }

    protected function registerCompilerPasses()
    {
        return [
            new CompilerPassOne
        ];
    }

    /**
     * {@inheritdoc}
     */
    protected function getWebDir()
    {
        return __DIR__ . '/../web';
    }

    /**
     * {@inheritdoc}
     */
    protected function getCacheDir()
    {
        return $this->getWebDir() . '/tmp';
    }

    /**
     * Load configuration to Container
     *
     * @param LoaderInterface $loader
     */
    protected function registerContainerConfiguration(LoaderInterface $loader)
    {
        $loader->load(__DIR__ . '/config/config.yml');
    }
}
{% endhighlight %}

Now we need to think how we are going to make our container object accessible in OXID. I can think of three solutions:

* Make Container object as singleton in ContainerBridge component
  * PRO: we do need to change OXID
  * CON: it is a singleton which we later have to support
* Make Container accessible via oxRegistry with `oxRegistry::get('container')`:
  * PRO: it is using oxRegistry which familiar amongst OXID developers
  * CON: if you are going more Symfony way I am pretty sure you want to deprecate oxRegistry at some point of time, so you would have to readjust that again
* Inject Container on every instance of `ContainerAwareInterface` object constructed via oxNew
  * PRO: we are not tied to oxRegistry or any other OXID object directly
  * CON: extension of oxNew to magically inject Container to `ContainerAwareInterface` objects

I very ofter think of second and third options. Can not make my mind yet. For example implementation I am going to go with a third option.

We will create a seperate component to bridge Symfony DependencyInjection into OXID. Normally this would be a seperate package installed by Composer but as we are not planning to keep this implementation for a long time lets do this within the source of our project. Edit `composer.json` to autoload files by PSR-4 rules for `src/` directory:

{% highlight json %}
{
  "autoload": {
    "psr-4": { "": "src/" }
  },
  "require": {
    "php": "~5.4",
    "symfony/dependency-injection": "~2.6.0",
    "symfony/proxy-manager-bridge": "~2.6.0",
    "symfony/config": "~2.6.0",
    "symfony/yaml": "~2.6.0",
  }
}
{% endhighlight %}

And after running `composer update` you will get autoloader regenerated. So now we can implement base ContainerKernel class:

{% highlight php %}
<?php
// file: src/Ellis/Oxid/Bridge/DependencyInjection/ContainerKernel.php

namespace Ellis\Oxid\Bridge\DependencyInjection;

use Symfony\Component\Config\FileLocator;
use Symfony\Component\Config\ConfigCache;
use Symfony\Component\DependencyInjection\ExtensionInterface;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\DependencyInjection\Dumper\PhpDumper;
use Symfony\Component\DependencyInjection\ParameterBag\ParameterBag;
use Symfony\Component\DependencyInjection\Compiler\CompilerPassInterface;
use Symfony\Bridge\ProxyManager\LazyProxy\Instantiator\RuntimeInstantiator;
use Symfony\Bridge\ProxyManager\LazyProxy\PhpDumper\ProxyDumper;
use Symfony\Component\Config\Loader\LoaderResolver;
use Symfony\Component\Config\Loader\DelegatingLoader;
use Symfony\Component\DependencyInjection\Loader\XmlFileLoader;
use Symfony\Component\DependencyInjection\Loader\YamlFileLoader;
use Symfony\Component\DependencyInjection\Loader\IniFileLoader;
use Symfony\Component\DependencyInjection\Loader\PhpFileLoader;
use Symfony\Component\DependencyInjection\Loader\ClosureLoader;

/**
 * Abstract Container Kernel
 */
abstract class ContainerKernel
{
    /**
     * @var string
     */
    protected $appDir;

    /**
     * @var bool
     */
    protected $debug;

    /**
     * Constructor.
     *
     * @param bool $debug
     */
    public function __construct($debug)
    {
        $this->debug = (bool) $debug;
    }

    /**
     * Register DependencyInjection container extensions
     *
     * @return ExtensionInterface[]
     */
    abstract protected function registerExtensions();

    /**
     * Register DependencyInjection compiler passes
     *
     * @return CompilerPassInterface[]
     */
    abstract protected function registerCompilerPasses();

    /**
     * Is debug mode
     *
     * @return bool
     */
    protected function isDebug()
    {
        return $this->debug;
    }

    /**
     * Get application directory path
     *
     * @return string
     */
    protected function getAppDir()
    {
        if (null === $this->appDir) {
            $reflection = new \ReflectionObject($this);
            $this->appDir = str_replace('\\', '/', dirname($reflection->getFileName()));
        }

        return $this->appDir;
    }

    /**
     * Get web directory path
     *
     * @return string
     */
    abstract protected function getWebDir();

    /**
     * Get directory path where cache should be stored
     *
     * @return string
     */
    abstract protected function getCacheDir();

    /**
     * Gets the container class.
     *
     * @return string The container class
     */
    protected function getContainerClass()
    {
        return ($this->isDebug() ? 'Debug' : 'Project') . 'Container';
    }

    /**
     * Gets the container's base class.
     *
     * All names except Container must be fully qualified.
     *
     * @return string
     */
    protected function getContainerBaseClass()
    {
        return 'Container';
    }

    /**
     * Build service container from cache
     *
     * The cached version of the service container is used when fresh, otherwise the
     * container is built.
     */
    public function buildContainerFromCache()
    {
        $class = $this->getContainerClass();
        $cache = new ConfigCache($this->getCacheDir().'/'.$class.'.php', $this->isDebug());

        if (!$cache->isFresh()) {
            $container = $this->buildContainer();
            $container->compile();
            $this->dumpContainer($cache, $container, $class, $this->getContainerBaseClass());
        }

        require_once $cache;

        return new $class();
    }

    /**
     * Builds the service container.
     *
     * @return ContainerBuilder
     */
    protected function buildContainer()
    {
        $container = $this->getContainerBuilder();
        $this->prepareContainer($container);

        if (null !== $cont = $this->registerContainerConfiguration($this->getContainerLoader($container))) {
            $container->merge($cont);
        }

        return $container;
    }

    /**
     * Gets a new ContainerBuilder instance used to build the service container.
     *
     * @return ContainerBuilder
     */
    protected function getContainerBuilder()
    {
        $container = new ContainerBuilder(new ParameterBag($this->getKernelParameters()));

        if (class_exists('ProxyManager\Configuration')) {
            $container->setProxyInstantiator(new RuntimeInstantiator());
        }

        return $container;
    }

    /**
     * Returns the kernel parameters.
     *
     * @return array An array of kernel parameters
     */
    protected function getKernelParameters()
    {
        return array(
            'app_dir'   => $this->getAppDir(),
            'web_dir'   => $this->getWebDir(),
            'cache_dir' => $this->getCacheDir()
        );
    }

    /**
     * Prepares the ContainerBuilder before it is compiled.
     *
     * @param ContainerBuilder $container A ContainerBuilder instance
     */
    protected function prepareContainer(ContainerBuilder $container)
    {
        $extensions = array();
        foreach ($this->registerExtensions() as $extension) {
            $container->registerExtension($extension);
            $extensions[] = $extension->getAlias();
        }

        foreach ($this->registerCompilerPasses() as $compiler) {
            $container->addCompilerPass($compiler);
        }

        // ensure these extensions are implicitly loaded
        $container->getCompilerPassConfig()->setMergePass(new MergeExtensionConfigurationPass($extensions));
    }

    /**
     * Dumps the service container to PHP code in the cache.
     *
     * @param ConfigCache      $cache     The config cache
     * @param ContainerBuilder $container The service container
     * @param string           $class     The name of the class to generate
     * @param string           $baseClass The name of the container's base class
     */
    protected function dumpContainer(ConfigCache $cache, ContainerBuilder $container, $class, $baseClass)
    {
        // cache the container
        $dumper = new PhpDumper($container);

        if (class_exists('ProxyManager\Configuration')) {
            $dumper->setProxyDumper(new ProxyDumper());
        }

        $content = $dumper->dump(array('class' => $class, 'base_class' => $baseClass));
        $cache->write($content, $container->getResources());
    }

    /**
     * Returns a loader for the container.
     *
     * @param ContainerInterface $container The service container
     *
     * @return DelegatingLoader The loader
     */
    protected function getContainerLoader(ContainerInterface $container)
    {
        $locator = new FileLocator($this);
        $resolver = new LoaderResolver(array(
            new XmlFileLoader($container, $locator),
            new YamlFileLoader($container, $locator),
            new IniFileLoader($container, $locator),
            new PhpFileLoader($container, $locator),
            new ClosureLoader($container),
        ));

        return new DelegatingLoader($resolver);
    }
}
{% endhighlight %}

And `MergeExtensionConfigurationPass`:

{% highlight php %}
<?php
// file: src/Ellis/Oxid/Bridge/DependencyInjection/MergeExtensionConfigurationPass.php

namespace Ellis\Oxid\Bridge\DependencyInjection;

use Symfony\Component\DependencyInjection\Compiler\MergeExtensionConfigurationPass as BaseMergeExtensionConfigurationPass;
use Symfony\Component\DependencyInjection\ContainerBuilder;

/**
 * Ensures certain extensions are always loaded.
 *
 * @author Kris Wallsmith <kris@symfony.com>
 */
class MergeExtensionConfigurationPass extends BaseMergeExtensionConfigurationPass
{
    private $extensions;

    public function __construct(array $extensions)
    {
        $this->extensions = $extensions;
    }

    public function process(ContainerBuilder $container)
    {
        foreach ($this->extensions as $extension) {
            if (!count($container->getExtensionConfig($extension))) {
                $container->loadFromExtension($extension, array());
            }
        }

        parent::process($container);
    }
}
{% endhighlight %}

Great! Now we need to build this Container in OXID so we could use it. We could do this via module but we might want to use Container parameters in `config.inc.php` so lets create bootstrap file independent from OXID:

{% highlight php %}
<?php
// file: web/containerbootstrap.php

if (!class_exists('\Composer\Autoload\ClassLoader')) {
    require_once __DIR__.'/../vendor/autoload.php';
}

global $container;

if ($container === null) {
    require_once __DIR__.'/../app/ContainerKernel.php';
    $debug = getenv('SYMFONY_DEBUG') !== '0' && getenv('SYMFONY_ENV') !== 'prod';
    $kernel = new ContainerKernel($debug);
    $container = $kernel->buildContainerFromCache();
}
{% endhighlight %}

And bootstrap it in `bootstrap.php`:

{% highlight php %}
<?php
// file: web/bootstrap.php

// ...

// load composer autoloader
require_once __DIR__ . '/../vendor/autoload.php';

// initialize container
require_once __DIR__ . '/containerbootstrap.php';

// ...
{% endhighlight %}

Ok. Now we have something to add to our Symfony module. We will create `oxUtilsObject` extension. So first register this in metadata:

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
            global $container;
            $oObject->setContainer($container);
        }

        return $oObject;
    }
}
{% endhighlight %}

Congratulations! You can now have container injected in any OXID object. How can you benefit from this you might think. You can create components independent from OXID itself, register it as container extension and create a lean modules as bridges to use that in OXID project.

## Credits

Explanation of Dependency Injection in general was highly inspired by Fabien Potencier slides which are available at [slideshare.net](http://www.slideshare.net/fabpot/dependency-injection-with-php-and-php-53)

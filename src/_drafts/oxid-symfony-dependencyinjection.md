---
layout: post
title: OXID and Symfony Part 2&#58; DependencyInjection
---

Modern PHP application has lots of objects which are responsible for various things like email sending or data retrieval from database. Chances are great that you may want to have objects inside another one, especially if you follow [Single Responsibility Principle](https://en.wikipedia.org/wiki/Single_responsibility_principle). This part of OXID and Symfony post series will focus on explaining why [Dependency Injection](https://en.wikipedia.org/wiki/Dependency_injection) and showing how to have [Symfony DependencyInjection](http://symfony.com/doc/current/components/dependency_injection/introduction.html) component in OXID eShop.

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
        $data = $this->client->get(static::URL, [
            'longitude' => $location->getLongitude(),
            'latitude'  => $location->getLatitude()
        ]);

        return $this->parse->parseWeather($data);
    }
}

$weatherService = new YahooWeatherService;
{% endhighlight %}


DO NOT rush to facepalm just yet. First we are going to do this a wrong way so we would know a reason why it shouldn't be that way.

It is easy to create objects if you do it like in the example above but it is really hard to configure objects that this service depends on. What if `HttpClient` and `YahooDataParser` requires some parameters while constructing them. Everything would be hard coded into `YahooWeatherService` class. Also, every new instance of `YahooWeatherService` would create new instances for classes that it depends on (yes, `YahooWeatherService` is not that good of an example for this point, but `Product` class would me). We could solve this problem by using [registries](https://github.com/domnikl/DesignPatternsPHP/tree/master/Structural/Registry):

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

Object container is an object which is aware of other objects and their dependencies which are created on demand. Other object must know now that they are being controlled by object container. Lets create very primitive object container:

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

Symfony DependencyInjection component has way more capabilities than we have reviewed so far. We only did brief introduction to make you understand why and how to use it. Read more about Symfony DependencyInjection component read at [official website](http://symfony.com/doc/current/components/dependency_injection/introduction.html).

Create `app` directory. It will have main configuration files and `ContainerKernel.php` file which will be responsible for container extensions. Directory tree:

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

To be continued...

## Credits

Explanation of Dependency Injection in general was highly inspired by Fabien Potencier slides which are available at [slideshare.net](http://www.slideshare.net/fabpot/dependency-injection-with-php-and-php-53)

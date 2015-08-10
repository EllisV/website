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

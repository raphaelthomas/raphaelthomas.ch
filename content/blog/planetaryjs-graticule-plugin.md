+++
title = "Graticule Plugin for Planetary.js"
date = "2018-05-18T23:47:13+10:00"
draft = false
+++

After a couple of attempts at drawing a map using plain D3 and only rather
limited success, I stumbled upon [Planetary.js](http://planetaryjs.com/) and
decided to give it a go. The
[rotating globe with pings](http://planetaryjs.com/examples/rotating.html) was
pretty much where I wanted to go so I shamelessly borrowed the code and
started modifying it as needed.

One thing that I was missing on the original example was graticules in order
to give the sphere a more map-like look. As it turned out writing a plugin for
Planetary.js is very straightforward: The plugin consists of a single function
named `drawGraticule`, which defines what the plugin does (updating the
graticules `onDraw` in this case):

```js
function drawGraticule(color, width) {
    return function(planet) {
        planet.onDraw(function() {
            planet.withSavedContext(function(context) {
                var graticule = d3.geo.graticule();
                context.beginPath();
                planet.path.context(context)(graticule());
                context.strokeStyle = color;
                context.lineWidth = width;
                context.stroke();
            });
        });
    };
};
```

To then use the plugin we load it using the `loadPlugin()` function, passing
both the desired stroke color and stroke width as parameters:

```js
var globe = planetaryjs.planet();
globe.loadPlugin(drawGraticule("#000000", 1));
```

Whether or not the graticules overlay the rest of the map (e.g. the countries)
can be controlled by initialising this plugin before or after the built-in
plugins. Enjoy.

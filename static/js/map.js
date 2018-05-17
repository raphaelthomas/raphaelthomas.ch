(function() {
  var size = parseInt($("div#mapContainer").width()*0.5);
  console.log(size);
  $("canvas#map")[0].setAttribute("height", size);
  $("canvas#map")[0].setAttribute("width", size);

  var globe = planetaryjs.planet();
  globe.loadPlugin(autorotate(15));
  globe.loadPlugin(drawGraticule("rgba(0,0,0,0.25)", 0.25));
  globe.loadPlugin(planetaryjs.plugins.earth({
    topojson: { file:   '/world-110m.json' },
    oceans:   { fill:   'rgba(222,222,222, 0.1)' },
    land:     { fill:   'rgba(222,222,222, 1)' },
    borders:  { stroke: 'rgba(200,200,200, 1)' }
  }));
  globe.loadPlugin(planetaryjs.plugins.pings());

  globe.projection.scale(size/2-10).translate([size/2, size/2]).rotate([0, -15, 0]);

  d3.json("/location.json", function(error, data) {
    $("#locationText").html(jQuery.timeago(new Date(data.time * 1000)) + (data.location ? " somewhere in " + data.location : ''));
    setInterval(function() {
        globe.plugins.pings.add(data.coordinates[0], data.coordinates[1], { color: 'red', ttl: 2000, angle: 10 });
    }, 2500);
  });

  var canvas = document.getElementById('map');
  if (window.devicePixelRatio == 2) {
    canvas.width = 800;
    canvas.height = 800;
    context = canvas.getContext('2d');
    context.scale(2, 2);
  }
  globe.draw(canvas);

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

  function autorotate(degPerSec) {
    return function(planet) {
      var lastTick = null;
      var paused = false;
      planet.plugins.autorotate = {
        pause:  function() { paused = true;  },
        resume: function() { paused = false; }
      };
      planet.onDraw(function() {
        if (paused || !lastTick) {
          lastTick = new Date();
        } else {
          var now = new Date();
          var delta = now - lastTick;
          var rotation = planet.projection.rotate();
          rotation[0] += degPerSec * delta / 1000;
          if (rotation[0] >= 180) rotation[0] -= 360;
          planet.projection.rotate(rotation);
          lastTick = now;
        }
      });
    };
  };
})();

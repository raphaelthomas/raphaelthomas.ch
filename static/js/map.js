(function() {
    var size = parseInt($("div#mapContainer").width());
    if (size > 500) { size *= 0.5; };

    $("canvas#map")[0].setAttribute("height", size);
    $("canvas#map")[0].setAttribute("width", size);

    var globe = planetaryjs.planet();
    globe.loadPlugin(drawGraticule("rgba(0,0,0,0.25)", 0.25));
    globe.loadPlugin(planetaryjs.plugins.earth({
        topojson: { file:   '/world-110m.json' },
        oceans:   { fill:   'rgba(230,230,230,0.2)' },
        land:     { fill:   'rgba(230,230,230,1)' },
        borders:  { stroke: 'rgba(220,220,220,1)' }
    }));
    globe.loadPlugin(planetaryjs.plugins.pings());

    var lonStart = Math.floor(Math.random() * 360) - 180;
    var latStart = Math.floor(Math.random() * 180) - 90;
    globe.projection.scale(size/2-10).translate([size/2, size/2]).rotate([-lonStart, -latStart, 0]);

    d3.json("/location.json", function(error, data) {
        function ping() {
            globe.plugins.pings.add(data.coordinates[0], data.coordinates[1], { color: '#428BCA', ttl: 2500, angle: 10 });
            setTimeout(function() { ping(); }, 5000); 
        };

        function success() {
            $("#locationText").fadeOut(function() {
                var timestamp = new Date(data.time * 1000).toISOString();
                $(this).empty().append('<time id="locationTime" datetime="'+timestamp+'">'+timestamp+'</time>');
                $(this).append((data.location ? " somewhere in " + data.location : ''));
                $("time#locationTime").timeago();
            }).fadeIn(750, function() { ping(); });
        }

        globe.loadPlugin(rotateLonLat(25, data.coordinates[0], data.coordinates[1], success));

        var canvas = document.getElementById('map');
        globe.draw(canvas);

    });

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

    function rotateLonLat(degPerSec, lon, lat, rotateDone) {
        return function(planet) {
            var lastTick = null;
            var paused = false;
            var rateLatLon;

            planet.onDraw(function() {
                if (paused || !lastTick) {
                    lastTick = new Date();
                }
                else {
                    var now = new Date();
                    var rotation = planet.projection.rotate();

                    var diffLon = Math.round((parseFloat(lon) + parseFloat(rotation[0])) * 1000)/1000;
                    var diffLat = Math.round((parseFloat(lat) + parseFloat(rotation[1])) * 1000)/1000;

                    if (!rateLatLon) { rateLatLon = Math.abs(diffLat/diffLon); };

                    var delta = Math.round(degPerSec * (now - lastTick))/1000;
                    var deltaLon = delta;
                    var deltaLat = delta * rateLatLon;

                    if (diffLon > 0) { deltaLon *= -1 };
                    if (diffLat > 0) { deltaLat *= -1 };

                    // console.log("currLon:" + rotation[0] + "\nlon:" + lon + "\ndeltaLon:" + deltaLon + "\ndiffLon:" + diffLon + "\n\ncurrLat:" +rotation[1] + "\nlat:" + lat + "\ndeltaLat:" + deltaLat + "\ndiffLat:" + diffLat);

                    rotation[0] += deltaLon;
                    rotation[1] += deltaLat;

                    if ((Math.abs(diffLat) <= Math.abs(deltaLat)) || (Math.abs(diffLon) <= Math.abs(deltaLon))) {
                        paused = true;
                        rotateDone();
                    };

                    planet.projection.rotate(rotation);
                    lastTick = now;
                }
            });
        };
    };
})();

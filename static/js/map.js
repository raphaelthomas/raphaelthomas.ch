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
    globe.loadPlugin(rotatelonlat(25));

    var lonStart = Math.floor(Math.random() * 360) - 180;
    var latStart = Math.floor(Math.random() * 180) - 90;
    globe.projection.scale(size/2-10).translate([size/2, size/2]).rotate([-lonStart, -latStart, 0]);

    var canvas = document.getElementById('map');
    globe.draw(canvas);

    var oldData = null;
    var doPing  = false;

    function ping() {
        if (doPing) {
            globe.plugins.pings.add(oldData.coordinates[0], oldData.coordinates[1], { color: '#428BCA', ttl: 2500, angle: 10 });
        }

        setTimeout(function() { ping(); }, 5000);
    };

    function success() {
        $("#locationText").fadeOut(function() {
            var timestamp = new Date(oldData.time * 1000).toISOString();
            $(this).empty().append('<time id="locationTime" datetime="'+timestamp+'">'+timestamp+'</time>');
            $(this).append((oldData.location ? " somewhere in " + oldData.location : ''));
            $("time#locationTime").timeago();
        }).fadeIn(750, function() { doPing = true;});
    }

    function updateLocation() {
        var cachebuster = Math.round(new Date().getTime() / 1000);
        d3.json("/location.json?"+cachebuster, function(error, data) {
            if (!oldData || oldData.time < data.time) {
                // doPing = false;
                oldData = data;
                globe.plugins.rotatelonlat.init(data.coordinates[0], data.coordinates[1], success);
            }

            setTimeout(function() { updateLocation(); }, 60000);
        });
    }

    ping();
    updateLocation();

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

    function rotatelonlat(degPerSec) {
        return function(planet) {
            var rateLatLon = null;
            var lastTick = null;
            var paused = true;
            var lon, lat;
            var rotateDone;

            planet.plugins.rotatelonlat = {
                init: function(initLon, initLat, initRotateDone) {
                    lon = initLon;
                    lat = initLat;
                    paused = false;
                    lastTick = null;
                    rateLatLon = null;
                    rotateDone = initRotateDone;
                },
            };

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

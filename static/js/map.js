var size = parseInt($("#map").width()*0.5);
var width = size,
    height = size;

var projection = d3.geo.orthographic()
    .translate([width / 2, height / 2])
    .scale(width / 2 - 20)
    .clipAngle(90)
    .precision(0.6);

var canvas = d3.select("#map").append("canvas")
    .attr("width", width)
    .attr("height", height);

var c = canvas.node().getContext("2d");

var path = d3.geo.path()
    .projection(projection)
    .context(c);

d3.json("/world-110m.json", function(error, world) {
    if (error) throw error;
    updateLocation(world);
});

function updateLocation(world) {
    d3.json("/location.json", function(error, data) {
        $("#locationText").html(jQuery.timeago(new Date(data.time * 1000)) + (data.location ? " somewhere in " + data.location : ''));

        var land = topojson.feature(world, world.objects.land);
        var countries = topojson.feature(world, world.objects.countries).features;
        var graticule = d3.geo.graticule();

        (function transition() {
            d3.transition()
                .duration(2500)
                .tween("rotate", function() {
                    var r = d3.interpolate(projection.rotate(), [-data.coordinates[0], -data.coordinates[1]]);
                    return function(t) {
                        projection.rotate(r(t));
                        c.clearRect(0, 0, width, height);
                        c.fillStyle   = "#fdfdfd", c.beginPath(), path({type: "Sphere"}), c.fill();
                        c.strokeStyle = "rgba(0,0,0,0.25)", c.lineWidth = 0.25, c.beginPath(), path(graticule()), c.stroke();
                        c.fillStyle   = "rgba(127,127,127,0.5)", c.beginPath(), path(land), c.fill();
                        // c.strokeStyle = "rgba(0,0,0,0.25)", c.lineWidth = 0.25, c.beginPath(), path(borders), c.stroke();
                        c.fillStyle = "rgba(255,0,0,0.5)", c.beginPath(), c.arc(size/2, size/2, 2, 0, 2*Math.PI, false), c.fill();
// path({type: "Point", coordinates: [data.coordinates[0],data.coordinates[1]]}), c.fill();
                    };
                })
                .transition()
                .each("end", transition);
        })();
    });
}

d3.select(self.frameElement).style("height", height + "px");

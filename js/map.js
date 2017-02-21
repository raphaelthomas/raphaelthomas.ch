var width = 250,
    height = 250;

var svg = d3.select("div#map").append("svg")
    .attr("width", width)
    .attr("height", height);
var projection = d3.geo.orthographic()
    .scale(125)
    .translate([width / 2, height / 2])
    .clipAngle(90)
    .precision(.1);

d3.json("/data/location.json", function(error, data) {
    projection.rotate([-data.coordinates[0], -data.coordinates[1], 0]);

    var path = d3.geo.path().projection(projection);
    var graticule = d3.geo.graticule();

    svg.append("defs").append("path")
        .datum({type: "Sphere"})
        .attr("id", "sphere")
        .attr("d", path);

    svg.append("use")
        .attr("class", "stroke")
        .attr("xlink:href", "#sphere");

    svg.append("use")
        .attr("class", "fill")
        .attr("xlink:href", "#sphere");

    svg.append("path")
        .datum(graticule)
        .attr("class", "graticule")
        .attr("d", path);

    svg.selectAll("circle")
        .data([data.coordinates]).enter()
        .append("circle")
        .attr("cx", function (d) { return projection(d)[0]; })
        .attr("cy", function (d) { return projection(d)[1]; })
        .attr("r", "1px")
        .attr("class", "location");

    d3.json("/data/countries.json", function(error, world) {
      if (error) throw error;

      var countries = topojson.feature(world, world.objects.countries).features

      svg.selectAll(".country")
          .data(countries)
          .enter().insert("path", ".graticule")
          .attr("class", "land")
          .attr("d", path);
    });

    d3.select(self.frameElement).style("height", height + "px");

    $( function() {
        $("#typed").typed({
            strings: ["Last time seen " + data.time + " somewhere in " + data.location + "..."],
            typeSpeed: 0,
            startDelay: 100,
        });
    });
});

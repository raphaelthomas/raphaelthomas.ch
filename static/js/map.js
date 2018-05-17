var size = parseInt($("#map").width());

var svg = d3.select("div#map").append("svg")
    .attr("id", "map-globe")
    .attr("width", size)
    .attr("height", size);

var projection = d3.geo.orthographic()
    .scale(size/2)
    .translate([size/2, size/2])
    .clipAngle(90)
    .precision(.1);

d3.json("/location.json", function(error, data) {
    $("#locationText").html(jQuery.timeago(new Date(data.time * 1000)) + (data.location ? " somewhere in " + data.location : ''));
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
        .attr("r", "0.5px")
        .attr("class", "location");

    d3.json("/countries.json", function(error, world) {
      if (error) throw error;

      var countries = topojson.feature(world, world.objects.countries).features

      svg.selectAll(".country")
          .data(countries)
          .enter().insert("path", ".graticule")
          .attr("class", "land")
          .attr("d", path);
    });

    d3.select(self.frameElement).style("height", size + "px");
});

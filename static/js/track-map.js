var trackMap = L.map('trackmap').setView([0, 0], 1);


var tileLayerName = $("div#trackmap").data('maptiles');

if (tileLayerName) {
    L.tileLayer.provider(tileLayerName).addTo(trackMap);
}
else {
    L.tileLayer.provider('Esri.WorldStreetMap').addTo(trackMap);
    //L.tileLayer.provider('Stamen.Watercolor').addTo(trackMap);
}

$.getJSON("/track-"+$("div#trackmap").data('map')+".json", function (track) {
    if (!track.features.length) {
        return;
    }

    var size = 40;
    var markerStyle = {
        radius: 3,
        fillColor: "#000000",
        color: "#000000",
        opacity: 1,
        fillOpacity: 1
    };
    var icon = L.divIcon({
        html: '<img src="https://gravatar.com/avatar/cb979cc3781fd53475adc366bcc57731?s='+size+'"/>',
        className: "currentMarker",
        iconSize: [size, size],
    });

    var trackLayer = new L.geoJSON(track, {
        style: {
            fillColor: "#000000",
            color: "#000000",
            opacity: 0.5,
            fillOpacity: 0.5
        },
        pointToLayer: function (feature, latlng) {
            if (feature.properties.last) {
                return L.marker(latlng, {
                    icon: icon
                });
            }
            else {
                return L.circleMarker(latlng, markerStyle);
            }
        }
    });
    trackLayer.addTo(trackMap);
    trackMap.fitBounds(trackLayer.getBounds());
});

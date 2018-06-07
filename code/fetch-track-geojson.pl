#!/usr/bin/perl

use strict;
use warnings;

use Const::Fast;
use Data::Dumper;
use File::Slurp;
use Getopt::Long;
use HTML::Entities;
use HTTP::Request::Common;
use JSON::MaybeXS;
use Log::Dispatch;
use Log::Dispatch::Screen;
use Log::Dispatch::Syslog;
use LWP::UserAgent;
use Time::Piece;
use XML::LibXML;
use YAML::XS 'LoadFile';

const my $APRSFI_API  => 'http://api.aprs.fi/api/get';
const my $INREACH_API => 'https://eur.inreach.garmin.com/feed/Share';

sub main {
    my $config = get_config();

    print Dumper($config);

    for my $track (@{$config->{tracks}}) {
        print Dumper($track);

        # my $points = get_track_points($track, $config->{sources});
        # my $geojson = create_geojson_from_points($points);
        # for my $destination (@{$config->{output}}) {
        #     write_file($destination, $data);
        # }
    }

    # get_inreach_location($config->{inreach});

    # my $data = encode_json(
    #     {
    #         coordinates => [$location->{longitude}, $location->{latitude}],
    #         location    => encode_entities($location_text) // '',
    #         source      => encode_entities($location->{source}) // '',
    #         time        => $location->{timestamp}
    #     }
    # );

    return;
}

sub get_config {
    my $config_cli = {};

    GetOptions($config_cli,
        'config=s',
    );

    my $config_file = {};
    my $config_file_name = delete $config_cli->{config};

    $config_file = LoadFile($config_file_name) if ($config_file_name);

    return { %$config_file, %$config_cli };
}

sub get_aprsfi_location {
    my $config = shift;

    return if (!$config);

    my $ua = LWP::UserAgent->new();
    my $response = $ua->get("$APRSFI_API?name=$config->{callsign}&what=loc&format=json&apikey=$config->{key}");

    return if (!$response->is_success);
    return if ($response->header('content-type') !~ m/^application\/json/);

    my $aprs_loc = decode_json($response->content);

    if ($aprs_loc->{result} eq 'fail') {
        die "$aprs_loc->{description}\n";
    }
    return if ($aprs_loc->{found} <= 0);

    # sort entries based on lasttime descending, return largest
    for my $loc_entry (sort { $b->{lasttime} <=> $a->{lasttime} } @{$aprs_loc->{entries}}) {
        my $location = {
            timestamp => int($loc_entry->{time}),
            latitude  => $loc_entry->{lat},
            longitude => $loc_entry->{lng},
            source    => 'APRS path '.$loc_entry->{path},
        };

        return $location;
    }
}

sub get_inreach_location {
# https://eur.inreach.garmin.com/feed/Share/raphaelthomas?d1=2018-05-01T00:00Z&d2=2018-05-31T23:59Z
    my $config = shift;

    my $d1 = '2018-05-01T00:00Z';
    my $d2 = '2018-05-31T23:59Z';

    return if (!$config);

    my $ua = LWP::UserAgent->new();
    my $request = GET "$INREACH_API/$config->{user}?d1=$d1&d2=$d2";
    $request->authorization_basic('', $config->{password});

    my $response = $ua->request($request);

    my $xpc = XML::LibXML::XPathContext->new(
        XML::LibXML->load_xml(string => $response->content(), no_blanks => 1)
    );
    $xpc->registerNs( kml => 'http://www.opengis.net/kml/2.2' );

    my $data;
    my $id;

    for my $extendeddata ($xpc->findnodes('//*/kml:ExtendedData/kml:Data')) {
        my $name  = lc($extendeddata->{name});
        my $value = $extendeddata->to_literal;
        $name =~ s/ /_/g;

        $id = $value if ($name eq 'id');
        $data->{$id}{$name} = $value;

        print "$name\t$value\n";
    }

    print Dumper($data);

    # my $t = Time::Piece->strptime($data->{time_utc}, "%m/%d/%Y %I:%M:%S %p");

    # my $location = {
    #     timestamp => $t->epoch(),
    #     latitude  => $data->{latitude},
    #     longitude => $data->{longitude},
    #     source    => $data->{device_type}.' and Iridium satellite network',
    # };

    # return $location;
}

main();

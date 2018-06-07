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
        my $points  = get_track_points($track, $config->{sources});
        next if (!$points);

        my $geojson = get_geojson_from_points($points);
        next if (!$geojson);

        for my $destination (@{$config->{output}}) {
            write_file("$destination/$track->{name}.json", $geojson);
        }
    }

    return;
}

sub get_geojson_from_points {
    my $points = shift;

    return;
}

sub get_track_points {
    my ($track, $sources) = @_;

    print Dumper($track);

    my $points;

    for my $source (@$sources) {
        print Dumper($source);
        if ($source->{type} eq 'aprsfi') {

        }
        elsif ($source->{type} eq 'inreach') {
            push(@$points, get_inreach_points($source, $track->{start}, $track->{end}));

        }
    }

    print Dumper($points);

    return $points;
}

sub get_inreach_points {
    my ($config, $start, $end) = @_;

    return if (!$config);

    my $ua = LWP::UserAgent->new();
    my $request = GET "$INREACH_API/$config->{call}?d1=$start&d2=$end";
    $request->authorization_basic('', $config->{key});

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
    }

    print Dumper($data);

    my $points;

    for my $datum (values %$data) {
        my $t = Time::Piece->strptime($datum->{time_utc}, "%m/%d/%Y %I:%M:%S %p");
        my $point = {
            timestamp => $t->epoch(),
            latitude  => $datum->{latitude},
            longitude => $datum->{longitude},
        };

        push(@$points, $point);
    }

    return @$points;
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

sub get_config {
    my $config_cli = {};

    GetOptions($config_cli, 'config=s');

    my $config_file = {};
    my $config_file_name = delete $config_cli->{config};

    $config_file = LoadFile($config_file_name) if ($config_file_name);

    return { %$config_file, %$config_cli };
}

main();

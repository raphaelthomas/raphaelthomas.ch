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

    for my $track (@{$config->{tracks}}) {
        my $points  = get_track_points($track, $config->{sources});
        my $geojson = get_geojson_from_points($points);
        next if (!$geojson);

        for my $destination (@{$config->{output}{file}}) {
            write_file("$destination/track-$track->{name}.json", $geojson);
        }
    }

    return;
}

sub get_track_points {
    my ($track, $sources) = @_;

    my $points;

    my $now   = time;
    my $start = Time::Piece->strptime($track->{start}, "%Y-%m-%dT%H:%MZ");
    my $end   = Time::Piece->strptime($track->{end}, "%Y-%m-%dT%H:%MZ");

    # if track has not yet started, don't query the APIs
    return if ($start > $now);
    # if track has ended, don't query the APIs
    # FIXME integrate force option
    return if ($end < $now);

    for my $source (@{$track->{sources}}) {
        next if (!exists $sources->{$source});

        if ($sources->{$source}{type} eq 'aprsfi') {
            # FIXME
            # push(@$points, get_aprsfi_points($sources->{$source}, $track->{start}, $track->{end}));
        }
        elsif ($sources->{$source}{type} eq 'inreach') {
            push(@$points, get_inreach_points($sources->{$source}, $track->{start}, $track->{end}));
        }
    }

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

        if ($name eq 'id') {
            $name = undef;
            $id = $value;
        }
        elsif ($name eq 'longitude' || $name eq 'latitude') {
            # do nothing
        }
        elsif ($name eq 'elevation') {
            if ($value =~ m/^(\d+(:?\.\d+)?) m from MSL$/) {
                $value = $1;
            }
            else {
                $value = undef;
            }
        }
        elsif ($name eq 'course') {
            if ($value =~ m/^(\d+(:?\.\d+)?)/) {
                $value = $1;
            }
            else {
                $value = undef;
            }
        }
        elsif ($name eq 'velocity') {
            $name = 'speed';

            if ($value =~ m/^(\d+(:?\.\d+)?) km\/h$/) {
                $value = $1;
            }
            else {
                $value = undef;
            }
        }
        elsif ($name eq 'time_utc') {
            my $t = Time::Piece->strptime($value, "%m/%d/%Y %I:%M:%S %p");
            $name = 'timestamp';
            $value = $t->epoch();
        }
        else {
            $name = undef;
        }

        $data->{$id}{$name} = $value if ($name);
    }

    my @points = sort { $a->{timestamp} <=> $b->{timestamp} } values %$data;

    return @points;
}

sub get_aprsfi_points {
    my ($config, $start, $end) = @_;

    return if (!$config);

    my $ua = LWP::UserAgent->new();
    my $response = $ua->get("$APRSFI_API?name=$config->{call}&what=loc&format=json&apikey=$config->{key}");

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

sub get_geojson_from_points {
    my $points = shift;

    my @features;
    my @lineCoordinates;

    my $numPoints = scalar(@$points);
    for my $i (0 .. $numPoints-1) {
        my $point = $points->[$i];
        my $last = ($i == $numPoints-1);
        my $coordinates = [
            $point->{longitude},
            $point->{latitude},
            $point->{elevation}
        ];

        push(@features, {
            type => "Feature",
            geometry => {
                type => "Point",
                coordinates => $coordinates,
            },
            properties => {
                timestamp => $point->{timestamp},
                course => $point->{course},
                speed => $point->{speed},
                last => ($last ? 1 : 0)
            },
        });

        push(@lineCoordinates, $coordinates);
    }

    if (scalar(@lineCoordinates)) {
        unshift(@features, {
            type => "Feature",
            geometry => {
                type => "LineString",
                coordinates => \@lineCoordinates
            }
        });
    }

    return encode_json({
        type => "FeatureCollection",
        features => \@features,
    });
}

main();

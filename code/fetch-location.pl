#!/usr/bin/perl

use strict;
use warnings;

use Const::Fast;
use Data::Dumper;
use File::Slurp;
use Getopt::Long;
use HTML::Entities;
use JSON::MaybeXS;
use LWP::UserAgent;  
use YAML::XS 'LoadFile';

const my $GOOGLE_MAPS_API => 'https://maps.googleapis.com/maps/api/geocode/json';
const my $APRS_FI_API     => 'http://api.aprs.fi/api/get';

sub main {
    my $config = get_config();

    my $aprs_loc = get_aprs_location($config->{aprs_fi_api_key}, $config->{callsign});

    return if (!$aprs_loc);

    my $time = $aprs_loc->{lasttime};
    my $lat  = $aprs_loc->{lat};
    my $lon  = $aprs_loc->{lng};

    if (-r $config->{destination}) {
        my $old_loc = decode_json(read_file($config->{destination}));
        return if ($time <= $old_loc->{time});
    }

    my $location_text = get_google_maps_location($config->{google_maps_api_key}, $lat, $lon);

    my $data = {
        coordinates => [$lon, $lat],
        call => $config->{callsign},
        location => encode_entities($location_text) // '',
        time => $time
    };

    write_file($config->{destination}, encode_json($data));

    return;
}

sub get_config {
    my $config_cli = {};

    GetOptions ($config_cli,
        'callsign=s',
        'aprs_fi_api_key=s',
        'google_maps_api_key=s',
        'destination=s',
        'config=s'
    );

    my $config_file = {};
    my $config_file_name = delete $config_cli->{config};

    $config_file = LoadFile($config_file_name) if ($config_file_name);

    return {
        %$config_file,
        %$config_cli
    };
}

sub get_aprs_location {
    my ($api_key, $callsign) = @_;

    my $ua = LWP::UserAgent->new();
    my $response = $ua->get("$APRS_FI_API?name=$callsign&what=loc&format=json&apikey=$api_key");

    return if (!$response->is_success);
    return if ($response->header('content-type') !~ m/^application\/json/);

    my $aprs_loc = decode_json($response->content);

    if ($aprs_loc->{result} eq 'fail') {
        die "$aprs_loc->{description}\n";
    }
    return if ($aprs_loc->{found} <= 0);

    # sort entries based on lasttime descending, return largest
    for my $loc_entry (sort { $b <=> $a} @{$aprs_loc->{entries}}) {
        return $loc_entry;
    }
}

sub get_google_maps_location {
    my ($api_key, $lat, $lon) = @_;

    my $ua = LWP::UserAgent->new();
    my $response = $ua->get("$GOOGLE_MAPS_API?key=$api_key&latlng=$lat,$lon");

    return if (!$response->is_success);
    return if ($response->header('content-type') !~ m/^application\/json/);

    my $geo_loc = decode_json($response->content);

    if ($geo_loc->{status} eq 'ZERO_RESULTS') {
        return;
    }
    elsif ($geo_loc->{status} ne 'OK') {
        die $geo_loc->{status};
    }

    my $loc_text;
    my $loc_value = 0;

    for my $loc (@{$geo_loc->{results}}) {
        my $text = $loc->{formatted_address};
        my $value = 0;

        for my $type (@{$loc->{types}}) {
            if ($type eq 'political') {
                $value += 5
            }
            elsif ($type eq 'country') {
                $value += 10;
            }
            elsif ($type eq 'administrative_area_level_1') {
                $value += 15;
            }
            elsif ($type eq 'administrative_area_level_2') {
                $value += 20;
            }
            elsif ($type eq 'locality') {
                $value += 25;
            }
            # elsif ($type eq 'colloquial_area') {
            #     $value += 30;
            # }
        }

        if ($value > $loc_value) {
            $loc_text = $text;
            $loc_value = $value;
        }
    }

    return $loc_text;
}

main();

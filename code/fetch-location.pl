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

const my $LOCATIONIQ_API => 'https://eu1.locationiq.org/v1/reverse.php';
const my $APRSFI_API     => 'http://api.aprs.fi/api/get';

sub main {
    my $config = get_config();

    # my ($time, $lat, $lon) = (1520000000, -34.1254749, 151.1201258);
    my ($time, $lat, $lon) = get_aprs_location($config->{aprsfi_key}, $config->{callsign});
    return if (!$time);

    my @output_destinations = split(/,/, $config->{destination});

    if ((! $config->{force}) && (-r $output_destinations[0])) {
        my $old_loc = decode_json(read_file($output_destinations[0]));
        return if ($time <= $old_loc->{time});
    }

    my $location_text = reverse_geocode($config->{locationiq_key}, $lat, $lon);

    my $data = encode_json(
        {
            coordinates => [$lon, $lat],
            call => $config->{callsign},
            location => encode_entities($location_text) // '',
            time => $time
        }
    );

    for my $destination (@output_destinations) {
        write_file($destination, $data);
    }

    return;
}

sub get_config {
    my $config_cli = {};

    GetOptions ($config_cli,
        'callsign=s',
        'aprsfi_key=s',
        'locationiq_key=s',
        'destination=s',
        'config=s',
        'force'
    );

    my $config_file = {};
    my $config_file_name = delete $config_cli->{config};

    $config_file = LoadFile($config_file_name) if ($config_file_name);

    return { %$config_file, %$config_cli };
}

sub get_aprs_location {
    my ($api_key, $callsign) = @_;

    my $ua = LWP::UserAgent->new();
    my $response = $ua->get("$APRSFI_API?name=$callsign&what=loc&format=json&apikey=$api_key");

    return if (!$response->is_success);
    return if ($response->header('content-type') !~ m/^application\/json/);

    my $aprs_loc = decode_json($response->content);

    if ($aprs_loc->{result} eq 'fail') {
        die "$aprs_loc->{description}\n";
    }
    return if ($aprs_loc->{found} <= 0);

    # sort entries based on lasttime descending, return largest
    for my $loc_entry (sort { $b <=> $a} @{$aprs_loc->{entries}}) {
        return ($loc_entry->{time}, $loc_entry->{lat}, $loc_entry->{lng});
    }
}

sub reverse_geocode {
    my ($api_key, $lat, $lon) = @_;

    my $ua = LWP::UserAgent->new();
    my $response = $ua->get("$LOCATIONIQ_API?key=$api_key&lat=$lat&lon=$lon&format=json");

    return if (!$response->is_success);
    return if ($response->header('content-type') !~ m/^application\/json/);

    my $geo_loc  = decode_json($response->content);
    my $loc_text = '';
    my $address = $geo_loc->{address};

    if ($address->{locality}) {
        $loc_text .= " $address->{locality}";
    }
    elsif ($address->{suburb}) {
        $loc_text .= " $address->{suburb}";
    }
    elsif ($address->{city}) {
        $loc_text .= " $address->{city}";
    }

    if ($address->{country}) {
        $loc_text .= ", $address->{country}";
    }

    $loc_text = $geo_loc->{display_name} if ($loc_text eq '');

    return "$loc_text.";
}

main();

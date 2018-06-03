#!/usr/bin/perl

# FIXME Add course, speed and MSL to location

use strict;
use warnings;

use Const::Fast;
use Data::Dumper;
use File::Slurp;
use Getopt::Long;
use HTML::Entities;
use HTTP::Request::Common;
use JSON::MaybeXS;
use LWP::UserAgent;
use Time::Piece;
use XML::LibXML;
use YAML::XS 'LoadFile';

const my $LOCATIONIQ_API => 'https://eu1.locationiq.org/v1/reverse.php';
const my $APRSFI_API     => 'http://api.aprs.fi/api/get';
const my $INREACH_API    => 'https://eur.inreach.garmin.com/feed/Share';

my $log = 0;

sub main {
    my $config = get_config();

    my $aprsfi_location = get_aprsfi_location($config->{aprsfi});
    $log && print "Location from aprs.fi: ".encode_json($aprsfi_location)."\n";

    my $inreach_location = get_inreach_location($config->{inreach});
    $log && print "Location from InReach API: ".encode_json($inreach_location)."\n";

    my $location;

    if (!$aprsfi_location && !$inreach_location) {
        return;
    }
    elsif ($aprsfi_location && !$inreach_location) {
        $location = $aprsfi_location;
    }
    elsif (!$aprsfi_location && $inreach_location) {
        $location = $inreach_location;
    }
    elsif ($aprsfi_location && $inreach_location) {
        if ($aprsfi_location->{timestamp} >= $inreach_location->{timestamp}) {
            $location = $aprsfi_location;
        }
        else {
            $location = $inreach_location;
        }
    }
    else {
        return;
    }

    if ((! $config->{force}) && (-r $config->{destinations}->[0])) {
        my $old_loc = decode_json(read_file($config->{destinations}->[0]));

        if ($location->{timestamp} <= $old_loc->{time}) {
            $log && print "No location update compared to file.\n";
            return;
        }
    }

    my $location_text = reverse_geocode($config->{locationiq}, $location);

    my $data = encode_json(
        {
            coordinates => [$location->{longitude}, $location->{latitude}],
            location    => encode_entities($location_text) // '',
            source      => encode_entities($location->{source}) // '',
            time        => $location->{timestamp}
        }
    );

    $log && print "Generated location JSON: $data\n";

    for my $destination (@{$config->{destinations}}) {
        write_file($destination, $data);
    }

    return;
}

sub get_config {
    my $config_cli = {};

    GetOptions($config_cli,
        'aprs_callsign=s',
        'aprsfi_key=s',
        'inreach_user=s',
        'inreach_password=s',
        'locationiq_key=s',
        'destination=s',
        'config=s',
        'force',
        'log',
    );

    $log = 1 if ($config_cli->{log});

    my $config_file = {};
    my $config_file_name = delete $config_cli->{config};

    $config_file = LoadFile($config_file_name) if ($config_file_name);

    return { %$config_file, %$config_cli };
}

sub get_aprsfi_location {
    my $config = shift;

    my $ua = LWP::UserAgent->new();
    my $response = $ua->get("$APRSFI_API?name=$config->{callsign}&what=loc&format=json&apikey=$config->{key}");

    return if (!$response->is_success);
    return if ($response->header('content-type') !~ m/^application\/json/);

    my $aprs_loc = decode_json($response->content);

    $log && print "Retrieved location via aprs.fi: ".encode_json($aprs_loc)."\n";

    if ($aprs_loc->{result} eq 'fail') {
        die "$aprs_loc->{description}\n";
    }
    return if ($aprs_loc->{found} <= 0);

    # sort entries based on lasttime descending, return largest
    for my $loc_entry (sort { $b->{lasttime} <=> $a->{lasttime} } @{$aprs_loc->{entries}}) {
        return {
            timestamp => int($loc_entry->{time}),
            latitude  => $loc_entry->{lat},
            longitude => $loc_entry->{lng},
            source    => 'APRS path '.$loc_entry->{path},
        };
    }
}

sub get_inreach_location {
    my $config = shift;

    my $ua = LWP::UserAgent->new();
    my $request = GET "$INREACH_API/$config->{user}";
    $request->authorization_basic('', $config->{password});

    my $response = $ua->request($request);

    my $xpc = XML::LibXML::XPathContext->new(
        XML::LibXML->load_xml(string => $response->content(), no_blanks => 1)
    );
    $xpc->registerNs( kml => 'http://www.opengis.net/kml/2.2' );

    my $data;

    for my $extendeddata ($xpc->findnodes('//*/kml:ExtendedData/kml:Data')) {
        my $name  = lc($extendeddata->{name});
        my $value = $extendeddata->to_literal;
        $name =~ s/ /_/g;
        $data->{$name} = $value;
    }

    $log && print "Location retrieved via InReach API: ".encode_json($data)."\n";

    my $t = Time::Piece->strptime($data->{time_utc}, "%m/%d/%Y %I:%M:%S %p");

    return {
        timestamp => $t->epoch(),
        latitude  => $data->{latitude},
        longitude => $data->{longitude},
        source    => 'Iridium satellite network',
    };
}

sub reverse_geocode {
    my ($config, $location) = @_;

    return if (!$location);

    my $ua = LWP::UserAgent->new();
    my $response = $ua->get("$LOCATIONIQ_API?key=$config->{key}&lat=$location->{latitude}&lon=$location->{longitude}&format=json");

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

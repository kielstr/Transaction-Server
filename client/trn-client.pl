#!/usr/bin/perl -w

use strict;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Data::Dumper;

use Transaction::Client;
my $trn = new Transaction::Client
	HOST=>'localhost',
	PORT=>'5001';
my %param = (
	'1foo'=>'1',
	'2foo'=>'2',
	'3foo'=>'3',
	'4foo'=>'4',
	'5foo'=>'5',
	too=>'hoot'
);

print "Sending Transaction\n";
$trn->send('kiel', 'opennow', 'echotest', %param);
print "$_ => ". $trn->param($_) . "\n" for $trn->param();
#2Bsleep 5;
print "Sending Transaction\n";
$trn->send('kiel', 'test', 'echotest', %param);
print "$_ => ". $trn->param($_) . "\n" for $trn->param();
#sleep 5;

print "Sending Transaction\n";
$trn->send('kiel', 'test', 'echotest', %param);
print "$_ => ". $trn->param($_) . "\n" for $trn->param();
#sleep 5;

print Dumper $trn;
$trn->quit;

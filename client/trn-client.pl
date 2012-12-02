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
	too=>'hoot'
);

for my $user (qw(www kiel kielstr www wwwstr)) {
	print "Sending Transaction as $user\n";
	$trn->send($user, 'opennow', 'echotest', %param);

	if ($trn->param('error')) {
		my $error = $trn->param('error');
		printf "\tFailed %s\n", $error; 
	} else {
		print "\t$_ => ". $trn->param($_) . "\n" for $trn->param();
	}
}
$trn->quit;


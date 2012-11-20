
#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use lib qw(/usr/local/scripts/trans/lib);
use Transaction;

my $trn = new Transaction
	server	=> '10.0.0.55',
	port	=> 50001,
	user	=> 'nobody',
	passwd	=> 'GiveMeIt',
	timeout	=> 10,
	retrys	=> 5,
	ssl	=> 0
;

my $action = shift;
my %args = map {my($key, $val)= split '='; $key=>$val} @ARGV;

print Data::Dumper->Dump([\%args], ['sent']);

my $ret = $trn->send($action, %args);

print Data::Dumper->Dump([$ret], ['returned']);

print $trn->param("amps");

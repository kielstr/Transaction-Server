package Transaction::WebUI;

use Carp;
use FindBin qw($Bin);
use HTML::Template;
use Moose;
use Modern::Perl;
use Method::Signatures;
use Net::HTTPServer;
use Transaction::Client;
use Transaction::Command;

use Data::Dumper;

my $cmd = Transaction::Command->new;

method run ($pipe) {
	$cmd->pipe($pipe);
	
	my $httpserver = Net::HTTPServer->new(
		port => 8080,
		docroot => '/home/kiel/perl/Transaction-Server/public',
	);
	
	$httpserver->Start;
	$httpserver->RegisterURL("/restart", \&_restart_server);
	$httpserver->RegisterURL("/", \&_main);
	$httpserver->Process;
}

sub _main {
	my $req = shift;
	my $res = $req->Response();

        my $tmpl = HTML::Template->new(
		die_on_bad_params => 0,
		filename => "$Bin/WebUI-Templates/main.tmpl"
	);
	$res->Print($tmpl->output);
	return $res;
}

sub _restart_server {
	my $req = shift;
	my $res = $req->Response();

        my $tmpl = HTML::Template->new(
		die_on_bad_params => 0,
		filename => "$Bin/WebUI-Templates/main.tmpl"
	);

	$cmd->command_data('action', 'restart');
	$cmd->command_send;

	$res->Print($tmpl->output);
	return $res;
}

1;

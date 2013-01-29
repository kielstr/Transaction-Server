package Transaction::WebUI;

use Carp;
use FindBin qw($Bin);
#use Dancer;
use base qw(HTTP::Server::Simple::CGI);
use HTML::Template;
use Moose;
use Modern::Perl;
use Method::Signatures;
use Transaction::Client;
use Transaction::Command;

use Data::Dumper;

my $cmd = Transaction::Command->new;
my %dispatch = (
	'/restart' => \&restart_server,
	'/img' => \&send_image,
);

sub handle_request {
	my $self = shift;
	my $cgi  = shift;
	
	my $path = $cgi->path_info();
	my $handler = $dispatch{$path};

	if (ref($handler) eq "CODE") {
		print "HTTP/1.0 200 OK\r\n";
		print $cgi->header;
		$cgi->start_html('Transaction Server UI');
		$handler->($cgi);
		$cgi->end_html;
	} else {
		print "HTTP/1.0 404 Not found\r\n";
		print $cgi->header,
		$cgi->start_html('Not found'),
		$cgi->h1('Not found'),
		$cgi->end_html;
	}
}

sub restart_server {
	my ($self, $cgi) = @_;
	$cmd->command_data('action', 'restart');
	$cmd->command_send;

        my $tmpl = HTML::Template->new(
		die_on_bad_params => 0,
		filename => "$Bin/WebUI-Templates/main.tmpl"
	);
	
	print $tmpl->output;
};

sub send_image {
	my ($self, $cgi) = @_;
	my $path = $cgi->path_info();
	print $path;	
}

method _command_data ($key, $val?) {
	my $fh = $self->{pipe};
	print $fh join '=', $key, $val;
	print $fh "\n";
	return 1;
}

method _command_send {
	my $fh = $self->{pipe};
	print $fh ".\n";
	return 1;
}

1;

package Transaction::WebUI;

use strict;
use warnings;
use Dancer;
use HTML::Template;
use FindBin qw($Bin);

sub run {

	open my $fh, '>/dev/null' or croak $!;
	select $fh;

	my $tmpl = HTML::Template->new(
		die_on_bad_params => 0,
		filename => "$Bin/WebUI-Templates/main.tmpl"
	);

	get '/' => sub {
		return $tmpl->output;
	};

	dance;
	select STDOUT;
}

1;

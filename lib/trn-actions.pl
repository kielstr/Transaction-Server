use strict;
use Data::Dumper;

sub main_example {
  my ($socket, $trn) = @_;
  trans_data($socket, 'example', 'code');
  trans_send($socket);
  return 1;
}
1;

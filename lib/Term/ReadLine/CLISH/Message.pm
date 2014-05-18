package Term::ReadLine::CLISH::Message;

use Moose;
use namespace::autoclean;
use common::sense;

has qw(generated is ro isa Int default) => sub { time };
has qw(format is rw isa Str default) => "%% %s";
has qw(caption is ro isa Str);
has qw(msg is ro isa Str);

__PACKAGE__->meta->make_immutable;

sub spew {
    my $this = shift;
    my $msg = $this->msg;
    my $cap = $this->caption;

    $msg = "$cap: $msg" if $cap;

    say sprintf($this->format, $msg);
}

1;

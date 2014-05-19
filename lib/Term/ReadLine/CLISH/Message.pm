package Term::ReadLine::CLISH::Message;

use Moose;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use common::sense;
use overload '""' => \&stringify, fallback => 1;

has qw(generated is ro isa Int default) => sub { time };
has qw(format is rw isa Str default) => "%% %s";
has qw(caption is ro isa Str);
has qw(msg is ro isa Str);

__PACKAGE__->meta->make_immutable;

sub stringify {
    my $this = shift;
    my $msg = $this->msg;
    my $cap = $this->caption;

    $msg =~ s/[\x0d\x0a]+/\x0a/g;
    $msg =~ s/[\x0d\x0a]+$//g;
    $msg = "$cap: $msg" if $cap;

    return sprintf($this->format, $msg);
}

sub spew {
    my $this = shift;
    say $this;
}

1;

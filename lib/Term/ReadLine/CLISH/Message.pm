package Term::ReadLine::CLISH::Message;

use Moose;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use common::sense;
use Term::ANSIColorx::ColorNicknames;
use Term::ANSIColor ();
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

    my $fmt = $this->format;

    if( $ENV{CLISH_NOCOLOR} ) {
        $fmt =~ s/\%C(?:\([^()]*\))?//g;

    } else {
        $fmt =~ s/\%C(?:\(([^()]*)\))?/"$1" ? Term::ANSIColor::color("$1") : Term::ANSIColor::color('reset')/eg;
    }

    return sprintf($fmt, $msg);
}

sub spew {
    my $this = shift;
    say $this;
}

sub colorize {
    # overload this
}

1;

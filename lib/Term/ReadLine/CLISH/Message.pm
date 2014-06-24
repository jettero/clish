package Term::ReadLine::CLISH::Message;

use Moose;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use Term::ANSIColorx::ColorNicknames;
use common::sense;
use overload '""' => sub { $_[0]->stringify }, fallback => 1;

has qw(generated is ro isa Int default) => sub { time };
has qw(format is rw isa Str default) => "%s";
has qw(caption is ro isa Str);
has qw(msg is ro isa Str);

__PACKAGE__->meta->make_immutable;

sub stringify {
    my $this = shift;
    my $fmt  = $this->format;
    my $msg  = $this->msg;
    my $cap = $this->caption;

    my $msg = $this->msg;
       $msg =~ s/[\x0d\x0a]\z//g;

    my @msg = split m/[\x0d\x0a]/, $msg;

    if( $cap ) {
        if( @msg == 1 ) {
            $msg[0] = "$cap: $msg[0]";

        } else {
            $_ = "  $_" for @msg;
            unshift @msg, "$cap:";
        }
    }

    return join("\x0a", _apply_format( _apply_color($fmt => @msg) ));
}

sub spew {
    my $this = shift;

    say $this;
}

sub _apply_format {
    my $fmt = shift;

    map { sprintf($fmt, $_) } @_;
}

sub _apply_color {
    map {

        if( $ENV{CLISH_NOCOLOR} ) {
            s/\%C(?:\([^()]*\))?//g;

        } else {
            s{\%C(?:\(([^()]*)\))?}{
                "$1"
                ? Term::ANSIColorx::ColorNicknames::color("$1")
                : Term::ANSIColorx::ColorNicknames::color('reset')
            }eg;
        }

        $_
    }

    @_
}

1;

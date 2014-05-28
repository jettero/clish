
package Term::ReadLine::CLISH::MessageSystem;

use common::sense;
use base 'Exporter';
use Term::ReadLine::CLISH::Message;
use Term::ReadLine::CLISH::Error;
use Term::ReadLine::CLISH::Warning;
use Term::ReadLine::CLISH::Debug;
use Carp;

our @EXPORT = qw(one_off_debug debug info warning error install_generic_message_handlers);

ONE_OFF_CONTEXT: {
    my %only_one;
    sub one_off_debug($;$) {
        my @c = caller;
        $only_one{@c} ++;
        croak "one_off_debug() must be called from only one place" unless 1 == keys %only_one;
        local $ENV{CLISH_DEBUG} = 1;
        debug(@_);
    }
}

sub debug($;$) {
    croak "debug called without debug ENV set" unless $ENV{CLISH_DEBUG};

    my @args = _possibly_captioned_message(@_);

    Term::ReadLine::CLISH::Debug->new(@args)->spew;
}

sub info($;$) {
    my @args = _possibly_captioned_message(@_);

    Term::ReadLine::CLISH::Message->new(@args)->spew;
}

sub warning($;$) {
    my @args = _probably_just_a_caption(@_);

    Term::ReadLine::CLISH::Warning->new(@args)->spew;
}

sub error($;$) {
    my @args = _probably_just_a_caption(@_);

    Term::ReadLine::CLISH::Error->new(@args)->spew;
}

sub install_generic_message_handlers {
    $SIG{__WARN__} = sub { warning "uncaught warning", "$_[0]" };
}

sub _probably_just_a_caption {
    my @args;

    if( @_ == 2 ) {
        push @args, caption => shift;
        push @args, msg     => shift;

    } elsif( @_ == 1 ) {
        push @args, caption => shift;

    } else {
        croak "choose either 'message' or 'caption', 'message'";
    }

    return @args;
}

sub _possibly_captioned_message {
    my @args;

    if( @_ == 2 ) {
        push @args, caption => shift;
        push @args, msg     => shift;

    } elsif( @_ == 1 ) {
        push @args, msg => shift;

    } else {
        croak "choose either 'message' or 'caption', 'message'";
    }

    return @args;
}

1;

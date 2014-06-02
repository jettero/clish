
package Term::ReadLine::CLISH::MessageSystem;

use common::sense;
use base 'Exporter';
use Term::ReadLine::CLISH::Message;
use Term::ReadLine::CLISH::Error;
use Term::ReadLine::CLISH::Warning;
use Term::ReadLine::CLISH::Debug;
use Carp;

our @EXPORT = qw(wtf debug info warning error install_generic_message_handlers scrub_last_error);

our $FILE = __FILE__;
our $BASE = $FILE;
    $BASE =~ s/^.*?Term/Term/;
    $BASE =~ s/CLISH.*\z/CLISH/;

sub scrub_last_error(;$) {
    ($@) = @_ if @_;

    chomp $@;

    # “ERROR executing CMD[help]: "perldoc" unexpectedly returned exit value 1 at
    #     lib/Term/ReadLine/CLISH/Library/Commands/Help.pm line 74.”
    #
    # Don't reveal the location of this error.  The error is with the user, or
    # with perldoc (at least when scrub_last_error is called, that's the idea).

    wtf($@ . " —- " . $BASE);
    $@ =~ s{\s+at\s+.+?\Q$BASE\E.+?\s+line\d+\.}{};
    die "wtf"  if $@ =~ m{$BASE};

    $@;
}

sub wtf($;$) {
    local $ENV{CLISH_DEBUG} = 1;
    $_[0] = "WTF $_[0]";
    debug(@_);
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
  # $SIG{__DIE__} = sub { warning "uncaught error", "$_[0]" };

    binmode STDIN,  ":utf8"; # if we're not using utf8 … we’re … on a comadore64? Slowlaris?
    binmode STDOUT, ":utf8"; # … it'd be just odd
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

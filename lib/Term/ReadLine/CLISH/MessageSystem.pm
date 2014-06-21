
package Term::ReadLine::CLISH::MessageSystem;

use common::sense;
use base 'Exporter';
use Term::ReadLine::CLISH::Message;
use Term::ReadLine::CLISH::Message::Debug;
use Term::ReadLine::CLISH::Message::Information;
use Term::ReadLine::CLISH::Message::Warning;
use Term::ReadLine::CLISH::Message::Error;
use Carp;

our @EXPORT = qw(wtf debug help info warning error install_generic_message_handlers scrub_last_error);

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

sub debug($;$) {
    croak "debug called without debug ENV set" unless $ENV{CLISH_DEBUG};

    my %args = _possibly_captioned_message(@_);
    Term::ReadLine::CLISH::Message::Debug->new(%args)->spew;
}

sub wtf($;$) {
    my ($pkg, $file, $line) = caller;
    my %args = _possibly_captioned_message(@_);

    $args{caption} = $args{caption}
        ? "(WTF in $file at line $line) $args{caption}"
        : "WTF in $file at line $line";

    local $ENV{CLISH_DEBUG} = 1;
    Term::ReadLine::CLISH::Message::Debug->new(%args)->spew;
}

sub info($;$) {
    my %args = _possibly_captioned_message(@_);

    Term::ReadLine::CLISH::Message::Information->new(%args)->spew;
}

sub help($;$) {
    my %args = _possibly_captioned_message(@_);

    Term::ReadLine::CLISH::Message->new(%args)->spew;
}

sub warning($;$) {
    my %args = _probably_just_a_caption(@_);

    Term::ReadLine::CLISH::Message::Warning->new(%args)->spew;
}

sub error($;$) {
    my %args = _probably_just_a_caption(@_);

    Term::ReadLine::CLISH::Message::Error->new(%args)->spew;
}

sub install_generic_message_handlers {
    $SIG{__WARN__} = sub {
        my $w = "$_[0]";

        if( $ENV{CLISH_CONFESS} or ($w =~ m/line \d/ and not $w =~ m{Term/.*?/CLISH}) ) {
            warning "uncaught warning", $w;
            warning "warning in external package, call trace follows";
            my $i = 0;
            while( my @c = caller($i++) ) {
                my ($package, $filename, $line, $subroutine, $hasargs,
                    $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash)

                = @c;

                warning "trace($i)", "pkg=$package sub=$subroutine file=$filename line=$line";

            }

        } else {
            warning "uncaught warning", $w;
        }
    };
  # $SIG{__DIE__} = sub { warning "uncaught error", "$_[0]" };

    binmode STDIN,  ":utf8"; # if we're not using utf8 … we’re … on a comadore64? Slowlaris?
    binmode STDOUT, ":utf8"; # … it'd be just odd
}

sub _probably_just_a_caption {
    my %args;

    # if we only have @_==1 then the message is probably $@

    if( @_ == 2 ) {
        $args{caption} = shift;
        $args{args}    = shift;

    } elsif( @_ == 1 ) {
        $args{caption} = shift;

    } else {
        croak "choose either 'message' or 'caption', 'message'";
    }

    return %args;
}

sub _possibly_captioned_message {
    my %args;

    # if we only have @_==1 then there's probably no caption

    if( @_ == 2 ) {
        $args{caption} = shift;
        $args{msg}     = shift;

    } elsif( @_ == 1 ) {
        $args{msg} = shift;

    } else {
        croak "choose either 'message' or 'caption', 'message'";
    }

    return %args;
}

1;

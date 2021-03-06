
package Term::ReadLine::CLISH::MessageSystem;

use common::sense;
use base 'Exporter';
use Term::ReadLine::CLISH::Message;
use Term::ReadLine::CLISH::Message::Debug;
use Term::ReadLine::CLISH::Message::Help;
use Term::ReadLine::CLISH::Message::Information;
use Term::ReadLine::CLISH::Message::Warning;
use Term::ReadLine::CLISH::Message::Error;
use Term::ReadLine::CLISH::Message::TODO;
use Text::Table;
use Carp;

our @MSGS = qw(wtf debug help info warning error XXX todo from_table);
our @TOOL = qw(scrub_last_error from_table);
our @BOOT = qw(install_generic_message_handlers);

our @EXPORT_OK = (@MSGS, @TOOL, @BOOT);
our %EXPORT_TAGS = ( all=>[@MSGS, @TOOL, @BOOT], msgs=>[@MSGS], tool=>[@TOOL], boot=>[@BOOT] );

our $FILE = __FILE__;
our $BASE = $FILE;
    $BASE =~ s/^.*?Term/Term/;
    $BASE =~ s/CLISH.*\z/CLISH/;

sub from_table(@) {

    my @head;
    if( $_[0] eq "-head" ) {
        my (undef, $tmp) = splice @_, 0, 2;
        @head = @{ $tmp };
    }

    my $table;

    eval {
        $table =

        Text::Table
            ->new  ( map{uc} @head )
            ->load ( @_ )

    ;1} or croak scrub_last_error();

    return "$table";
}

# error_strip error_clean, blah
sub scrub_last_error(;$) {
    ($@) = @_ if @_;

    chomp $@;

    # “ERROR executing CMD[help]: "perldoc" unexpectedly returned exit value 1 at
    #     lib/Term/ReadLine/CLISH/Library/Commands/Help.pm line 74.”
    #
    # Don't reveal the location of this error.  The error is with the user, or
    # with perldoc (at least when scrub_last_error is called, that's the idea).

    1 while $@ =~ s{\s+at\s+\S+\Q$BASE\E\S+\s+line\s+\d+\.}{};
    die "internal error scrubbing error (BASE)"  if $@ =~ m{$BASE};

    $@;
}

sub install_generic_message_handlers {
    $SIG{__WARN__} = sub {
        my $w = join(" ", map {"$_"} grep {defined and length} @_);

        warning("uncaught warning", $w);

        if( $ENV{CLISH_CONFESS} or ($w =~ m/line \d/ and not $w =~ m{Term/.*?/CLISH}) ) {
            warning("warning in external package, call trace follows");
            my $i = 0;
            while( my @c = caller($i++) ) {
                my ($package, $filename, $line, $subroutine, $hasargs,
                    $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash)

                = @c;

                warning("trace($i)", "pkg=$package sub=$subroutine file=$filename line=$line");

            }
        }
    };

    binmode STDIN,  ":utf8"; # if we're not using utf8 … we’re … on a comadore64? Slowlaris?
    binmode STDOUT, ":utf8"; # … it'd be just odd to not have wide characters
}

sub _probably_just_a_caption {
    my %args;

    # if we only have @_==1 then the message is probably $@

    if( @_ == 2 ) {
        $args{caption} = shift;
        $args{msg}     = shift;

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

##₀        |↑
##########|||≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡=================>
##°        |↓


sub debug($;$) {
    croak "debug called without debug ENV set" unless $ENV{CLISH_DEBUG};

    my %args = _possibly_captioned_message(@_);
    Term::ReadLine::CLISH::Message::Debug->new(%args)->spew;
}

sub info($;$) {
    my %args = _possibly_captioned_message(@_);

    Term::ReadLine::CLISH::Message::Information->new(%args)->spew;
}

sub help($;$) {
    my %args = _possibly_captioned_message(@_);

    Term::ReadLine::CLISH::Message::Help->new(%args)->spew;
}

sub warning($;$) {
    my %args = _probably_just_a_caption(@_);

    Term::ReadLine::CLISH::Message::Warning->new(%args)->spew;
}

sub error($;$) {
    my %args = _probably_just_a_caption(@_);

    Term::ReadLine::CLISH::Message::Error->new(%args)->spew;
}

sub todo($;$) {
    my %args = _possibly_captioned_message(@_);

    Term::ReadLine::CLISH::Message::TODO->new(%args)->spew;
}
*XXX = \&todo;

use Data::Dump::Filtered qw(add_dump_filter);
use Data::Dump qw(dump);

add_dump_filter(sub{ my ($ctx, $obj) = @_; return { dump => "q«$obj»" } if $ctx->is_blessed; });

sub wtf($;$) {
    my ($pkg, $file, $line) = caller;

    my %args = (
        caption => "WTF in $file at line $line",
        msg     => dump(@_),
    );

    local $ENV{CLISH_DEBUG} = 1;
    Term::ReadLine::CLISH::Message::Debug->new(%args)->spew;
}

1;

package Term::ReadLine::CLISH;

=encoding UTF-8
=head1 NAME

Term::ReadLine::CLISH — command line interface shell

=cut

=head1 SYNOPSIS

XXX: Cut from example/MyShell.pm

=cut

use Moose;
use namespace::autoclean;
use Term::ReadLine;
use Term::ReadLine::CLISH::Parser;
use Term::ReadLine::CLISH::MessageSystem;
use common::sense;

our $VERSION = '0.0000'; # string for the CPAN

has qw(prompt is rw isa Str default) => "clish> ";
has qw(path   is rw isa pathArray coerce 1 default) => sub { [@INC] };
has qw(prefix is rw isa prefixArray coerce 1 default) => sub {['Term::ReadLine::CLISH::Library::Commands']};
has qw(name is ro isa Str default) => "CLISH";
has qw(version is ro isa Str default) => $VERSION;
has qw(history_location is rw);
has qw(term is rw isa Term::ReadLine);
has qw(parser is rw isa Term::ReadLine::CLISH::Parser);
has qw(done is rw isa Bool);
has qw(cleanup is rw isa ArrayRef[CodeRef] default) => sub { [sub { say "\r\e[2Kbye" }] };

sub DEMOLISH {
    my $this = shift;

    for my $cr (@{ $this->cleanup }) {
        eval { $cr->($this); 1} or warning "during cleanup";
    }
}

sub BUILD {
    my $this = shift;
    my $term = Term::ReadLine->new($this->name);
    my $parser = Term::ReadLine::CLISH::Parser->new(path=>$this->path, prefix=>$this->prefix);

    # XXX: I hate ornaments, but this should probably be an option later
    eval { $term->ornaments('', '', '', '') };

    install_generic_message_handlers();

    $this->term( $term );
    $this->parser( $parser );

    push @{ $this->cleanup }, sub { shift->save_history };
}

sub run {
    my $this = shift;

    $this->init_history;

    print "Welcome to " . $this->name . " v" . $this->version . ".\n\n";

    INPUT: while( not $this->done ) {
        my $prompt = $this->prompt;
        $_ = $this->term->readline($prompt);
        last INPUT unless defined;
        s/^\s*//; s/\s*$//; s/[\r\n]//g;

        $this->parser->parse($_); # generates/prints errors and executes commands
    }
}

sub init_history {
    my $this = shift;
    my $term = $this->term;

    my $hl = $this->history_location;
    if( !$hl ) {
        my $n = lc $this->name;
        $this->history_location( $hl = "$ENV{HOME}/.$n\_history" );
    }
    $term->read_history($hl);
    print "[loaded ", int ($term->GetHistory), " command(s) from history file]\n";
}

sub save_history {
    my $this = shift;
    my $term = $this->term;
    my $hl = $this->history_location;

    return unless $hl;
    $term->write_history($hl);
    $term->history_truncate_file($hl, 100);
}

__PACKAGE__->meta->make_immutable;

1;

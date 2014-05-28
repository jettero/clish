package Term::ReadLine::CLISH;

=encoding UTF-8
=head1 NAME

Term::ReadLine::CLISH — command line interface shell

=cut

=head1 SYNOPSIS

    XXX: Cut from example/*

=cut

use Moose;
use namespace::autoclean;
use Term::ReadLine;
use Term::ReadLine::CLISH::Parser;
use Term::ReadLine::CLISH::MessageSystem;
use File::Spec;
use POSIX qw(sigaction SIGINT);
use common::sense;

our $VERSION = '0.0000'; # string for the CPAN

has qw(prompt is rw isa Str default) => "clish> ";
has qw(path   is rw isa pathArray coerce 1 default) => sub {
    my $file = __FILE__;
       $file =~ s/.pm$//;

    return [File::Spec->catfile($file, "Library")]
};

has qw(prefix is rw isa prefixArray coerce 1 default) => sub {['Term::ReadLine::CLISH::Library::Commands']};
has qw(name is rw isa Str default) => "CLISH";
has qw(version is rw isa Str default) => $VERSION;
has qw(history_location is rw);
has qw(term is rw isa Term::ReadLine::Stub);
has qw(parser is rw isa Term::ReadLine::CLISH::Parser);
has qw(done is rw isa Bool);
has qw(cleanup is rw isa ArrayRef[CodeRef] default) => sub { [sub { say "\r\e[2Kbye" }] };

__PACKAGE__->meta->make_immutable;

sub add_namespace {
    my $this = shift;
    my $ns   = shift;
    my $nsp  = $ns; $nsp =~ s{::}{/}g;

    push @{ $this->path }, $nsp;
    push @{ $this->prefix }, $ns;

    $this;
}

sub path_string {
    my $this = shift;

    return join(":", @{ $this->path });
}

sub DEMOLISH {
    my $this = shift;

    for my $cr (@{ $this->cleanup }) {
        eval { $cr->($this); 1} or warning "during cleanup";
    }
}

sub BUILD {
    my $this = shift;
    my $term = Term::ReadLine->new($this->name);

    # XXX: I hate ornaments, but this should probably be an option later
    eval { $term->ornaments('', '', '', '') };
    $this->term( $term );

    install_generic_message_handlers();

    push @{ $this->cleanup }, sub { shift->save_history };
}

sub rebuild_parser {
    my $this = shift;

    my $parser = Term::ReadLine::CLISH::Parser->new(path=>$this->path, prefix=>$this->prefix);
    $this->parser( $parser );
    debug "path: " . $this->path_string if $ENV{CLISH_DEBUG};
}

sub run {
    my $this = shift;

    $this->init_history;
    $this->rebuild_parser;
    $this->attach_sigint;

    info "Welcome to " . $this->name . " v" . $this->version;

    INPUT: while( not $this->done ) {
        my $prompt = $this->prompt;
        $_ = $this->term->readline($prompt);
        last INPUT unless defined;
        s/^\s*//; s/\s*$//; s/[\r\n]//g;

        if( my ($cmd, $args) = $this->parser->parse_for_execution($_) ) {

            $cmd->exec( $args );
            #rint "\n"; # XXX: blank line after cmd execution?  hrm.... can't decide ....

        }

        # else { the parser prints the relevant errors for us }
    }
}

sub init_history {
    my $this = shift;
    my $term = $this->term;

    if( $term->can("read_history") ) {
        my $hl = $this->history_location;
        if( !$hl ) {
            my $n = lc $this->name;
            $this->history_location( $hl = "$ENV{HOME}/.$n\_history" );
        }
        $term->read_history($hl);

        info "[loaded " . int($term->GetHistory) . " command(s) from history file]";
    }
}

sub save_history {
    my $this = shift;
    my $term = $this->term;

    if( $term->can("write_history") ) {
        my $hl = $this->history_location;

        return unless $hl;
        $term->write_history($hl);
        $term->history_truncate_file($hl, 100);
    }
}

sub safe_talk {
    my $this = shift;
    my $code = shift;
    my $term = $this->term;
    my $attribs = $term->Attribs;
    my $prompt = $attribs->{prompt};

    # NOTE: mostly from Term::ReadLine::Gnu's eg/perlsh; but to be
    # fair, tried to copy AnyEvent::ReadLine::Gnu first — I just
    # couldn't get that to work without warnings that dorked it all up.
    # I think he needs to add {end} to his hide() / show().

    $term->modifying;
    $term->delete_text;
    $attribs->{point} = $attribs->{end} = 0;
    $term->set_prompt("");
    $term->redisplay;

    $code->();

    $term->set_prompt($prompt);
    $term->redisplay;
}

sub attach_sigint {
    my $this = shift;

    if( $this->term->isa("Term::ReadLine::Gnu") ) {
        my ($last, $count);

        sigaction SIGINT, new POSIX::SigAction sub {
            $this->safe_talk(sub{

                my $now = time;
                if( $now - $last < 2 ) {
                    if( (--$count) <= 0 ) {
                        info "ok! see ya …";

                        eval { ($this->parser->parse_for_execution("quit"))[0]->exec(); 1}
                            or die "problem executing quit command, dying instead";

                    } else {
                        info( $count == 1 ? "got ^C (hit again to exit)" :
                            "got ^C (hit $count more times to exit)" );
                    }
                }

                else {
                    $count = 2;
                    info "got ^C (hit $count more times to exit)";
                    $last = $now;
                }

            });

        } or die "Error setting SIGINT handler: $!\n";

    }
}

1;

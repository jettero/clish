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

    binmode STDIN,  ":utf8"; # if we're not using utf8 … we’re … on a comadore64? Slowlaris?
    binmode STDOUT, ":utf8"; # … it'd be just odd

    $this->init_history;
    $this->rebuild_parser;
    $this->attach_sigint;
    $this->attach_completion_whirlygigs;

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
    my @save = @{ $attribs }{qw(prompt line_buffer point end)};

    # NOTE: mostly from Term::ReadLine::Gnu's eg/perlsh; but to be
    # fair, tried to copy AnyEvent::ReadLine::Gnu first — I just
    # couldn't get that to work without warnings that dorked it all up.
    # I think he needs to add {end} to his hide() / show().

    $term->modifying;
    @{ $attribs }{qw(line_buffer point end)} = ("", 0,0,0);
    $term->set_prompt("");
    $term->redisplay;

    $code->();

    $term->modifying;
    $term->set_prompt(shift @save);
    @{ $attribs }{qw(line_buffer point end)} = @save;
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

THE_WHIRLYGIGS: {
    my ($i, @m);
    my $_matches = sub {
        my ($this, $attribs, $text, $state) = @_;
        my $return;

        if( $state ) {
            $i ++;

        } else {
            $i = 0;
            @m = map { $_->name } map {($_, @{$_->arguments})} @{ $this->parser->cmds };
            $attribs->{completion_append_character} = $text =~ m/^(["'])/ ? "$1 " : ' ';
            $this->safe_talk(sub{ one_off_debug("\$#m = ($#m); \$attribs{cac}=«$attribs->{completion_append_character}»") });
        }

        for(; $i < $#m ; $i++ ) {
            if( $m[$i] =~ m/^(['"]*)\Q$text/ ) {
                $return = $m[$i];
                last;
            }
        }

        $this->safe_talk(sub{ one_off_debug("  \$i=$i; \$m[$i] = \$return = $return") });
        return $return;
    };

    sub _try_to_complete {
        my ($this, $term, $attribs, $text, $line, $start, $end) = @_;

        return $term->completion_matches($text, sub { $_matches->($this, $attribs, @_) });
    }
}

sub attach_completion_whirlygigs {
    my $this = shift;
    my $term = $this->term;
    my $attribs = $term->Attribs;

    # curry in the bind variables so we don't have to look them up again
    $attribs->{attempted_completion_function} = sub { $this->_try_to_complete($term, $attribs, @_) };
    $attribs->{completion_display_matches_hook} = sub {
        my($matches, $num_matches, $max_length) = @_;

        # XXX: reformatting is done here I guess

        $term->display_match_list($matches);
        $term->forced_update_display;
    };
}

1;

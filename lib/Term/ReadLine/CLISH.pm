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
use File::HomeDir;
use Tie::YAML;
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
has qw(vdb is rw isa Tie::YAML);
has qw(term is rw isa Term::ReadLine::Stub);
has qw(parser is rw isa Term::ReadLine::CLISH::Parser);
has qw(done is rw isa Bool);
has qw(cleanup is rw isa ArrayRef[CodeRef] default) => sub { [sub { info "bye" }] };

__PACKAGE__->meta->make_immutable;

sub var {
    my $this = shift;
    my ($var, $val) = @_;
    my $vdb = $this->vdb;

    if( @_ > 1 ) {
        if( defined $val ) {
            $vdb->{$var} = $val;

        } else {
            delete $vdb->{$var};
        }

        $vdb->save;
    }

    return $vdb->{$var};
}

sub var_defined_or_default {
    my $this = shift;
    my ($var, $default) = @_;
    my $orig = $this->var($var);

    return $orig if defined $orig;
    return $this->var( $var, $default );
}

sub var_true_or_default {
    my $this = shift;
    my ($var, $default) = @_;
    my $orig = $this->var($var);

    return $orig if $orig;
    return $this->var( $var, $default );
}

sub add_namespace {
    my $this = shift;
    my $ns   = shift;
    my $nsp  = $ns; $nsp =~ s{::}{/}g;

    push @{ $this->path }, $nsp;
    push @{ $this->prefix }, $ns;

    return $this;
}

sub path_string {
    my $this = shift;

    return join(":", @{ $this->path });
}

sub DEMOLISH {
    my $this = shift;

    $this->safe_talk(sub {

        for my $cr (@{ $this->cleanup }) {
            eval { $cr->($this); 1} or warning "during cleanup";
        }

    }, no_restore => 1 );

    return;
}

sub BUILD {
    my $this = shift;
    my $term = Term::ReadLine->new($this->name);

    # XXX: I hate ornaments, but this should probably be an option later
    eval { $term->ornaments('', '', '', '') };
    $this->term( $term );

    push @{ $this->cleanup }, sub { shift->save_history };

    return;
}

sub rebuild_parser {
    my $this = shift;

    my $parser = Term::ReadLine::CLISH::Parser->new(path=>$this->path, prefix=>$this->prefix);
    $this->parser( $parser );
    debug "path: " . $this->path_string if $ENV{CLISH_DEBUG};

    return $this;
}

sub config {
    my $this = shift;
    my $file = shift;
    my $dir  = File::HomeDir->my_dist_config( $this->name, { create => 1 } );

    return $dir unless $file;
    return File::Spec->catfile($dir, $file);
}

sub run {
    my $this = shift;

    install_generic_message_handlers();

    $this->init_vdb;
    $this->init_history;
    $this->rebuild_parser;
    $this->attach_sigint;
    $this->attach_completion_whirlygigs;

    info "Welcome to " . $this->name . " v" . $this->version;

    INPUT: while( not $this->done ) {
        $::THIS_CLISH = $this;

        my $prompt = $this->prompt;
        $_ = $this->term->readline($prompt);
        last INPUT unless defined;
        s/^\s*//; s/\s*$//; s/[\r\n]//g;

        if( my ($cmd, $args) = $this->parser->parse_for_execution($_) ) {
            eval {

                $cmd->exec( $args );

            1} or error "executing $cmd";
        }
    }
}

sub history_location {
    my $this = shift;

    return $this->var_true_or_default( history_location => $this->config("history.txt") );
}

sub init_vdb {
    my $this = shift;
    my $y = tie my %y, 'Tie::YAML' => $this->config("vdb.yaml");

    $this->vdb( $y );

    if( my $h = $y->{ENV} ) {
        for my $k (keys %$h) {
            $ENV{$k} = $h->{$k};
        }
    }

    push @{ $this->cleanup }, sub {
        my $this = shift;
        my $h = $this->var('ENV') || {};
        my $save_env = $this->var_or_default( save_env_re => "^CLISH_" );
           $save_env = $this->varor_default( save_env_re => "^CLISH_" );
           # XXX: make var_exists_or_default
           # XXX: make var_true_or_default

        unless( eval { qr($save_env); 1 } ) {
            warning "with save_env_re=$save_env", scrub_last_error();
            $save_env = qr(^CLISH_);
        }

        for my $k (grep { $_ =~ $save_env } keys %ENV) {
            $h->{$k} = $ENV{$k};
        }

        $this->var(ENV=>$h);
    };

    return $this;
}

sub init_history {
    my $this = shift;
    my $term = $this->term;

    if( $term->can("ReadHistory") ) {
        my $hl = $this->history_location;
        my $hl_desc = "history file";

        if( $ENV{HOME} and $hl =~ m{/} ) {
            # probably unix-y
            $hl_desc = $hl;
            $hl_desc =~ s/^$ENV{HOME}/~/;
        }

        $term->ReadHistory($hl);

        info "[loaded " . int($term->GetHistory) . " command(s) from $hl_desc]";
    }

    $term->StifleHistory(100) if $term->can("StifleHistory");

    return $this;
}

sub save_history {
    my $this = shift;
    my $term = $this->term;

    if( $term->can("WriteHistory") ) {
        my $hl = $this->history_location;
        eval { $term->write_history($hl); 1 } or warning( scrub_last_error() );
    }

    return $this;
}

sub safe_talk {
    my $this = shift;
    my $code = shift;
    my %opt  = @_;
    my $term = $this->term;
    
    # sometimes, during global destruction, $term will be undefined
    return unless defined $term;

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

    return $this if $opt{no_restore};

    $term->modifying;
    $term->set_prompt(shift @save);
    @{ $attribs }{qw(line_buffer point end)} = @save;
    $term->redisplay;

    return $this;
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

    return $this;
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

    return $this;
}

1;

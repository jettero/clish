package Term::ReadLine::CLISH;

=encoding UTF-8
=head1 NAME

Term::ReadLine::CLISH — command line interface shell

=cut

=head1 SYNOPSIS

    XXX: Cut from example/*

=cut

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Term::ReadLine;
use Term::ReadLine::CLISH::MessageSystem;
use Term::ReadLine::CLISH::InputModel;
use File::Spec;
use File::HomeDir;
use Tie::YAML;
use Text::Table;
use POSIX qw(sigaction SIGINT SIGTSTP);
use common::sense;

our $VERSION = '0.0000'; # string for the CPAN

subtype 'CLISHModel', as 'Term::ReadLine::CLISH::InputModel';
subtype 'CLISHModelStack', as 'ArrayRef[CLISHModel]';

has qw(name is rw isa Str default) => "CLISH";
has qw(version is rw isa Str default) => $VERSION;
has qw(vdb is rw isa Tie::YAML);
has qw(term is rw isa Term::ReadLine::Stub);
has qw(done is rw isa Bool);
has qw(cleanup is rw isa ArrayRef[CodeRef] default) => sub { [sub { info "bye" }] };
has qw(models is rw isa CLISHModelStack default), sub { [Term::ReadLine::CLISH::InputModel->new] };

__PACKAGE__->meta->make_immutable;

sub push_model {
    my $this = shift;

    if( my @mobj = grep { eval { $_->isa("Term::ReadLine::CLISH::InputModel")} } @_ ) {
        push @{$this->models}, @mobj;
        return $this;
    }

    my $model_class = @_ % 2 ? shift : "Term::ReadLine::CLISH::InputModel";
    my %opt = @_;

    $opt{prompt} ||= $this->prompt;
    $opt{path}   ||= $this->path;
    $opt{prefix} ||= $this->prefix;

    push @{$this->models}, Term::ReadLine::CLISH::InputModel->new(%opt);

    $this->rebuild_parser;

    if( $ENV{CLISH_DEBUG} ) {
        debug "pushed a new input model:";
        debug " - new prefix = [" . join(", ", @{$this->prefix}) . "]";
        debug " - new path = [" . join(", ", @{$this->path}) . "]";
        debug " - new prompt = \"" . $this->prompt . "\"";
    }

    return $this;
}

sub pop_model {
    my $this = shift;
    my $m_ar = $this->models;
    my $item = pop @$m_ar;

    if( $ENV{CLISH_DEBUG} ) {
        debug "popped a model off the stack:";

        if( @$m_ar ) {
            debug " - new prefix = [" . join(", ", @{$this->prefix}) . "]";
            debug " - new path = [" . join(", ", @{$this->path}) . "]";
            debug " - new prompt = \"" . $this->prompt . "\"";

        } else {
            debug " - (nothing left on the stack)";
        }
    }

    return $item;
}

sub model_depth {
    my $this = shift;
    my $m_ar = $this->models;

    return 0 + @$m_ar;
}

*has_model = \&model_depth;

# XXX: read methods from the CLISHModelStack directly, rather than enumerating them like this
for my $f (qw(parser prompt path prefix rebuild_parser path_string)) {
    no strict 'refs';
    *{$f} = sub {
        my $this = shift;
        my $mod  = eval { @{$this->models}[-1] };

        unless( $mod ) {
            my ($p,$f,$l) = caller;
            die "tried to invoke $f on an empty model stack at $f line $l\n";
        }

        return $mod->$f(@_);
    };
}

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

sub DEMOLISH {
    my $this = shift;

    $this->safe_talk(sub {

        for my $cr (@{ $this->cleanup }) {
            eval { $this->$cr; 1 } or warning "during cleanup";
        }

    }, no_restore => 1 );

    return;
}

sub BUILD {
    my $this = shift;
    my $term = Term::ReadLine->new($this->name);

    # XXX: I hate ornaments, but this should probably be an option later
    eval { $term->ornaments('', '', '', '') };

    $term->add_defun('handle-qmark', sub { $this->handle_qmark(@_) });
    $term->bind_key( ord('?') => 'handle-qmark' );

    $this->term( $term );

    push @{ $this->cleanup }, sub { $_[0]->save_history };

    return;
}

sub handle_qmark {
    my $this = shift;

    $this->safe_talk(sub{
        my ($buffer, $point, $end) = @_;

        if( my ($cmds, $args) = $this->parser->parse_for_help($buffer) ) {
            use Data::Dump::Filtered qw(add_dump_filter); use Data::Dump qw(dump);
            add_dump_filter(sub{ my ($ctx, $obj) = @_; return { dump => "q«$obj»" } if $ctx->is_blessed; });

            debug dump({cmds=>$cmds, args=>$args, bpe=>[$buffer, $point, $end]}) if $ENV{CLISH_DEBUG};
            help Text::Table->new->load( map { [ $_->name, $_->help ] } @$cmds);
        }
    });
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
    $this->attach_sigstop;
    $this->attach_completion_whirlygigs;

    info "Welcome to " . $this->name . " v" . $this->version;

    INPUT: while( not $this->done ) {
        my $prompt = $this->prompt;

        # XXX: $prompt = evaluate_prompt_specials( $prompt );
        # actually, we should do this in the InputModel::prompt() becaue it
        # should really get evaluated any time we print the prompt (e.g.,
        # safe_talk()) — or maybe we just do the evaluationin both places...
        # hrm.

        $_ = $this->term->readline("$prompt" || "clish>");
        say unless defined $_;

        if( not defined ) {
            if( $this->pop_model and $this->has_model ) {
                next INPUT;
            }

            last INPUT;
        }

        s/^\s*//; s/\s*$//; s/[\r\n]//g;

        $::THIS_CLISH = $this;

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
    my @save = @{ $attribs }{qw(line_buffer point end)};

    # NOTE: mostly from Term::ReadLine::Gnu's eg/perlsh; but to be
    # fair, tried to copy AnyEvent::ReadLine::Gnu first — I just
    # couldn't get that to work without warnings that dorked it all up.
    # I think he needs to add {end} to his hide() / show().

    $term->modifying;
    @{ $attribs }{qw(line_buffer point end)} = ("",0,0);
    $term->set_prompt("");
    $term->redisplay;

    $code->(@save);

    return $this if $opt{no_restore};

    $term->modifying;
    $term->set_prompt($this->prompt);
    @{ $attribs }{qw(line_buffer point end)} = @save;
    $term->redisplay;

    return $this;
}

sub attach_sigstop {
    my $this = shift;

    if( $this->term->isa("Term::ReadLine::Gnu") ) {
        my ($last, $count);

        sigaction SIGTSTP, new POSIX::SigAction sub {
            $this->safe_talk(sub{
                $this->pop_model while $this->model_depth > 1;
            });

        } or die "Error setting SIGINT handler: $!\n";

    }

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
            $this->safe_talk(sub{ wtf("\$#m = ($#m); \$attribs{cac}=«$attribs->{completion_append_character}»") });
        }

        for(; $i < $#m ; $i++ ) {
            if( $m[$i] =~ m/^(['"]*)\Q$text/ ) {
                $return = $m[$i];
                last;
            }
        }

        $this->safe_talk(sub{ wtf("  \$i=$i; \$m[$i] = \$return = $return") });
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

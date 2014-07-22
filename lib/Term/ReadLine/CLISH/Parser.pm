
package Term::ReadLine::CLISH::Parser;

use Moose;
use namespace::autoclean;
use Moose::Util::TypeConstraints;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use Parse::RecDescent;
use Module::Pluggable::Object;
use common::sense;
use constant {
    PARSE_COMPLETE => 1,

    PARSE_RETURN_TOKENS  => 0,
    PARSE_RETURN_CMDS    => 1,
    PARSE_RETURN_ARGSS   => 2,
    PARSE_RETURN_STATUSS => 3,
};

subtype 'pathArray', as 'ArrayRef[Str]';
coerce 'pathArray', from 'Str', via { [ split m/[:; ]+/ ] };

subtype 'prefixArray', as 'ArrayRef[Str]';
coerce 'prefixArray', from 'Str', via { [ $_ ] };

subtype 'cmd', as 'Term::ReadLine::CLISH::Command';
subtype 'cmdArray', as 'ArrayRef[cmd]';
coerce 'cmdArray', from 'cmd', via { [ $_ ] };

has qw(path is rw isa pathArray coerce 1);
has qw(prefix is rw isa prefixArray);
has qw(commands is rw isa cmdArray coerce 1);
has qw(tokenizer is rw isa Parse::RecDescent);

has qw(output_prefix is rw isa Str default) => "% ";

__PACKAGE__->meta->make_immutable;


use Data::Dump::Filtered qw(add_dump_filter); use Data::Dump qw(dump);
add_dump_filter(sub{ my ($ctx, $obj) = @_; return { dump => "q«$obj»" } if $ctx->is_blessed; });

=head1 C<parse_for_help>

  # XXX: I AM A STUB AND YOU ARE READING ME

=cut

sub parse_for_help {
    my $this = shift;
    my $line = shift;

    my ($tokout, $cmds, $argss, $statuss) = $this->parse($line, heuristic_validation=>1);

    if( $tokout->{cruft} ) {
        error "miscellaneous cruft on end of line", $tokout->{cruft};
        return;
    }

    wtf "parse_for_help result", "\n" . dump({
        line    => $line,
        tokout  => $tokout,
        cmds    => $cmds,
        argss   => $argss,
        statuss => $statuss,

    }) . "\n";

    return $cmds;
}

=head1 C<parse_for_tab_completion>

  # XXX: I AM A STUB AND YOU ARE READING ME

=cut

sub parse_for_tab_completion {
    my $this = shift;
    my $line = shift;

    my ($tokout, $cmds, $argss, $statuss) = $this->parse($line, heuristic_validation=>1, no_untagged=>1);
    my @things_we_could_pick;

    my $still_working_on_current_word = $line !~ m/\s+\z/;
    my @tok = eval{ @{ $tokout->{tokens} } };

    $tokout->{cruft} = 1 if !$still_working_on_current_word
        and grep {!($_ == PARSE_COMPLETE or m/required arguments omitted/)} @$statuss;

    if( $tokout->{cruft} ) {
        debug "[pftc] has cruft, no completions" if $ENV{CLISH_DEBUG};
        @things_we_could_pick = (); # we'll never figure this out, it's a string or something

    } elsif( not @tok ) {
        # we're probably working on a command
        @things_we_could_pick = $this->command_names;
        debug "[pftc] no tokens, completions are commands", join(", ", @things_we_could_pick) if $ENV{CLISH_DEBUG};

    } elsif( @tok == 1 and $still_working_on_current_word ) {
        @things_we_could_pick = $this->command_names;
        @things_we_could_pick = grep { m/^\Q$tok[0]/ } @things_we_could_pick;
        debug "[pftc] commands matching token \"$tok[0]\"", join(", ", @things_we_could_pick) if $ENV{CLISH_DEBUG};

    } elsif( @tok ) {
        my %K;
        for my $i ( 0 .. $#$cmds ) {
            while( my ($arg_tag, $arg_obj) = each %{ $argss->[$i] } ) {
                $K{$arg_tag} = 1
                    if $still_working_on_current_word
                       ? $arg_tag =~ m/^\Q$tok[-1]/
                       : not grep {$arg_tag ne $_->name} map {@$_} @{$tokout->{tokmap}};
                       ;
            }
        }

        @things_we_could_pick = keys %K;
        if( $ENV{CLISH_DEBUG} ) {
            if( $still_working_on_current_word ) {
                debug "[pftc] argument tags matching token \"$tok[-1]\"", join(", ", @things_we_could_pick);

            } else {
                debug "[pftc] argument tags not yet filled \"$tok[-1]\"", join(", ", @things_we_could_pick);
            }
        }

    } else {
        error "[pftc] unexpected logical conclusion during tab-completion parsing" if $ENV{CLISH_DEBUG};
    }

    return wantarray ? @things_we_could_pick : \@things_we_could_pick;
}

=head1 C<parse_for_execution()>

This method is usually invoked as follows

        if( my ($cmd, $args) = $this->parser->parse_for_execution($line) ) {
            eval {

                $cmd->exec( $args );

            } or die error "while executing $cmd"; # read from $@ for us
        }

        # else { no need to do anything here, just read the next line }

If the text in C<$line> cannot be parsed unambiguously to a C<$cmd> object with
appropriate arguments, then it will generate and print appropriate errors for
the line.

=cut

sub parse_for_execution {
    my $this = shift;
    my $line = shift;
    my ($tokout, $cmds, $argss, $statuss) = $this->parse($line);

    $line =~ s/^\s+//;
    $line =~ s/\s+$//;

    return unless $line;

    if( not $tokout or not $tokout->{tokens} ) {
        error "tokenizing input"; # the tokenizer will have left an argument in $@
        return;
    }

    if( $tokout->{cruft} ) {
        error "miscellaneous cruft on end of line", $tokout->{cruft};
        return;
    }

    return unless @{$tokout->{tokens}};

    if( @$cmds == 1 ) {
        if( $statuss->[0] == PARSE_COMPLETE ) {
            debug "selected $cmds->[0] for execution, executing final validation" if $ENV{CLISH_DEBUG};

            $cmds->[0]->validate($argss->[0]) or return;
            return ($cmds->[0], $argss->[0]);

        } elsif ($statuss->[0]) {
            error "parsing $cmds->[0] arguments", $statuss->[0];
            return;
        }
    }

    elsif( @$cmds ) {
        error "\"$tokout->{tokens}[0]\" could be any of these", join(", ", map { $_->name } @$cmds);

    } else {
        error "parsing input", "unknown command '$tokout->{tokens}[0]'";
    }

    return;
}

=head1 C<parse()>

This is a support function, normally invoked as follows.

    my ($tokout, $cmds, $args_star, $statuses) = $this->parse($line, opt1=>optval, opt2=>optval2);

The C<parse> method returns an hashref with keys C<tokens> and C<cruft> from
the line in C<$tokout>.  C<tokens> is an arrayref of tokens that parsed
correctly, and C<cruft> is left-over unparsable things from the line (which is
hopefully useful for tab completion and context help).

It also returns an arrayref of possible commands in C<$cmds>, an arrayref of
hashrefs (each hashref the parsed arguments for the commands as
C<< tag=>value >> pairs), and an arrayref of C<$statuses>.

The statuses are either the value C<PARSE_COMPLETE> or a string representing
any errors with intepreting the line as an invocation of the command at the
same index.

Example:

    if( @$cmds == 1 and $statuses->[0] == PARSE_COMPLETE ) {
        info "executing $cmds->[0]";
        $cmds->[0]->exec( $args_star->[0] );
    }

Exception: if the tokenizer (an actual parser) can't make sense of the line,
C<parse> will return an empty list and leave the parse error in C<$@>.  Note
that C<error()> is an alias for L<Term::ReadLine::CLISH::Error>'s (new/spew)
that consumes C<$@> if invoked with a single argument.

    if( not $tokout ) {
        error "parse error";
        return;
    }

    if( @$cmds ... PARSE_COMPLETE )
        ...

=cut

sub find_command_by_name {
    my $this = shift;
    my $name = lc shift;

    for(@{ $this->commands }) {
        return $_ if $_->name eq $name;
    }

    return;
}

sub parse {
    my $this = shift;
    my $line = shift;

    my %vopt = @_;
    $vopt{final_validation}   = $vopt{full_validation}      = 0;
    $vopt{initial_validation} = $vopt{heuristic_validation} = 1;

    my @return = ({}, [], [], []);

    if( $line =~ m/\S/ ) {
        my $prefix    = $this->output_prefix;
        my $tokenizer = $this->tokenizer;
        my $tokout    = $return[0] = $tokenizer->tokens( $line );

        return unless $tokout and $tokout->{tokens};
            # careful to not disrupt $@ on the way up XXX document this type of error (including $@)

        debug do { local $" = "> <"; "cruft: \"$tokout->{cruft}\" tokens: <@{$tokout->{tokens}}>" }
            if $ENV{CLISH_DEBUG};

        if( my @TOK = @{$tokout->{tokens}} ) {
            my ($cmd_token, @arg_tokens) = @TOK;

            my @cmds = grep {substr($_->name, 0, length $cmd_token) eq $cmd_token} @{ $this->commands };

            $return[ PARSE_RETURN_CMDS ] = \@cmds;

            for my $cidx ( 0 .. $#cmds ) {
                my $cmd = $cmds[$cidx];
                my @cmd_args = @{ $cmd->arguments };

                debug "cmd_args: @cmd_args" if $ENV{CLISH_DEBUG};

                $return[ PARSE_RETURN_ARGSS ][ $cidx ] = my $out_args = +{ map {($_->name,$_)} @cmd_args };

                # NOTE: it's really not clear what the best *generalized* arg
                # processing strategy is best.  For now, I'm just doing it
                # really dim wittedly.

                my $tokmap = $tokout->{tokmap}[$cidx] ||= [];
                $this->_try_to_eat_tok( $cmd,$out_args,$tokmap => \@cmd_args,\@arg_tokens, %vopt );

                # if there are remaining arguments (extra tokens), reject the command
                if( my @extra = map {"\"$_\""} @arg_tokens ) {
                    local $" = ", ";
                    $return[ PARSE_RETURN_STATUSS ][ $cidx ] = "unrecognized tokens (@extra) on line";
                    next;
                }

                # if some of the arguments are missing, reject the command
                # (we check this again from cmd->validate in
                # parse_for_execution, but we immediately print the error
                # there; this is more of a hint, since we don't know if the
                # final checks will even pass))
                if( my @req = grep { $_->required } @cmd_args ) {
                    local $" = ", ";                           # NOTE: used as an error code above
                    $return[ PARSE_RETURN_STATUSS ][ $cidx ] = "required arguments omitted (@req)";
                    next;
                }

                $return[ PARSE_RETURN_STATUSS ][ $cidx ] = PARSE_COMPLETE;
            }
        }
    }

    return @return;
}


sub _try_to_eat_tok {
    my $this = shift;
    my ( $cmd,$out_args,$tokmap => $cmd_args,$arg_tokens, %vopt ) = @_;

    # $cmd is the command object we're with which we're currently working
    # $out_args is the hashref of return arguments (populated by add_copy_with_token_to_hashref)
    # $cmd_args are the command args not yet consumed by the parse (spliced out)
    # $arg_tokens are the tokens representing args not yet consumed by the parse (spliced out)

    $::THIS_CLISH_PARSER = $this;

    EATER: {
        if( @$arg_tokens ) {
            if( @$arg_tokens > 1 ) {
                redo EATER if
                $this->_try_to_eat_tagged_arguments( @_ )
            }

            unless( $vopt{no_untagged} ) {
                redo EATER if
                $this->_try_to_eat_untagged_arguments( @_ )
            }
        }
    }
}

sub _try_to_eat_tagged_arguments {
    my $this = shift;
    my ( $cmd,$out_args,$tokmap => $cmd_args,$arg_tokens, %vopt ) = @_;

    my $tok  = $arg_tokens->[0];
    my $ntok = $arg_tokens->[1];

    my @matched_cmd_args_idx = # the indexes of matching Args
        grep { $cmd_args->[$_]->validate($ntok, %vopt) }
        grep { substr($cmd_args->[$_]->name, 0, length $tok) eq $tok }
        0 .. $#$cmd_args;

    if( @matched_cmd_args_idx == 1 ) {
        my $midx = $matched_cmd_args_idx[0];

        # consume the items
        my ($arg) = splice @$cmd_args, $midx, 1;

        if( $arg->is_flag ) {
            my ($nom) = splice @$arg_tokens, 0, 1;

            debug "[is_flag] ate arg=$arg and tok-nom=<$nom>" if $ENV{CLISH_DEBUG};

            $arg->add_copy_with_token_to_hashref( $out_args => $tok );
            push $tokmap, $arg;

        } else {
            my @nom = splice @$arg_tokens, 0, 2;

            { local $" = ", "; debug "[tagged] ate arg=$arg and tok-nom=<@nom>" if $ENV{CLISH_DEBUG}; }

            # populate the option in argss
            $arg->add_copy_with_token_to_hashref( $out_args => $ntok );
            push $tokmap, $arg,$arg;
        }

        return 1; # returning true reboots the _try*
    }

    else {
        # XXX: it's not clear what to do here should we explain for every
        # (un)matching command?  how often will we really have the
        # (non)ambiguity of options become the minimial liguistic difference
        # between two or more commands?

        if( @matched_cmd_args_idx) {
            my @matched = map { $cmd_args->[$_] } @matched_cmd_args_idx;

            warning "\"$tok $ntok\" could be any of", "@matched";
        }

        # I think we don't want to show anything in this case
        # else { debug "$tok failed to resolve to anything" }
    }

    return;
}

sub _try_to_eat_untagged_arguments {
    my $this = shift;
    my ( $cmd,$out_args,$tokmap => $cmd_args,$arg_tokens, %vopt ) = @_;
    my $tok = $arg_tokens->[0];

    my @matched_cmd_args_idx = # the idexes of matching Args
        grep { $cmd_args->[$_]->validate($tok, %vopt) }
        grep { $cmd_args->[$_]->tag_optional or (
            $cmd_args->[$_]->is_flag and
            substr($cmd_args->[$_]->name, 0, length $tok) eq $tok
        ) }
        0 .. $#$cmd_args;

    if( @matched_cmd_args_idx == 1 ) {
        my $midx = $matched_cmd_args_idx[0];

        # consume the items
        my ($arg) = splice @$cmd_args, $midx, 1;
        my ($nom) = splice @$arg_tokens, 0, 1;

        debug "[untagged] ate arg=$arg and tok-nom=<$nom>" if $ENV{CLISH_DEBUG};

        # populate the option in argss
        $arg->add_copy_with_token_to_hashref( $out_args => $tok );
        push $tokmap, $arg;

        return 1; # returning true reboots the _try*
    }

    else {
        # XXX: (see "not clear" comment above)

        if( @matched_cmd_args_idx ) {
            my @matched = map { $cmd_args->[$_] } @matched_cmd_args_idx;

            warning "\"$tok\" could be any of", "@matched";
        }

        # I think we don't want to show anything in this case
        # else { debug "$tok failed to resolve to anything" }
    }

    return;
}

sub BUILD {
    my $this = shift;
       $this->reload_commands;
       $this->build_parser;
}

sub build_parser {
    my $this = shift;

    my $prd = Parse::RecDescent->new(q
        tokens: token(s?) cruft /$/ {
            $return = {
                tokens => $item[1],
                cruft  => $item[2],
            }
        }

        token: word | string
        cruft: /\s*/ /.*/   { $return = $item[2] }
        word:  /[\w\d_.-]+/ { $return = $item[1] }

        string: "'" /[^']*/ "'" { $return = $item[2] }
              | '"' /[^"]*/ '"' { $return = $item[2] }
    );

    $this->tokenizer($prd);
}

sub command_names {
    my $this = shift;
    my @cmd  = @{ $this->commands };

    my %h;
    return sort map { $_->name } grep { !$h{$_}++ } @cmd;
}

sub reload_commands {
    my $this = shift;

    # XXX: 0 psh> my @prefix = qw(example::cmds
    # Term::ReadLine::CLISH::Library::Commands); use lib 'lib'; use
    # Module::Pluggable::Object; $finder =
    # Module::Pluggable::Object->new(search_path=>\@prefix,
    # search_dirs=>['example', 'lib'], only=>do { local $"="|";
    # qr{^(?:@prefix)::[^:]+\z} }), [ $finder->plugins ];

    my $prefixar = $this->prefix;
    my $finder = Module::Pluggable::Object->new(
        search_dirs => $this->path,
        search_path => $prefixar,
        instantiate => "new",

        only => do { local $" = "|"; qr{^(?:@$prefixar)::[^:]+\z} }
    );

    my @cmds = $finder->plugins;

    my $c = @cmds;
    my $p = $c == 1 ? "" : "s";

    info "[loaded $c command$p from PATH]";
    debug "@cmds" if $ENV{CLISH_DEBUG};

    $this->commands(\@cmds);
}

1;

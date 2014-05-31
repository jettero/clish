
package Term::ReadLine::CLISH::Parser;

use Moose;
use namespace::autoclean;
use Moose::Util::TypeConstraints;
use Term::ReadLine::CLISH::MessageSystem;
use Parse::RecDescent;
use File::Find::Object;
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
has qw(cmds is rw isa cmdArray coerce 1);
has qw(tokenizer is rw isa Parse::RecDescent);

has qw(output_prefix is rw isa Str default) => "% ";

__PACKAGE__->meta->make_immutable;

=head1 C<parse_for_tab_completion>

  # XXX: I AM A STUB AND YOU ARE READING ME

=cut

sub parse_for_tab_completion {
    my $this = shift;
    my $line = shift;

    my @things_we_could_pick;
    my ($tokout, $cmds, $argss, $statuss) = $this->parse($line, heuristic_validation=>1);

    if( $tokout->{cruft} ) {
        @things_we_could_pick = (); # we'll never figure this out, it's a string or something

    } else {
        my @TOK = @{$tokout->{tokens}};

        if( @TOK > 1 ) {
            my @args_with_values;  # XXX: apply filters here, find applicable args
            my @args_without_values;

        } else {
            # XXX: we're matching commands in the 0 or the 1 case, so populate like this
            my $m = $TOK[0];
            @things_we_could_pick = grep { m/^\Q$m/ } @cmds;
        }
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
            debug "selected $cmds->[0] for execution" if $ENV{CLISH_DEBUG};
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

You can pass options to C<parse()> that get passed to the validator subs.
Commands can use these args to alter their validation strategies.  For now, the
only CLISH-known option is C<heuristic_validation> (used by
L<parse_for_tab_completion()>).

=over

=item C<heuristic_validation>

Tell validation functions to avoid long operations and error generation, to
just assume arguments are acceptable if they more or less contain the right
characters.

=back

=cut

sub parse {
    my $this = shift;
    my $line = shift;
    my %options = @_;

    my @return = ([], [], [], []);

    if( $line =~ m/\S/ ) {
        my $prefix    = $this->output_prefix;
        my $tokenizer = $this->tokenizer;
        my $tokout    = $tokenizer->tokens( $line );

        return unless $tokout and $tokout->{tokens};
            # careful to not disrupt $@ on the way up XXX document this type of error (including $@)

        debug do { local $" = "> <"; "cruft: \"$tokout->{cruft}\" tokens: <@{$tokout->{tokens}}>" }
            if $ENV{CLISH_DEBUG};

        if( my @TOK = @{$tokout->{tokens}} ) {
            my ($cmd_token, @arg_tokens) = @TOK;

            $return[0] = $tokout;
            my @cmds = grep {substr($_->name, 0, length $cmd_token) eq $cmd_token} @{ $this->cmds };

            $return[ PARSE_RETURN_CMDS ] = \@cmds;

            for my $cidx ( 0 .. $#cmds ) {
                my $cmd = $cmds[$cidx];
                my @cmd_args = @{ $cmd->arguments };

                debug "cmd_args: @cmd_args" if $ENV{CLISH_DEBUG};

                $return[ PARSE_RETURN_ARGSS ][ $cidx ] = my $out_args = +{ map {($_->name,$_)} @cmd_args };

                # NOTE: it's really not clear what the best *generalized* arg
                # processing strategy is best.  For now, I'm just doing it
                # really dim wittedly.

                $this->_try_to_eat_tok( $cmd,$out_args => \@cmd_args,\@arg_tokens );

                # if there are remaining arguments, reject the command
                if( my @extra = map {"\"$_\""} @arg_tokens ) {
                    local $" = ", ";
                    $return[ PARSE_RETURN_STATUSS ][ $cidx ] = "unrecognized tokens on line (@extra)";
                    next;
                }

                # if some of the arguments are missing, reject the command
                if( my @req = grep { $_->required } @cmd_args ) {
                    local $" = ", ";
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
    my ( $cmd,$out_args => $cmd_args,$arg_tokens ) = @_;

    # $cmd is the command object we're with which we're currently working
    # $out_args is the hashref of return arguments (populated by add_copy_with_value_to_hashref)
    # $cmd_args are the command args not yet consumed by the parse (spliced out)
    # $arg_tokens are the tokens representing args not yet consumed by the parse (spliced out)

    EATER: {
        if( @$arg_tokens ) {
            if( @$arg_tokens > 1 ) {
                redo EATER if
                $this->_try_to_eat_tagged_arguments( @_ )
            }

            redo EATER if
            $this->_try_to_eat_untagged_arguments( @_ )
        }
    }
}

sub _try_to_eat_tagged_arguments {
    my $this = shift;
    my ( $cmd,$out_args => $cmd_args,$arg_tokens ) = @_;

    my $tok  = $arg_tokens->[0];
    my $ntok = $arg_tokens->[1];

    my @lv; # validated values for the array matching arrays
    my @ev; # errors from the validation

    my @matched_cmd_args_idx = # the indexes of matching Args
        grep { undef $@; my $v = $cmd_args->[$_]->validate('XXX: we need %options here somehow' $ntok);
               $ev[$_] = $@; $lv[$_] = $v if $v; $v }
        grep { substr($cmd_args->[$_]->name, 0, length $tok) eq $tok }
        0 .. $#$cmd_args;

    if( @matched_cmd_args_idx == 1 ) {
        my $midx = $matched_cmd_args_idx[0];

        # consume the items
        my ($arg) = splice @$cmd_args, $midx, 1;
        my @nom   = splice @$arg_tokens, 0, 2;

        { local $" = "> <"; debug "ate $arg with <@nom>" if $ENV{CLISH_DEBUG}; }

        # populate the option in argss
        $arg->add_copy_with_value_to_hashref( $out_args => $lv[$midx] );

        return 1; # returning true reboots the _try*
    }

    elsif( my @dev = grep {defined $ev[$_]} 0 .. $#ev ) {
        warning "trying to use '$tok' => '$ntok' to fill $cmd\'s $cmd_args->[$_]",
            $ev[$_] for @dev;
    }

    else {
        # XXX: it's not clear what to do here
        # should we explain for every (un)matching
        # command?

        if( @matched_cmd_args_idx) {
            my @matched = map { $cmd_args->[$_] } @matched_cmd_args_idx;
            debug "$tok failed to resolve to a single validated tagged option,"
                . " but initially matched: @matched" if $ENV{CLISH_DEBUG};
        }

        # I think we don't want to show anything in this case
        # else { debug "$tok failed to resolve to anything" }
    }

    return;
}

sub _try_to_eat_untagged_arguments {
    my $this = shift;
    my ( $cmd,$out_args => $cmd_args,$arg_tokens ) = @_;
    my $tok = $arg_tokens->[0];

    my @lv; # validated values for the array matching arrays
    my @ev; # errors from the validation

    my @matched_cmd_args_idx = # the idexes of matching Args
        grep { undef $@; my $v = $cmd_args->[$_]->validate('XXX: we need %options here somehow'$tok);
               $ev[$_] = $@; $lv[$_] = $v if defined $v; defined $v }
        grep { $cmd_args->[$_]->tag_optional }
        0 .. $#$cmd_args;

    if( @matched_cmd_args_idx == 1 ) {
        my $midx = $matched_cmd_args_idx[0];

        # consume the items
        my ($arg) = splice @$cmd_args, $midx, 1;
        my ($nom) = splice @$arg_tokens, 0, 1;

        { local $" = "> <"; debug "ate $arg with <$nom>" if $ENV{CLISH_DEBUG}; }

        # populate the option in argss
        $arg->add_copy_with_value_to_hashref( $out_args => $lv[$midx] );

        return 1; # returning true reboots the _try*
    }

    elsif( my @dev = grep {defined $ev[$_]} 0 .. $#ev ) {
        warning "trying to use '$tok' to fill $cmd\'s $cmd_args->[$_]",
            $ev[$_] for @dev;
    }

    else {
        # XXX: it's not clear what to do here should we
        # explain for every (un)matching command?

        if( @matched_cmd_args_idx ) {
            my @matched = map { $cmd_args->[$_] } @matched_cmd_args_idx;
            debug "$tok failed to resolve to a single validated tagged option,"
                . " but initially matched: @matched" if $ENV{CLISH_DEBUG};
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
        tokens: token(s?) { $return = { tokens => $item[1] } } cruft { $return->{cruft} = $item[3] } /$/
        cruft: /\s*/ /.*/ { $return = $item[2] }
        token: word | string
        word: /[\w\d_.-]+/ { $return = $item[1] }

        string: "'" /[^']*/ "'" { $return = $item[2] }
              | '"' /[^"]*/ '"' { $return = $item[2] }
    );

    $this->tokenizer($prd);
}

sub command_names {
    my $this = shift;
    my @cmd  = @{ $this->cmds };

    my %h;
    return sort map { $_->name } grep { !$h{$_}++ } @cmd;
}

sub prefix_regex {
    my $this = shift;
    my @prefixes = @{ $this->prefix };
    s{::}{/}g for @prefixes;
    local $" = "|";
    my $RE = qr{(?:@prefixes)};
    return $RE;
}

sub reload_commands {
    my $this = shift;
    my $PATH = $this->path;
    my $prreg = $this->prefix_regex;

    my $orig_warn = $SIG{__WARN__};
    $SIG{__WARN__} = sub {
        debug("reload_commands hid this warning: $_[0]") if $ENV{CLISH_DEBUG};
    };

    my @cmds;

    for my $path (@$PATH) {
        my $ffo = File::Find::Object->new({}, $path);

        debug "trying to load commands from $path using $prreg" if $ENV{CLISH_DEBUG};

        while( my $f = $ffo->next ) {
            debug "    considering $f" if $ENV{CLISH_DEBUG};

            if( -f $f and my ($ppackage) = $f =~ m{($prreg.*?)\.pm} ) {
                my $package = $ppackage; $package =~ s{/}{::}g;
                my $newcall = "use $package; $package" . "->new";
                my $obj     = eval $newcall;

                if( $obj ) {
                    if( $obj->isa("Term::ReadLine::CLISH::Command") ) {
                        debug "    loaded $ppackage as $package" if $ENV{CLISH_DEBUG};
                        push @cmds, $obj;

                    } else {
                        debug "    loaded $ppackage as $package — but it didn't appear to be a Term::ReadLine::CLISH::Command" if $ENV{CLISH_DEBUG};
                    }

                } else {
                    error "trying to load '$ppackage' as '$package'";
                }
            }
        }
    }

    my $c = @cmds;
    my $p = $c == 1 ? "" : "s";

    info "[loaded $c command$p from PATH]";

    $SIG{__WARN__} = $orig_warn;

    $this->cmds(\@cmds);
}

1;

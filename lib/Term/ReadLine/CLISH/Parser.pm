
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

sub parse_for_execution {
    my $this = shift;
    my $line = shift;
    my ($tokens, $cmds, $argss, $statuss) = $this->parse($line);

    if( not $tokens ) {
        error "error parsing line"; # the tokenizer will have left an argument in $@
        return;
    }

    return unless @$tokens;

    if( @$cmds == 1 ) {
        if( $statuss->[0] == PARSE_COMPLETE ) {
            debug "selected $cmds->[0] for execution";
            return ($cmds->[0], $argss->[0]);

        } elsif ($statuss->[0]) {
            error "parse error for $cmds->[0]", $statuss->[0];
            return;
        }
    }

    elsif( @$cmds ) {
        error "ambiguous command, \"$tokens->[0]\" could be any of these", join(", ", map { $_->name } @$cmds);

    } else {
        error "parse error", "command not understood";
    }

    return;
}

=head1 C<parse()>

    my ($tokens, $cmds, $args_star, $statuses) = $this->parse($line);

The C<parse> method returns an arrayref of tokens from the line in C<$tokens>,
an arrayref of possible commands in C<$cmds>, an arrayref of hashrefs (each
hashref the parsed arguments for the commands as C<< tag=>value >> pairs), and
an arrayref of C<$statuses>.

The statuses are either the value C<PARSE_COMPLETE> or a string representing any
errors with intepreting the line as an invocation of the command at the same
index.

Example:

    if( @$cmds == 1 and $statuses->[0] == PARSE_COMPLETE ) {
        info "we should execute $cmds->[0]";
    }

Exception: if the tokenizer (an actual parser) can't make sense of the line,
C<parse> will return an empty list and leave the parse error in C<$@>.

=cut

sub parse {
    my $this = shift;
    my $line = shift;
    my %options;

    my @return = ([], [], [], []);

    if( $line =~ m/\S/ ) {
        my $prefix    = $this->output_prefix;
        my $tokenizer = $this->tokenizer;
        my $tokens    = $tokenizer->tokens( $line );

        return unless $tokens; # careful to not disrupt $@ on the way up XXX document this type of error (including $@)

        debug do { local $" = "> <"; "tokens: <@$tokens>" };

        if( @$tokens ) {
            my ($cmd_token, @arg_tokens) = @$tokens;

            $return[0] = $tokens;
            my @cmds = grep {substr($_->name, 0, length $cmd_token) eq $cmd_token} @{ $this->cmds };

            CMD_LOOP:
            for my $idx ( 0 .. $#cmds ) {
                my $cmd = $cmds[$idx];
                my $opt = {};
                my @cmd_args = @{ $cmd->arguments };

                # NOTE: it's really not clear what the best *generalized* arg
                # processing strategy is best.  For now, I'm just doing it
                # really dim wittedly.

                my @cr = 0 .. $#cmd_args;

                my @req  = grep { $cmd_args[$_]->required     } @cr;
                my @tago = grep { $cmd_args[$_]->tag_optional } @cr;

                my $tok = $arg_tokens[0];
                my @matches_tag = grep { substr($cmd_args[$_]->name, 0, length $tok) eq $tok } @cr;
                my @fills_tago  = grep { $cmd_args[$_]->validate( $tok ) } @tago;

                warn "XXX: do the args";

                # if there are remaining arguments, reject the command
                if( my @extra = map {"\"$_\""} @arg_tokens ) {
                    local $" = ", ";
                    $return[ PARSE_RETURN_STATUSS ][ $idx ] = "extra tokens (@extra) on line";
                }

                # if some of the arguments are missing, reject the command
                if( my @req = grep { $_->required } @cmd_args ) {
                    local $" = ", ";
                    $return[ PARSE_RETURN_STATUSS ][ $idx ] = "required arguments (@req) omitted";
                    next CMD_LOOP;
                }

                push @{ $return[1] }, $cmd;
                push @{ $return[2] }, $opt;
                $return[ PARSE_RETURN_STATUSS ][ $idx ] = PARSE_COMPLETE;
            }
        }
    }

    return @return;
}

sub BUILD {
    my $this = shift;
       $this->reload_commands;
       $this->build_parser;
}

sub build_parser {
    my $this = shift;

    my $prd = Parse::RecDescent->new(q
        tokens: token(s?) { $return = $item[1] } end_of_line
        end_of_line: /$/ | /\s*/ <reject: $text ? $@ = "unrecognized token: $text" : undef>
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

    my @cmds;

    for my $path (@$PATH) {
        my $ffo = File::Find::Object->new({}, $path);

        debug "trying to load commands from $path using $prreg";

        while( my $f = $ffo->next ) {
            debug "    considering $f";

            if( -f $f and my ($ppackage) = $f =~ m{($prreg.*?)\.pm} ) {
                my $package = $ppackage; $package =~ s{/}{::}g;
                my $newcall = "use $package; $package" . "->new";
                my $obj     = eval $newcall;

                if( $obj ) {
                    if( $obj->isa("Term::ReadLine::CLISH::Command") ) {
                        debug "    loaded $ppackage as $package";
                        push @cmds, $obj;

                    } else {
                        debug "    loaded $ppackage as $package — but it didn't appear to be a Term::ReadLine::CLISH::Command";
                    }

                } else {
                    error "    while trying to load '$ppackage as $package'";
                }
            }
        }
    }

    my $c = @cmds;
    my $p = $c == 1 ? "" : "s";

    info "[loaded $c command$p from PATH]";

    $this->cmds(\@cmds);
}

1;

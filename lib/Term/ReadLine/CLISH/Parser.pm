
package Term::ReadLine::CLISH::Parser;

use Moose;
use namespace::autoclean;
use Moose::Util::TypeConstraints;
use Term::ReadLine::CLISH::MessageSystem;
use Parse::RecDescent;
use File::Find::Object;
use common::sense;

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
    my ($tokens, $cmds, $argss) = $this->parse($line);

    if( not $tokens ) {
        error "error parsing line", $tokens;
        return;
    }

    return unless @$tokens;

    if( @$cmds == 1 ) {
        debug "selected $cmds->[0] for execution";
        return ($cmds->[0], $argss->[0]);
    }

    elsif( @$cmds > 1 ) {
        error "ambiguous command, \"$tokens->[0]\" could be any of these", join(", ", map { $_->name } @$cmds);

    } else {
        error "command not understood";
    }

    return;
}

sub parse {
    my $this = shift;
    my $line = shift;
    my %options;

    my @return = ([],[],[]);

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
            for my $cmd ( @cmds ) {
                my $opt = {};
                my @cmd_args = @{ $cmd->arguments };

                # NOTE: it's really not clear what the best *generalized* arg
                # processing strategy is best.  For now, I'm just doing it
                # really dim wittedly.
                #
                # If it can fill the arg, then fill it, otherwise move on.  If
                # anything's left, we failed.  More precisely, 1. we have to
                # fill all required args, and 2. we can't have any tokens left.
                #
                # If (1) or (2) fail, we go to the next command without pushing
                # to @return[x].

                while( @cmd_args and @arg_tokens ) {
                    die "need a plan of some kind though... XXX";
                }

                next CMD_LOOP if @arg_tokens;
                next CMD_LOOP if grep { $_->required } @cmd_args;

                push @{ $return[1] }, $cmd;
                push @{ $return[2] }, $opt;
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


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

sub parse {
    my $this = shift;
    my $line = shift;

    my $prefix    = $this->output_prefix;
    my $tokenizer = $this->tokenizer;
    my @tokens    = @{$tokenizer->tokens( $line ) || []};

    return unless @tokens;

    my @matching_commands = grep {substr($_->name, 0, length $tokens[0]) eq $tokens[0]} @{ $this->cmds };

    use Data::Dump qw(dump);
    debug "tokens: " . dump(\@tokens);
    debug "matching commands: @matching_commands";

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

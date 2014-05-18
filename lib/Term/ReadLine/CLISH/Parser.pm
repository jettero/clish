
package Term::ReadLine::CLISH::Parser;

use Moose;
use namespace::autoclean;
use Moose::Util::TypeConstraints;
use Term::ReadLine::CLISH::Error;
use common::sense;
use Parse::RecDescent;

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
has qw(parser is rw isa Parse::RecDescent);

has qw(output_prefix is rw isa Str default) => "% ";

__PACKAGE__->meta->make_immutable;

sub parse {
    my $this = shift;
    my $line = shift;

    my $prefix = $this->output_prefix;
    my $parser = $this->parser;
    my $result = $parser->tokens($line);

    # XXX: disable this, but provide some kind of parser introspection later too
    use Data::Dump qw(dump);
    say "$prefix parsed: " . dump($result);

    unless( $result ) {
        say "$prefix parse error"
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

    # NOTE: $::blah is $main::blah, RD uses it all over

    $::RD_HINT = 1; # let the parser generator give meaningful errors

    my $parser = Parse::RecDescent->new(q

        tokens: token(s) { $return = $item[1] } /$/
              | <error: tokenization failure>

        token: word | string | /\s*/ <error: mysterious goo in column $thiscolumn, "... $text">

        word: /[\w\d_.-]+/ { $return = $item[1] }

        string: "'" /[^']*/ "'" { $return = $item[2] }
              | '"' /[^"]*/ '"' { $return = $item[2] }

    );

    # my @names = $this->command_names;
    # $parser->Extend(sprintf('command: "%s" { $return = $item[1] }', "blah"));
    # $parser->Extend(sprintf('command: "%s" { $return = $item[1] }', "blarg"));
    # $parser->Extend(sprintf('command: "%s" { $return = $item[1] }', "blat"));

    die "unable to parse command grammar in parser generator\n" unless $parser;
    # XXX: should have a better error handler later

    $this->parser($parser);
}

sub command_names {
    return sort map { $_->name } @{ shift->cmds };
}

sub prefix_regex {
    my $this = shift;
    my @prefixes = map {s{::}{/}g} @{ $this->prefix };
    local $" = "|";
    my $RE = qr{(?:@prefixes)};
    return $RE;
}

sub reload_commands {
    my $this = shift;
    my $PATH = $this->path;
    my $prreg = $this->prefix_regex;

    my @cmds;

    for my $path (grep {$_ =~ $prreg} @$PATH) {
        for my $f (glob("$path/*.pm")) {
            if( my ($ppackage) = $f =~ m{($:rreg.*?)\.pm} ) {
                my $package = $ppackage; $package =~ s{/}{::}g;
                my $newcall = "use $package; $package" . "->new";
                my $obj     = eval $newcall;

                if( $obj ) {
                    push @cmds, $obj;

                } else {
                    Term::ReadLine::CLISH::Error->new->spew("while trying to load '$ppackage as $package'");
                }
            }
        }
    }

    $this->cmds(\@cmds);
}

1;


use common::sense;
use Test;
use lib 'example';
use Term::ReadLine::CLISH;

my @output;
*Term::ReadLine::CLISH::Message::spew = sub { push @output, "@_" };

my $parser = Term::ReadLine::CLISH->new->add_namespace("example::cmds")->rebuild_parser->parser;

my %LINES = (
    q    => [ "quit" ],
    qu   => [ "quit" ],
    qui  => [ "quit" ],
    quit => [ "quit" ],
);

plan tests => 0 + (map { @$_ } values %LINES);

for my $line (keys %LINES) {
    my @options = $parser->parse_for_tab_completion($line);
}

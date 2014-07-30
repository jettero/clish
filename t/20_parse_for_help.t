
use common::sense;
use Test;
use lib 'example';
use Term::ReadLine::CLISH;
use Net::DNS;

binmode STDERR, ":utf8";
binmode STDOUT, ":utf8";

my $NOTHING_YET_PLEASE = 1;
my @output;
*Term::ReadLine::CLISH::Message::spew = sub { unless($NOTHING_YET_PLEASE) { warn "$_\n" for @_ } };

my $clish  = Term::ReadLine::CLISH->new->add_namespace("example::cmds") or die "couldn't make clish";
   $clish -> rebuild_parser;
my $parser = $clish->parser or die "couldn't make parser";

$NOTHING_YET_PLEASE = 0;

my @LINES = (
    q    => [ "CMD[quit]" ],
    qu   => [ "CMD[quit]" ],
    qui  => [ "CMD[quit]" ],
    quit => [ "CMD[quit]" ],

    "ping "            => [ qw(FLAG[df] ARG[count] ARG[size] ARG[target]) ],
    "ping df size"     => [ "ARG[size]" ],
    "ping df size "    => [ "ARG[size]" ], # we should show help for size still??
    "ping count "      => [ "ARG[count]" ],
    "ping count 3 "    => [ qw(FLAG[df] ARG[size] ARG[target]) ],
    "ping df size 1 c" => [ qw(ARG[count]) ],
    "p d s 1 c 1 "     => [ qw(ARG[target]) ],
    "p c 1 s 1 df"     => [ qw(FLAG[df]) ],
    "p c 1 s 1 df "    => [ qw(ARG[target]) ],

    "t"  => [ qw(CMD[test1] CMD[test2] CMD[test3] CMD[test4]) ],
    "t " => [ "ARG[msg]" ],
);

my %RESULTS = @LINES;
   @LINES = grep {!ref} @LINES;

plan tests => 0 + @LINES;

@output = ();

for my $line (@LINES) {
    my @options = sort $parser->parse_for_help($line);
    my @expect  = sort @{ $RESULTS{$line} };

    ok( "$line: @options" => "$line: @expect" );
}

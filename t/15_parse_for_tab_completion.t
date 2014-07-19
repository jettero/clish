
use common::sense;
use Test;
use lib 'example';
use Term::ReadLine::CLISH;
use Net::DNS;

my @output;
*Term::ReadLine::CLISH::Message::spew = sub { push @output, "@_" };

my $clish  = Term::ReadLine::CLISH->new->add_namespace("example::cmds") or die "couldn't make clish";
   $clish -> rebuild_parser;
my $parser = $clish->parser or die "couldn't make parser";

my @LINES = (
    q    => [ "quit" ],
    qu   => [ "quit" ],
    qui  => [ "quit" ],
    quit => [ "quit" ],

    "ping "         => [ qw(df count size target) ],
    "ping df size"  => [ qw(size) ],
    "ping df size " => [ ], # integer next, no completion
    "ping count "   => [ ], # integer next, no completion
);

my %RESULTS = @LINES;
   @LINES = grep {!ref} @LINES;

plan tests => 0 + @LINES;

$ENV{CLISH_DEBUG} = 0; # this messages up the message capture if it's set
@output = ();

for my $line (@LINES) {
    my @options = sort $parser->parse_for_tab_completion($line);
    my @expect  = sort @{ $RESULTS{$line} };

    ok( "$line: @options" => "$line: @expect" );
}

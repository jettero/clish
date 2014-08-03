
use common::sense;
use Test;
use lib 'example';
use Term::ReadLine::CLISH;

$ENV{CLISH_DEBUG} = 0; # this messages up the message capture if it's set

my @output;
*Term::ReadLine::CLISH::Message::spew = sub { push @output, "@_" };

my $clish  = Term::ReadLine::CLISH->new->add_namespace("example::cmds") or die "couldn't make clish";
   $clish -> rebuild_parser;
my $parser = $clish->parser or die "couldn't make parser";

my %CMD = (
    q    => [ quit => {} ],
    qu   => [ quit => {} ],
    qui  => [ quit => {} ],
    quit => [ quit => {} ],

    exit => [ quit => {} ],
    "x 'say scalar localtime'" => [ execute => { code => "say scalar localtime" } ],

    "  ping  192.168.1.1" => [ ping => {target=>"192.168.1.1"} ],
    "p t     192.168.1.1" => [ ping => {target=>"192.168.1.1"} ],
    "p c 7 t 192.168.1.1" => [ ping => {target=>"192.168.1.1", count=>7} ],
);

my %EXPECT = (
    "no workie" => qr(unknown command),
    "p t 192.168.1.1 c blah" => qr(unrecognized tokens),
);

$CMD{$_} //= [ ''=>{} ] for keys %EXPECT;

plan tests => 4*(keys %CMD);

for my $str (keys %CMD) {
    @output = ();

    my ($pcmd, $parg) = $parser->parse_for_execution($str);
    my ($ocmd, $oarg) = @{ $CMD{$str} };

    my @k1 = sort grep { $parg->{$_}->has_value } keys %$parg;
    my @k2 = sort keys %$oarg;

    ok(0+@k1, 0+@k2);
    ok("@k1", "@k2");

    my @v1 = map {eval{$_->isa("Net::IP")} ? $_->ip : "$_"} map {$_->value} @{$parg}{@k1};
    ok("@v1", "@{$oarg}{@k2}");

    ok( "@output", $EXPECT{$str} // "" );
}

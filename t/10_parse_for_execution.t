
use common::sense;
use Test;
use lib 'example';
use Term::ReadLine::CLISH;

my @output;
*Term::ReadLine::CLISH::Message::spew = sub { push @output, "@_" };

my $parser = Term::ReadLine::CLISH->new->add_namespace("example::cmds")->rebuild_parser->parser;

my %CMD = (
    q    => [ "quit" => {} ],
    qu   => [ "quit" => {} ],
    qui  => [ "quit" => {} ],
    quit => [ "quit" => {} ],

    "  ping  192.168.1.1" => [ "ping", {target=>"192.168.1.1"} ],
    "p t     192.168.1.1" => [ "ping", {target=>"192.168.1.1"} ],
    "p c 7 t 192.168.1.1" => [ "ping", {target=>"192.168.1.1", count=>7} ],

    "no workie" => [ ''=>{} ],
);

my %EXPECT = (
    "no workie" => qr(unknown command)
);

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


use common::sense;
use Test;
use lib 'example';
use Term::ReadLine::CLISH;

my $parser = Term::ReadLine::CLISH->new->add_namespace("example::cmds")->rebuild_parser->parser;

my %CMD = (
    q    => [ "quit" => {} ],
    qu   => [ "quit" => {} ],
    qui  => [ "quit" => {} ],
    quit => [ "quit" => {} ],

    "  ping  192.168.1.1" => [ "ping", {target=>"192.168.1.1"} ],
    "p t     192.168.1.1" => [ "ping", {target=>"192.168.1.1"} ],
    "p c 7 t 192.168.1.1" => [ "ping", {target=>"192.168.1.1", count=>7} ],
);

plan tests => 3*(keys %CMD) + 1;

my @errors;
my $str;
*Term::ReadLine::CLISH::Parser::error = sub { push @errors, [$str, $@] };
delete $SIG{__WARN__};

for $str (keys %CMD) {
    my ($pcmd, $parg) = $parser->parse_for_execution($str);
    my ($ocmd, $oarg) = @{ $CMD{$str} };

    my @k1 = sort grep { $parg->{$_}->has_value } keys %$parg;
    my @k2 = sort keys %$oarg;

    ok(0+@k1, 0+@k2);
    ok("@k1", "@k2");

    my @v1 = map {eval{$_->isa("Net::IP")} ? $_->ip : "$_"} map {$_->value} @{$parg}{@k1};
    ok("@v1", "@{$oarg}{@k2}");
}

if( @errors ) {
    ok(0);
    select STDERR;
    say "$_->[1] during \"$_->[0]\"" for @errors;

} else {
    ok(1);
}

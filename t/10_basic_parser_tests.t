
use common::sense;
use Test;
use lib 'example';
use Term::ReadLine::CLISH;

plan tests => 3 + 2;

my ($num, $name) = $0 =~ m/(\d+)_(.+)$/;
my $shell = Term::ReadLine::CLISH->new(name=>"$name", version=>"$num.0", prompt=>"$name> ")
    -> add_namespace("example::cmds")
    -> rebuild_parser
    ;

my $parser = $shell->parser;
my ($cmds, $args) = $parser->parse_for_execution("quit");

ok( $shell->name    => $name     );
ok( $shell->version => "$num.0"  );
ok( $shell->prompt  => "$name> " );  

my @v = values %{ $args };

ok( "$cmds" => "CMD[quit]" );
ok( "@v"    => "" );

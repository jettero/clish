
package example::cmds::test2;

use Term::ReadLine::CLISH::Command::Moose;
use namespace::autoclean;
use common::sense;

command( isa => 'example::cmds::test1' );

__PACKAGE__->meta->make_immutable;

1;

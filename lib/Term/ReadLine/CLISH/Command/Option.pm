
package Term::ReadLine::CLISH::Command::Option;

use Moose;
use common::sense;
use namespace::autoclean;
use Moose::Util::TypeConstraints;

subtype 'MethodName', as 'Str', where { m/^[\w_][\w\d_]*\z/ };
subtype 'ChoiceOfMethods', as 'ArrayRef[MethodName]';
coerce 'ChoiceOfMethods', from 'MethodName', via { [ $_ ] };

has qw(name is ro isa Str default) => "??";
has qw(validators is ro isa ChoiceOfMethods coerce 1 default), sub { [] };
has qw(required is ro isa Bool default 0);
has qw(help is ro isa Str default ??);

__PACKAGE__->meta->make_immutable;

1;

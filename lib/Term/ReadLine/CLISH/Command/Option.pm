
package Term::ReadLine::CLISH::Command::Option;

use Moose;
use namespace::sweep; # like autoclean, but doesn't murder overloads
use Moose::Util::TypeConstraints;
use common::sense;
use overload '""' => \&stringify, fallback => 1;

subtype 'FunctionName', as 'Str', where { m/^(?:::|[\w\d_]+)*\z/ };
subtype 'ChoiceOfFunctions', as 'ArrayRef[FunctionName]';
coerce 'ChoiceOfFunctions', from 'FunctionName', via { [ $_ ] };
coerce 'ChoiceOfFunctions', from 'Undef', via { ['Term::ReadLine::CLISH::Command::Option::ACCEPT'] };

has qw(name is ro isa Str default) => "??";
has qw(validators is ro isa ChoiceOfFunctions coerce 1 default), sub { [] };
has qw(required is ro isa Bool default 0);
has qw(tag_optional is ro isa Bool default 0);
has qw(help is ro isa Str default ??);

__PACKAGE__->meta->make_immutable;

sub stringify {
    my $this = shift;

    return "Argument[" . $this->name . "]";
}

1;

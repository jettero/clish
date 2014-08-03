package Term::ReadLine::CLISH::Library::InputModels::ConfigurationInputModel;

use Moose;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use common::sense;

extends 'Term::ReadLine::CLISH::InputModel';

__PACKAGE__->meta->make_immutable;

sub post_exec {
    my $this = shift;
    my ($cmd, $args) = @_;

    return unless my $slot = $cmd->configuration_slot;
    my $line = $cmd->stringify_as_command_line($args);

    $::THIS_CLISH->configuration->set($slot, $line);
}

1;

package Term::ReadLine::CLISH::Library::Commands::Configure;

use Term::ReadLine::CLISH::Command::Moose;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs);
use namespace::autoclean;
use common::sense;

command(
    help => "enter the configuration terminal",
    arguments => [
        flag( 'terminal', help => "(this doesn't really do anything, it's just something people will type here)" ),
    ],
);

__PACKAGE__->meta->make_immutable;

sub exec {
    my $this = shift;

    my $prompt = $::THIS_CLISH->prompt;
       $prompt =~ s/\\b/(config)/
    or $prompt =~ s/([>:#](?:\s*|\e\[[\d;]+m)*)\z/(config)$1/
    or $prompt = "$prompt(config)"
       ;

    $::THIS_CLISH->push_model(
        'Term::ReadLine::CLISH::Library::InputModels::ConfigurationModel',
        prompt => $prompt,
        prefix => [ map { $_ . "::Configure" } @{$::THIS_CLISH->prefix} ],
    );

    warning "pushed input model from empty path or something \$@=$@" if $@;

    return;
}

1;

package Term::ReadLine::CLISH::Configuration;

use Moose;
use File::Slurp qw(slurp);
use File::Spec;
use Term::ReadLine::CLISH::MessageSystem qw(:msgs :tool);
use Term::ReadLine::CLISH::Library::InputModels::ConfigurationInputModel;
use common::sense;

has qw(slots is ro isa HashRef default) => sub { +{} };
has qw(subspace is rw isa Str default Configure);
has qw(model is ro isa Term::ReadLine::CLISH::InputModel default) => sub {
    Term::ReadLine::CLISH::Library::InputModels::ConfigurationInputModel->new;
};

has qw(startup_config_filename is rw isa Str default startup-config);

__PACKAGE__->meta->make_immutable;

{
    my %CONFIGS;
    sub value {
        my $this = shift;
        my $key  = shift or return;
        $CONFIGS{$key} = shift if @_;
        return $CONFIGS{$key};
    }
}

sub stringify_config {
    my $this = shift;
    my $slots = $this->slots;
    my @lines = map {$slots->{$_}} sort keys %$slots;

    my $PKG = ref $::THIS_CLISH;
    my $pkg = ref $this;
    my $date = localtime;

    local $" = "\n";
    return "! $PKG configuration\n! generated by $pkg on $date\n\n@lines\n";
}

sub recompute_prefix {
    my $this  = shift;
    my $model = $this->model;
    my $sub   = $this->subspace;

    $model->prefix( [ map { $_ . "::$sub" } @{$::THIS_CLISH->prefix} ] );
    $model->rebuild_parser;

    return $this;
}

sub read_configuration {
    my $this = shift;
    my $config = eval { slurp( $::THIS_CLISH->locate_config_file( $this->startup_config_filename )) };

    debug "couldn't read config", scrub_last_error() unless $config;

    return $this unless $config;

    info "read configuration from " . $this->startup_config_filename;
    return $this->execute_configuration($config);
}

sub execute_configuration {
    my $this = shift;
    my $config = shift;

    my $parser = $this->recompute_prefix->model->rebuild_parser->parser;

    for my $line ( split m/\s*\x0d?\x0a\s*/, $config ) {
        chomp $line;
        next if $line =~ m/^\s*\!/; # comment line
        next unless $line =~ m/\S/;

        if( my ($cmd, $args) = $parser->parse_for_execution( $line ) ) {
            debug "config-exec( $line )" if $ENV{CLISH_DEBUG};
            $cmd->exec( $args );
        }
    }

    info "merged configuration";
    return $this;
}

sub set {
    my $this = shift;
    my ($slot, $line) = @_;

    debug "configuration set($slot => $line)" if $ENV{CLISH_DEBUG};

    return $this->slots->{slot} = $line;
}

sub clear_slot {
    my $this = shift;
    my ($slot) = @_;

    debug "configuration clear($slot)" if $ENV{CLISH_DEBUG};

    return delete $this->slots->{slot};
}

1;

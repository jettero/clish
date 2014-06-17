package Term::ReadLine::CLISH::InputModel;

=encoding UTF-8
=head1 NAME

Term::ReadLine::CLISH::InputModel — a container for a parser, prompt, path, etc

=cut

use Moose;
use common::sense;
use namespace::autoclean;
use Term::ReadLine::CLISH::Parser;
use Term::ReadLine::CLISH::MessageSystem;

has qw(parser is rw isa Term::ReadLine::CLISH::Parser);
has qw(prompt is rw isa Str default) => "clish> ";

has qw(prefix is rw isa prefixArray coerce 1 default) => sub {['Term::ReadLine::CLISH::Library::Commands']};
has qw(path   is rw isa pathArray   coerce 1 default) => sub {
    my $file = __FILE__;
       $file =~ s{InputModel.pm$}{Library};

    return $file;
};

__PACKAGE__->meta->make_immutable;

sub rebuild_parser {
    my $this = shift;

    my $parser = Term::ReadLine::CLISH::Parser->new(path=>$this->path, prefix=>$this->prefix);
    $this->parser( $parser );
    debug "path: " . $this->path_string if $ENV{CLISH_DEBUG};

    return $::THIS_CLISH;
}

sub path_string {
    my $this = shift;

    return join(":", @{ $this->path });
}

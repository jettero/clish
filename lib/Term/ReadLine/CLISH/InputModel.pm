package Term::ReadLine::CLISH::InputModel;

=encoding UTF-8
=head1 NAME

Term::ReadLine::CLISH::InputModel — a container for a parser, prompt, path, etc

=cut

use Moose;
use common::sense;
use namespace::autoclean;

has qw(parser is rw isa Term::ReadLine::CLISH::Parser);
has qw(prompt is rw isa Str default) => "clish> ";

has qw(prefix is rw isa prefixArray coerce 1 default) => sub {['Term::ReadLine::CLISH::Library::Commands']};
has qw(path   is rw isa pathArray   coerce 1 default) => sub {
    my $file = __FILE__;
       $file =~ s{InputModel.pm$}{Library};

    return $file;
};

__PACKAGE__->meta->make_immutable;

#!/usr/bin/perl -Ilib

use common::sense;
use Term::ReadLine::CLISH;

Term::ReadLine::CLISH->new(name=>"My Shell", version=>"0.1")
    -> add_namespace("example::cmds")
    -> run;

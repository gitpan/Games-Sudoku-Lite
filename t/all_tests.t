#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'no_plan';

use lib 'lib';
use Games::Sudoku::Lite;

my @problems  = glob("t/data/*.problem");
my @solutions = glob("t/data/*.solution");

for my $i (0..@problems-1)
{
    local $/;
    open F, $problems[$i],  and my $problem  = <F> and close F or die $!;
    open F, $solutions[$i], and my $solution = <F> and close F or die $!;

    my $puzzle = Games::Sudoku::Lite->new($problem);
       $puzzle->solve;
    is ($puzzle->solution, $solution);
}



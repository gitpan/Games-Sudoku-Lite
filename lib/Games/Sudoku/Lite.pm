# Games::Sudoku::Lite -- Fast and simple Sudoku puzzle solver
#
# Copyright (C) 2006  Bob O'Neill.
# All rights reserved.
#
# This code is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#

package Games::Sudoku::Lite;

use strict;
use warnings;

our $VERSION = '0.10';

# Configurable, just in case somebody wants it to be.
my $Width           = 9;
my $Height          = 9;
my $Square_Height   = 3;
my $Square_Width    = 3;
my @Possible_Values = (1..9);

my $DEBUG = 0;

sub new {
    my $class = shift;
    my $board = shift;
    my $self  = {};
    $self->{board} = _txt_to_array($board);

    return bless $self, $class;
}

sub solve {
    my $self = shift;

    my $success = $self->_algorithm();
    $self->_retry() if not $success;
}

sub _algorithm {
    my $self = shift;

    # Accurate naming at the expense of brevity
    my $prev_possibilities = $Width * $Height * @Possible_Values;
    my $possibilities_left = $self->_possibilities_left();

    while ($possibilities_left < $prev_possibilities)
    {
        $self->_row_rule();
        $self->_column_rule();
        $self->_square_rule();

        $prev_possibilities = $possibilities_left;
        $possibilities_left = $self->_possibilities_left();
        warn "Possibilities Remaining: $possibilities_left" if $DEBUG;
    }

    # Clarity at the expense of conciseness
    my $success = ($possibilities_left == 0);
    return $success;
}

sub _retry
{
    my $self = shift;

    # Start guessing.
    my @coords;
    my $x = 0;
    # Make a list of all unknowns
    for my $row (@{$self->{board}})
    {
        my $y = 0;
        for my $cell (@$row)
        {
            push @coords, [$x, $y] if ref $cell;
            $y++;
        }
        $x++;
    }
    # For each undetermined point, make each possible guess and re-run
    # the algorithm.  This assumes that the puzzle is solvable with one
    # particular correct guess and doesn't attempt to make multiple
    # consecutive guesses.
    my $saved_board = $self->{board};
    for my $point (@coords)
    {
        my ($x, $y) = @$point;

        my @choices = @{ $self->{board}[$x][$y] };
        for my $choice (@choices)
        {
            # Make the guess.
            $self->{board}[$x][$y] = $choice;

            warn "trying again...set $x $y to $choices[0]" if $DEBUG;
            my $success = $self->_algorithm();

            if ($success) {
                return 1;
            }
            else {
                $self->{board} = $saved_board;
                # we'll have to guess again...
            }
        }
    }
    return 0;
}

sub solution {
    my $self = shift;
    return _array_to_txt($self->{board});
}

sub _array_to_txt {
    my $array = shift || [];
    my $board = '';
    for my $row (@$array)
    {
        if ($DEBUG)
        {
            for (@$row) {
               $_ = join '', @$_ if ref $_;
               my $w = @Possible_Values + 1;
               $board .= sprintf "%${w}s", $_;
            }
            $board .= "\n";
        }
        else
        {
            for (@$row) { $_ = '.' if ref $_ }
            $board .= join '', @$row, "\n";
        }
    }

    return $board;
}

sub _txt_to_array {
    my $board = shift;
    my @array;
    my $i = 0;
    for my $line (split /\n/, $board)
    {
        my @row = split //, $line, $Width;
        for my $i (0..@row-1)
        {
            my $cell = $row[$i];
            if ($cell eq '.')
            {
                $cell = [@Possible_Values];
            }
            $row[$i] = $cell;
        }
        push @array, [@row];

        $i++;
        warn "ERROR: Too Many Rows in Board" if $i > $Height;
    }
    return \@array;
}

sub _possibilities_left {
    my $self = shift;
    my $possibilities_left = 0;
    for my $row (@{$self->{board}})
    {
        for my $cell (@$row)
        {
            $possibilities_left += @$cell if ref $cell;
        }
    }
    return $possibilities_left;
}

sub _row_rule {
    my $self = shift;

    for my $row_num (1..$Height)
    {
        my @row   = $self->_get_row($row_num);
        my %homes = _reduce_possibilities(\@row);
        $self->_set_row($row_num, @row);
        $self->_send_home(row_num => $row_num, homes => \%homes);
    }
}

sub _column_rule {
    my $self = shift;

    for my $column_num (1..$Width)
    {
        my @column = $self->_get_column($column_num);
        my %homes  = _reduce_possibilities(\@column);
        $self->_set_column($column_num, @column);
        $self->_send_home(column_num => $column_num, homes => \%homes);
    }
}

sub _square_rule {
    my $self = shift;

    my $h_squares     = $Width  / $Square_Width;
    my $v_squares     = $Height / $Square_Height;
    my $total_squares = $h_squares * $v_squares;

    for my $square_num (1..$total_squares)
    {
        my $square = $self->_get_square($square_num);
        my %homes  = _reduce_possibilities($square);
        $self->_set_square($square_num, $square);
        $self->_send_home(square_num => $square_num, homes => \%homes);
    }
}

sub _reduce_possibilities {
    my $cells = shift;
    my @known_values = grep { not ref $_ } @$cells;

    my %homes;
    for my $cell (@$cells)
    {
        if (not ref $cell) {
            $homes{$cell}++;
            next;
        }

        my @new_poss;
        for my $n (@$cell) {
            push (@new_poss, $n) unless grep /^$n$/, @known_values;
        }
        warn "ERROR: No possibilities left for this cell" unless @new_poss;
        $cell = \@new_poss;
        $cell = $new_poss[0] if @new_poss == 1; # Cell is solved.

        $homes{$_}++ for @new_poss;
    }
    return %homes;
}

sub _send_home {
    my $self       = shift;
    my %params     = @_;
    my %homes      = %{$params{homes}};
    my $row_num    = $params{row_num};
    my $column_num = $params{column_num};
    my $square_num = $params{square_num};

    warn "ERROR: missing value in ". join('|', keys %homes)
        unless (keys %homes == @Possible_Values);

    for my $n (keys %homes) {
        warn "ERROR: no home for $n"
            ." (row=$row_num; column=$column_num; square=$square_num)"
            unless $homes{$n};

        if ($homes{$n} == 1) {
            if ($row_num) {
                my @row = $self->_get_row($row_num);
                $self->_find_a_home($n, \@row);
                $self->_set_row($row_num, @row);
            }
            elsif ($column_num) {
                my @column = $self->_get_column($column_num);
                $self->_find_a_home($n, \@column);
                $self->_set_column($column_num, @column);
            }
            elsif ($square_num) {
                my $square = $self->_get_square($square_num);
                $self->_find_a_home($n, $square);
                $self->_set_square($square_num, $square);
            }
            else {
                warn "ERROR: missing row_num/column_num/square_num value";
            }
        }
    }
}

sub _find_a_home {
    my $self  = shift;
    my $n     = shift;
    my $cells = shift || [];

    for my $cell (@$cells)
    {
        next if not ref $cell;
        if (grep /^$n$/, @$cell)
        {
            # Cell is solved.
            $cell = $n;
            last;
        }
    }
}

sub _get_row {
    my $self    = shift;
    my $row_num = shift;

    return @{$self->{board}[$row_num-1]};
}

sub _set_row {
    my $self    = shift;
    my $row_num = shift;
    my @row     = @_;

    $self->{board}[$row_num-1] = \@row;
}

sub _get_column {
    my $self       = shift;
    my $column_num = shift;
    my @column;

    for my $row (@{$self->{board}}) {
        push @column, $row->[$column_num-1];
    }

    return @column;
}

sub _set_column {
    my $self       = shift;
    my $column_num = shift;
    my @column     = @_;

    my $i = 0;
    for my $row (@{$self->{board}}) {
        $row->[$column_num-1] = $column[$i++];
    }
}

sub _get_square {
    _get_or_set_square(@_); # reduces duplication
}

sub _set_square {
    _get_or_set_square(@_); # ditto
}

sub _get_or_set_square {
    my $self       = shift;
    my $square_num = shift;
    my $set_square = shift; # Pass a square in to set, otherwise will get

    my $h_squares = $Width  / $Square_Width;
    my $v_squares = $Height / $Square_Height;

    my $column_num = $square_num % $h_squares;          # 1, 2, 3
    my $row_num    = _round_up($square_num/$v_squares); # 1, 2, 3

    my $x_min = ($column_num - 1) * $Square_Width;      # 0..8
    my $x_max = $x_min + $Square_Width - 1;             # 0..8
    my $y_min = ($row_num - 1) * $Square_Height;        # 0..8
    my $y_max = $y_min + $Square_Height - 1;            # 0..8

    my @square;
    my %map;
    for my $x ($x_min..$x_max)
    {
        for my $y ($y_min..$y_max)
        {
            $map{$x}{$y} = @square; # scalar context
            $self->{board}[$x][$y] = $set_square->[$map{$x}{$y}] if $set_square;
            push @square, $self->{board}[$x][$y];
        }
    }

    return \@square;
}

sub _round_up {
    my $float     = shift;
    my $int_float = int $float;
    if ($int_float == $float) {
        return $int_float;
    }
    else {
        return $int_float + 1;
    }
}

1; # of rings to rule them all.

__END__

=head1 NAME

Games::Sudoku::Lite -- Fast and simple Sudoku puzzle solver

=head1 SYNOPSIS

 use Games::Sudoku::Lite;

 my $board = <<END;
 3....8.2.
 .....9...
 ..27.5...
 24.5..8..
 .85.74..6
 .3....94.
 1.4....72
 ..69...5.
 .7.612..9
 END

 my $puzzle = Games::Sudoku::Lite->new($board);
    $puzzle->solve;

 print $puzzle->solution, "\n";

=head1 AUTHOR

Bob O'Neill, E<lt>bobo@cpan.orgE<gt>
 
=head1 ACKNOWLEDGEMENTS

Thanks to Tom Wyant (L<http://search.cpan.org/~wyant/>))
for the idea of using dots rather than spaces to represent
unknowns in the text representation of the board.

Thanks to Eugene Kulesha (L<http://search.cpan.org/~jset/>)
for providing a test that I could not initially pass and for
the idea of keeping test data in data files rather than in
the tests themselves.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 Bob O'Neill.
All rights reserved.

This code is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item * L<perl>.

=back

=cut

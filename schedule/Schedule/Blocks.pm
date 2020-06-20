#!/usr/bin/perl
use strict;
use warnings;

package Blocks;
use FindBin;
use Carp;
use lib "$FindBin::Bin/..";
use Schedule::Block;

=head1 NAME

Blocks - static class to provide useful methods for collections of blocks 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Blocks;
    
    #Get a list of all the AssignBlocks associated with a given day
    my @dayBlocks = AssignBlock->get_day_blocks( $day, $allBlocks );
    

=head1 CLASS METHODS

=cut

# =================================================================
# get_day_blocks ($day, $blocks)
# =================================================================

=head2 get_day_blocks ($day, $blocks)

return an array of all blocks within a specific day

B<Parameters>

$day day of the week (integer, 1=monday etc)

$blocks array pointer of AssignBlocks

B<Returns>

Array of AssignBlock objects

=cut

sub get_day_blocks {
    my $class  = shift;
    my $day    = shift;
    my $blocks = shift;

    my @x = @$blocks;
    return unless $blocks;
    return grep { $_->day == $day } @$blocks;
}

1;


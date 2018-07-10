#!/usr/bin/perl
use strict;
use warnings;

package Conflict;
use Carp;


=head1 NAME

Conflict - create the Conflict object

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Conflict;

    $schedule->conflicts->add( -type   => Conflict->MINIMUM_DAYS
                             , -blocks => \@blocks
                             );      
        

=head1 DESCRIPTION

Describes a conflict

=head1 METHODS

=cut

# =================================================================
# Class variables
# =================================================================
our $Max_id;

# =================================================================
# Constants
# =================================================================

use constant {
    TIME         => 1,
    LUNCH        => 2,
    MINIMUM_DAYS => 4,
    AVAILABILITY => 8
};
our @Sorted_Conflicts = (TIME, LUNCH, MINIMUM_DAYS, AVAILABILITY);

# =================================================================
# most_severe
# =================================================================

=head2 most_severe(number)

CLASS or object method

Input a conflict number, returns number of most severe conflict

=cut

sub most_severe {
    my $class = shift;
    my $conflict_number = shift || 0;
    my $severest = 0;
            
    # loop through conflict types by order of severity (most severe first)
    foreach my $conflict (@Sorted_Conflicts) {
                
        # logically AND each conflict type with the specified conflict number
        if ($conflict_number & $conflict) {
            $severest = $conflict;
            last;
        }
    }
    
    return $severest;
}
 

# =================================================================
# new
# =================================================================

=head2 new (...)

creates and returns a conflict object

B<Parameters>

-type => the type of the conflict

-blocks => the blocks involved in the conflict

B<Returns>

Conflict object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;
    confess "Bad inputs" if @_%2;

    my %inputs = @_; 
    my $type = $inputs{-type} || "";
    my $blocks = $inputs{-blocks} || "";
    
    my $self = { };
    bless $self, $class;
    $self->type($type);
    $self->blocks($blocks);
    
    return $self;
}

# =================================================================
# type
# =================================================================

=head2 type ( [type] )

Gets and sets the conflict's type

=cut

sub type {
    my $self = shift;
    $self->{-type} = shift if @_;
    return $self->{-type}
}

# =================================================================
# blocks
# =================================================================

=head2 blocks ( [blocks] )

Gets and sets the conflict's blocks

=cut

sub blocks {
    my $self = shift;
    $self->{-blocks} = shift if @_;
    return $self->{-blocks}
}

# =================================================================
# add_block
# =================================================================

=head2 add_block ( [block] )

Add a block to the blocks

=cut

sub add_block($) {
    my $self = shift;
    my $block = shift;
    push @{$self->{-blocks}}, $block;
}


1;

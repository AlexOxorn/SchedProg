#!/usr/bin/perl
use strict;
use warnings;

package Conflict;
use FindBin;
use lib "$FindBin::Bin/..";
use lib "$FindBin::Bin/Library";
use PerlLib::Colour;
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
    AVAILABILITY => 8,
    TIME_TEACHER => 16,
    TIME_LAB     => 32,
    TIME_STREAM  => 64,
};

our @Sorted_Conflicts = (TIME, LUNCH, MINIMUM_DAYS, AVAILABILITY);

my $Colours = {
    Conflict->TIME_TEACHER => "red2",
    Conflict->TIME_LAB     => "red2",
    Conflict->TIME_STREAM  => "red2",
    Conflict->LUNCH        => "tan4",
    Conflict->MINIMUM_DAYS => "lightgoldenrod1",
    Conflict->AVAILABILITY => "mediumvioletred"
};
my $lightred = Colour->new($Colours->{Conflict->TIME_TEACHER})->lighten(30);
$Colours -> {Conflict->TIME} = $lightred;

sub Colours {
    return $Colours;
}


sub hash_descriptions {
    return { 
        Conflict::TIME => "indirect time overlap",
        Conflict::LUNCH => "no lunch time",
        Conflict::MINIMUM_DAYS => "too few days",
        Conflict::TIME_TEACHER => "time overlap",
        Conflict::TIME_LAB => "time overlap",
        Conflict::TIME_STREAM  => "time overlap",
        Conflict::AVAILABILITY => "not available"
    }            
}

sub get_description {
    my $class = shift;
    my $num = shift;
    my $h = hash_descriptions;
    return $h->{$num};
    
}

sub is_time {
    my $class = shift;
    my $number = shift;
    return $number & TIME;
}

sub is_time_lab {
    my $class = shift;
    my $number = shift;
    return $number & TIME_LAB;
}

sub is_time_teacher {
    my $class = shift;
    my $number = shift;
    return $number & TIME_TEACHER;
}

sub is_time_stream {
    my $class = shift;
    my $number = shift;
    return $number & TIME_STREAM;
}

sub is_lunch {
    my $class = shift;
    my $number = shift;
    return $number & LUNCH;
}

sub is_minimum_days {
    my $class = shift;
    my $number = shift;
    return $number & MINIMUM_DAYS;
}

sub is_availibilty {
    my $class = shift;
    my $number = shift;
    return $number & AVAILABILITY;
}


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
    my $view_type = shift || "";
    my $severest = 0;
    
    my @sorted_conflicts = @Sorted_Conflicts;
    unshift @sorted_conflicts,TIME_LAB if lc($view_type) eq "lab"; 
    unshift @sorted_conflicts,TIME_STREAM if lc($view_type) eq "stream"; 
    unshift @sorted_conflicts,TIME_TEACHER if lc($view_type) eq "teacher"; 
                
    # loop through conflict types by order of severity (most severe first)
    foreach my $conflict (@sorted_conflicts) {
                
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

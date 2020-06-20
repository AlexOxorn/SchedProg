#!/usr/bin/perl
use strict;
use warnings;

package Lab;
use Carp;
use FindBin;
use lib "$FindBin::Bin/..";
use Schedule::Time_slot;
use overload 
		fallback => 1,
		'""' => \&print_description;

=head1 NAME

Lab - describes a distinct contiguous course/section/class 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Lab;
    
    my $lab = Lab->new (-number=>"P322");
    $section->add_unavailable(-start=>"3:22",
                              -day=>"Mon",
                              -duration=5);
    

=head1 DESCRIPTION

Describes a physical room where classes are taught.

=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Max_id = 0;

# =================================================================
# new
# =================================================================

=head2 new ()

creates and returns a lab object

B<Parameters>

-number => Room number

B<Returns>

Lab object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;

    confess "Bad inputs\n" if @_ % 2;
    my %inputs = @_;

    # process inputs
    my $number      = $inputs{-number}      || "100";
    my $desc        = $inputs{-descr}        || '';

    my $self = {};
    bless $self;
    
    $self->number ($number);
    $self->descr  ($desc);
	$self->{-id} = ++$Max_id;

    return $self;
}

# =================================================================
# id
# =================================================================

=head2 id ()

Returns the unique id for this lab object

=cut

sub id {
    my $self = shift;
    return $self->{-id};
}

# =================================================================
# number
# =================================================================

=head2 number ()

Sets/returns the room number for this lab object

=cut

sub number {
    my $self = shift;
    $self->{-number} = shift if @_;
    return $self->{-number};
}

# =================================================================
# descr
# =================================================================

=head2 descr ()

Sets/returns the description for this lab object

=cut

sub descr {
    my $self = shift;
    $self->{-descr} = shift if @_;
    return $self->{-descr};
}

# =================================================================
# add_unavailable
# =================================================================

=head2 add_unavailabe ()

creates a time slot where this lab is not available

B<Parameters>

-day => 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'

-start => start time using 24 h clock (i.e 1pm is "13:00")

-duration => how long does this class last, in hours

B<Returns>

Lab object

=cut

sub add_unavailable {
    my $self = shift;
    $self->{-unavailable}={} unless $self->{unavailable};

    # create timeslot
    my $slot = Time_slot->new(@_);
    
    # save
    $self->{-unavailable}->{$slot->id} = $slot;

    return $self;
}

# =================================================================
# add_unavailable
# =================================================================

=head2 remove_unavailabe (id)

remove the unavailable time slot from this lab

B<Parameters>

id: the id of the time slot to be removed

B<Returns>

Lab object

=cut

sub remove_unavailable {
    my $self = shift;
    my $id = shift;
    delete $self->{-unavailable}->{$id};
    return $self;
}

# =================================================================
# get_unavailable
# =================================================================

=head2 get_unavailabe (id)

return the unavailable time slot object for this lab

B<Parameters>

id => the id of the time slot to be returned

B<Returns>

Time_slot object

=cut

sub get_unavailable  {
    my $self = shift;
    my $id = shift;
    return $self->{-unavailable}->{$id};
}

# =================================================================
# unavailable
# =================================================================

=head2 unavailabe ()

returns all the unavailable time slot objects for this lab

B<Returns>

List of Time_slot objects

=cut

sub unavailable  {
    my $self = shift;
    my $id = shift;
    return values %{$self->{-unavailable}};
}

# =================================================================
# print_description
# =================================================================

=head2 print_description

Returns a text string that describes the lab

=cut

sub print_description {
    my $self = shift;
    my $text = $self->number;

	$text = $text . ": " . $self->descr if $self->descr;

    return $text;

}

# =================================================================
# footer
# =================================================================


=head1 AUTHOR

Sandy Bultena, Ian Clement, Jack Burns

=head1 COPYRIGHT

Copyright (c) 2016, Jack Burns, Sandy Bultena, Ian Clement. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut

1;


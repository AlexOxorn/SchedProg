#!/usr/bin/perl
use strict;
use warnings;

package Labs;

use FindBin;
use lib ("$FindBin::Bin/..");
use Schedule::Lab;
use Carp;

=head1 NAME

Labs - a class containing an array of lab objects

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Labs;
    
    my $labs = Labs->new();
    
    $labs->add($lab_object);
    $labs->remove($lab_object);
    my $array = $labs->list();


=head1 DESCRIPTION

Manages the array of labs.

=head1 METHODS

=cut

# =================================================================
# new
# =================================================================

=head2 new ()

creates an empty Labs object

B<Returns>

Labs object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self = { -list => {} };
    bless $self, $class;
    return $self;
}

# =================================================================
# share_blocks
# =================================================================

=head2 share_blocks(block1, block2)  CLASS METHOD

Are there labs who share these two blocks?

Returns true/false

=cut

sub share_blocks {
    my $class = shift;
    my $block1 = shift;
    my $block2 = shift;
    
    
    # count occurences in both sets and ensure that all values are < 2
    my %occurences;

    # get all the labs for the first and second set.
    foreach my $lab ($block1->labs) {
        $occurences{$lab->id}++;
    }
    foreach my $lab ($block2->labs) {
        $occurences{$lab->id}++;
    }

    # a count of 2 means that they are in both sets.
    foreach my $count (values %occurences) {
        return $count if ($count >= 2);
    } 

    return;
}

# =================================================================
# add
# =================================================================

=head2 add(lab1, [lab2, ...])

Adds a new lab Labs object

Returns Labs object

=cut

sub add {
    my $self = shift;
    $self->{-list} = $self->{-list} || {};
    while ( my $lab = shift ) {
        confess "<" . ref($lab) . ">: invalid lab - must be a Lab object"
          unless ref($lab) && $lab->isa("Lab");

        # cannot have two distinct labs with the same room #
        my $obj = $self->get_by_number( $lab->number );
        if ( $obj && $obj->id != $lab->id ) {
            confess "<" . $lab->number . ">"
              . ": another lab/resource already exists with this number";
        }

        $self->{-list}{ $lab->id } = $lab;
    }
    return $self;
}

# =================================================================
# get
# =================================================================

=head2 get(lab_id)

Returns Labs object with id

=cut

sub get {
    my $self = shift;
    my $id   = shift;
    return $self->{-list}->{$id};
}

# =================================================================
# get_by_number
# =================================================================

=head2 get_by_number(lab number)

Return lab which matches this lab number

=cut

sub get_by_number {
    my $self   = shift;
    my $number = shift;
    return unless $number;

    foreach my $lab ( $self->list ) {
        if ( $lab->number eq $number ) {
            return $lab;
        }
    }

    return;

}

# =================================================================
# remove lab
# =================================================================

=head2 remove ($lab_object)

Removes lab from the Labs object

Returns labs object

=cut

sub remove {
    my $self = shift;
    my $lab  = shift;

    confess "<" . ref($lab) . ">: invalid lab - must be a Lab object"
      unless ref($lab) && $lab->isa("Lab");

    delete $self->{-list}{ $lab->id }
      if exists $self->{-list}{ $lab->id };

    undef $lab;

    return $self;
}

# =================================================================
# list
# =================================================================

=head2 list ()

Returns reference to array of Course objects

=cut

sub list {
    my $self = shift;
    if (wantarray) {
        return values %{ $self->{-list} };
    }
    else {
        return [ values %{ $self->{-list} } ];
    }
}

# =================================================================
# footer
# =================================================================

1;

=head1 AUTHOR

Sandy Bultena, Ian Clement, Jack Burns

=head1 COPYRIGHT

Copyright (c) 2016, Jack Burns, Sandy Bultena, Ian Clement. 

All Rights Reserved.

This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

     (see http://www.perl.com/perl/misc/Artistic.html)

=cut


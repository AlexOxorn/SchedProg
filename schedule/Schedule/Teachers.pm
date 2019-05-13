#!/usr/bin/perl
use strict;
use warnings;

package Teachers;

use FindBin;
use lib ("$FindBin::Bin/..");
use Schedule::Teacher;
use Carp;

=head1 NAME

Teachers - a class containing an array of teacher objects

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Teachers;
    
    my $teachers = Teachers->new();
    
    $teachers->add($teacher_object);
    $teachers->remove($teacher_object);
    my $array = $teachers->list();


=head1 DESCRIPTION

Manages the array of teachers.

=cut 

=head1 Class METHODS

=cut

# =================================================================
# new
# =================================================================

=head2 new ()

creates an empty Teachers object

B<Returns>

Teachers object

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

Are there teachers who share these two blocks?

Returns true/false

=cut

sub share_blocks {
    my $class = shift;
    my $block1 = shift;
    my $block2 = shift;
    
    
    # count occurences in both sets and ensure that all values are < 2
    my %occurences;

    # get all the teachers the first and second set.
    foreach my $teacher ($block1->teachers) {
        $occurences{$teacher->id}++;
    }
    foreach my $teacher ($block2->teachers) {
        $occurences{$teacher->id}++;
    }

    # a count of 2 means that they are in both sets.
    foreach my $count (values %occurences) {
        return $count if ($count >= 2);
    } 

    return;
}


=head1 Instance METHODS

=cut

# =================================================================
# add
# =================================================================

=head2 add(teacher1, [teacher2, ...])

Adds a new teacher Teachers object

Returns Teachers object

=cut

sub add {
    my $self = shift;
    $self->{-list} = $self->{-list} || {};
    while (my $teacher = shift) {
        confess "<"
          . ref($teacher)
          . ">: invalid teacher - must be a Teacher object"
          unless ref($teacher) && $teacher->isa("Teacher");
        
        $self->{-list}{$teacher->id}=$teacher;
    }
    return $self;
}

# =================================================================
# get
# =================================================================

=head2 get(teacher_id)

Returns Teachers object with id

=cut

sub get {
    my $self = shift;
    my $id = shift;
    return $self->{-list}->{$id};
}

# =================================================================
# get_by_name
# =================================================================

=head2 get_by_name(first_name,last_name)

Returns first teacher found which matches first name / last name

=cut

sub get_by_name {
    my $self = shift;
    my $first_name = shift;
    my $last_name = shift;
    return unless $first_name && $last_name;
    
    foreach my $teacher ($self->list) {
        if ($teacher->firstname eq $first_name && $teacher->lastname eq $last_name) {
            return $teacher;
        }
    }
    
    return;
    
}

# =================================================================
# remove teacher 
# =================================================================

=head2 remove ($teacher_object)

Removes teacher from the Teachers object

Returns teachers object

=cut

sub remove {
    my $self = shift;
    my $teacher  = shift;

    confess "<" . ref($teacher) . ">: invalid teacher - must be a Teacher object"
      unless ref($teacher) && $teacher->isa("Teacher");

    delete $self->{-list}{ $teacher->id }
      if exists $self->{-list}{ $teacher->id };
    
    undef $teacher;

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
        return values %{$self->{-list}};
    }
    else {
        return [values %{$self->{-list}}];
    }
}

# =================================================================
# disjoint 
# =================================================================

=head2 disjoint ( [Teachers] )

Determine is the current set of teachers is disjoint with the provided set of
teachers.

=cut

sub disjoint {
    my $self = shift;
    my $rhs = shift;

    my %occurences;

    # get all the teachers the current set.
    foreach my $teacher (@{$self->teachers->list}) {
        $occurences{$teacher->id}++;
    }

    # get all the teachers the provided set.
    foreach my $teacher (@{$rhs->teachers->list}) {
        $occurences{$teacher->id}++;
    }

    # a teacher count of 2 means that they are in both sets.
    foreach my $count (values %occurences) {
        return 0 if ($count >= 2);
    } 
    
    return 1;
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


#!/usr/bin/perl
use strict;
use warnings;

package Courses;

use FindBin;
use lib ("$FindBin::Bin/..");
use Carp;

use Schedule::Course;

=head1 NAME

Courses - a class containing an array of course objects

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Courses;
    
    my $courses = Courses->new();
    
    $courses->add($course_object);
    $courses->remove($course_object);
    my $array = $courses->list();


=head1 DESCRIPTION

Manages the array of courses.

=head1 METHODS

=cut

# =================================================================
# new
# =================================================================

=head2 new ()

creates an empty Courses object

B<Returns>

Courses object

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
# add
# =================================================================

=head2 add( Course Object(s) )

Adds a new course Courses object

Returns Courses object

=cut

sub add {
    my $self = shift;
    while ( my $course = shift ) {
        confess "<"
          . ref($course)
          . ">: invalid course - must be a Course object"
          unless ref($course) && $course->isa("Course");

        $self->{-list}{ $course->id } = $course;
    }
    
    
    return $self;
}

# =================================================================
# remove course
# =================================================================

=head2 remove ($course_object)

Removes course from the Courses object

Returns course object

=cut

sub remove {
    my $self   = shift;
    my $course = shift;

    confess "<" . ref($course) . ">: invalid course - must be a Course object"
      unless ref($course) && $course->isa("Course");

    delete $self->{-list}{ $course->id }
      if exists $self->{-list}{ $course->id };

    $course->delete();
    
    foreach my $course ( $self->list ) {
        print $course->number; 
        print "\t"
    }
    print "\n-------\n";

    return $self;
}

# =================================================================
# get
# =================================================================

=head2 get(lab_id)

Returns Courses object with id

=cut

sub get {
    my $self = shift;
    my $id   = shift;
    return $self->{-list}->{$id};
}

# =================================================================
# get_by_number
# =================================================================

=head2 get_by_number(course number)

Return course which matches this course number

=cut

sub get_by_number {
    my $self   = shift;
    my $number = shift;
    return unless $number;

    foreach my $course ( $self->list ) {
        if ( $course->number eq $number ) {
            return $course;
        }
    }

    return;

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
# courses list for allocation
# =================================================================

=head2 allocation_list ()

Returns a list of courses, sorted, that need allocation 

=cut

sub allocation_list {
    my $self = shift;

    my @courses = grep { $_->needs_allocation }
      sort { $a->number cmp $b->number } $self->list;
      
      return @courses;
}

# =================================================================
# footer    Scheduler->Courses->list()
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


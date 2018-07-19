#!/usr/bin/perl
use strict;
use warnings;

package Course;

use FindBin;
use lib ("$FindBin::Bin/..");
use Carp;
use Schedule::Section;
use overload '""' => \&print_description;

=head1 NAME

Course - describes a distinct course

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Course;
    
    my $block = Block->new (-day=>"Wed",-start=>"9:30",-duration=>1.5);
    my $section = Section->new(-number=>1, -hours=>6);

    my $course = Course->new(-name=>"Basket Weaving", -course_id="420-ABC-DEF");
    $course->add_section($section);
    $section->add_block($block);
    
    print "Course consists of the following sections: ";
    foreach my $section ($course->sections) {
        # print info about $section
    }
    

=head1 DESCRIPTION

Describes a course

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

creates and returns a course object

B<Parameters>

-number => course number

-name => course name

B<Returns>

Course object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;
    confess "Bad inputs\n" if @_ % 2;
    my %inputs = @_;

    my $number = $inputs{-number} || "";
    my $name   = $inputs{-name}   || "";

    my $self = {};
    bless $self, $class;

    $self->{-id} = $Max_id++;
    $self->number($number);
    $self->name($name);
    return $self;
}

# =================================================================
# id
# =================================================================

=head2 id ()

Returns the unique id for this section object

=cut

sub id {
    my $self = shift;
    return $self->{-id};
}

# =================================================================
# name
# =================================================================

=head2 name ( [name] )

Course name

=cut

sub name {
    my $self = shift;
    $self->{-name} = shift if @_;
    return $self->{-name};
}

# =================================================================
# number
# =================================================================

=head2 number ( [course number] )

Gets and sets the course number

=cut

sub number {
    my $self = shift;
    $self->{-number} = shift if @_;
    return $self->{-number};
}

# =================================================================
# add_ section
# =================================================================

=head2 add_section ( section object )

Assign a section to this course

returns course object

=cut

sub add_section {
    my $self = shift;
    $self->{-sections} = $self->{-sections} || {};

    while ( my $section = shift ) {

        # ----------------------------------------------------------
        # has to be a Section object
        # ----------------------------------------------------------
        confess "<"
          . ref($section)
          . ">: invalid section - must be a Section object"
          unless ref($section) && $section->isa("Section");

        # ----------------------------------------------------------
        # Section number must be unique for this course
        # ----------------------------------------------------------
        my $duplicate = 0;
        foreach my $sec ( $self->sections ) {
            if ( $section->number eq $sec->number ) {
                $duplicate = 1;
                last;
            }
        }
        confess "<"
          . $section->number
          . ">: section number is not unique for this course"
          if $duplicate;

        # ----------------------------------------------------------
        # save section for this course, save course for this section
        # ----------------------------------------------------------
        $self->{-sections}{ $section->number } = $section;
        $section->course($self);
    }

    return $self;
}

# =================================================================
# get_section
# =================================================================

=head2 get_section ( section number )

gets section from this course that has section number

Returns Section object

=cut

sub get_section {
    my $self    = shift;
    my $number = shift;

    if (exists $self->{-sections}{ $number }) {
        return $self->{-sections}{$number}
    }

    return;
}

# =================================================================
# remove_section
# =================================================================

=head2 remove_section ( section object )

removes section from this course

Returns Course object

=cut

# ===================================
# Alex Code
# Assign teacher to Course
# ===================================

sub course_assign_teacher(){
	my $self = shift;
	my $teacher = shift;
	
	foreach my $sec ( $self->sections ){
		$sec->assign_teacher($teacher);
	}
}

sub remove_section {
    my $self    = shift;
    my $section = shift;

    confess "<" . ref($section) . ">: invalid section - must be a Section object"
      unless ref($section) && $section->isa("Section");

    delete $self->{-sections}{ $section->number }
      if exists $self->{-sections}{ $section->number };

    $section->delete();

    return $self;

}

# =================================================================
# delete
# =================================================================

=head2 delete

Deletes this object (and all its dependants) 

Returns undef

=cut

sub delete {
    my $self    = shift;
    
    foreach my $section ($self->sections) {
        $self->remove_section($section);    
    }
    undef $self;

    return;
}

# =================================================================
# sections
# =================================================================

=head2 sections ( )

returns an list of sections assigned to this course

=cut

sub sections {
    my $self = shift;
    
    if (wantarray) {
        return values %{ $self->{-sections} };
    }
    else {
        return [values %{ $self->{-sections} }];
    }
}

# =================================================================
# max_section_number
# =================================================================

=head2 max_section_number ( )

returns the maximum 'section number'

=cut

sub max_section_number {
    my $self = shift;
    my @sections = sort {$a->number <=> $b->number} $self->sections;
    return $sections[-1]->number if @sections;
    return 0;
}

# =================================================================
# blocks
# =================================================================

=head2 blocks ( )

returns an list of blocks assigned to this course

=cut

sub blocks {
    my $self = shift;
    my @blocks;
    foreach my $section ( $self->sections ) {
        push @blocks, $section->blocks;
    }
    
    if (wantarray) {
        return @blocks;
    }
    else {
        return \@blocks;
    }
}

# =================================================================
# section
# =================================================================

=head2 section (section number )

returns the section associated with this section number

=cut

sub section {
    my $self           = shift;
    my $section_number = shift;
    return $self->{-sections}->{$section_number};
}

# =================================================================
# print_description
# =================================================================

=head2 print_description

Returns a text string that describes the course, sections,
blocks, teachers, labs.

=cut

sub print_description {
    my $self = shift;
    my $text = "";

    # header
    $text .= "\n\n" . "=" x 50 . "\n";
    $text .= $self->number . " " . $self->name . "\n";
    $text .= "=" x 50 . "\n";

    # sections
    foreach my $s ( sort {$a->number <=> $b->number} $self->sections ) {
        $text .= "\nSection " . $s->number . "\n";
        $text .= "-" x 50 . "\n";

        # blocks
        foreach my $b ( sort{$a->day_number <=> $b->day_number || $a->start_number <=> $b->start_number }$s->blocks ) {
            $text .=
              $b->day . " " . $b->start . ", " . $b->duration . " hours\n";
            $text .=
              "\tlabs: " . join( ", ", map { "$_" } $b->labs ) . "\n";
            $text .= "\tteachers: ";
            $text .= join(", ",map {"$_"} $b->teachers);
            $text .= "\n";
        }
    }

    return $text;

}

sub teachers {
    my $self = shift;
    my %teachers;

	foreach my $section ($self->sections){
		foreach my $block ( $section->blocks ) {
        		foreach my $teacher ( $block->teachers ) {
            		$teachers{$teacher} = $teacher;
        		}
    		}	
	}

    if (wantarray) {
        return values %teachers;
    }
    else {
        return [ values %teachers ];
    }
}

=head2 more stuff about conflicts to come

# =================================================================
# footer
# =================================================================

1;

=cut

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

#!/usr/bin/perl
use strict;
use warnings;

package Course;

use FindBin;
use lib ("$FindBin::Bin/..");
use Carp;
use Schedule::Section;
use overload
  fallback => 1,
  '""'     => \&print_description;

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

	my $number   = $inputs{-number}   || "";
	my $name     = $inputs{-name}     || "";
	my $semester = $inputs{-semester} || "";

	my $self = {};
	bless $self, $class;

	$self->{-id} = ++$Max_id;
	$self->number($number);
	$self->name($name);
	$self->semester($semester);
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
# needs allocation
# =================================================================

=head2 needs_allocation ( [true | false] )

Does this course need to be allocated (i.e. have a teacher assigned)

For example, Math and Human Relations do not need to be 
allocated to one of our teachers

... defaults to true

=cut

sub needs_allocation {
	my $self = shift;
    $self->{-allocation} = shift if @_;
    $self->{-allocation} = 1 unless defined $self->{-allocation};
    return $self->{-allocation};
}

# =================================================================
# semester
# =================================================================

=head2 semester ( [semester] )

Course semester

=cut

sub semester {
	my $self = shift;
	if (@_) {
		my $semester = lc(shift);
		if ( $semester !~ /^(summer|winter|fall)/ ) {
			warn("invalid semester for course; ($semester) \n");
			my @caller = caller();
			print "Called from: ",join(", ",@caller),"\n";
			$semester = "";
		}
		$self->{-semester} = $semester;
	}
	return $self->{-semester};
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
	my $self   = shift;
	my $number = shift;

	if ( exists $self->{-sections}{$number} ) {
		return $self->{-sections}{$number};
	}

	return;
}

# =================================================================
# get_section_by_id
# =================================================================

=head2 get_section_by_id ( section id )

gets section from this course that has section id

Returns Section object

=cut

sub get_section_by_id {
	my $self = shift;
	my $id   = shift;

	my @sections = $self->sections;
	foreach my $i (@sections) {
		return $i if $i->id == $id;
	}

	return;
}

# =================================================================
# get_section_by_name
# =================================================================

=head2 get_section_by_name ( section name )

gets section from this course that has section name

Returns Section object

=cut

sub get_section_by_name {
	my $self = shift;
	my $name = shift;

	my @toReturn;
	if ($name) {
		my @sections = $self->sections;
		foreach my $i (@sections) {
			push( @toReturn, $i ) if $i->name eq $name;
		}
	}

	return @toReturn;
}

# =================================================================
# remove_section
# =================================================================

=head2 remove_section ( section object )

removes section from this course

Returns Course object

=cut

sub remove_section {
	my $self    = shift;
	my $section = shift;

	confess "<"
	  . ref($section)
	  . ">: invalid section - must be a Section object"
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
	my $self = shift;

	foreach my $section ( $self->sections ) {
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
		return [ values %{ $self->{-sections} } ];
	}
}

# =================================================================
# number of sections
# =================================================================

=head2 number of sections ( )

returns number sections assigned to this course

=cut

sub number_of_sections {
	my $self = shift;

	my @sections = $self->sections;
	return scalar(@sections);
}

# =================================================================
# sections
# =================================================================

=head2 sections_for_teacher ( teacher object )

returns an list of sections assigned to this course, with this teacher

=cut

sub sections_for_teacher {
	my $self = shift;
	my $teacher = shift;
	my @sections = ();

        foreach my $section ( $self->sections ) {
            foreach my $teacher_id ( $section->teachers ) {
                if ( $teacher->id eq $teacher_id->id ) {
                    push @sections, $section;
                }
            }
        }


	if (wantarray) {
		return @sections ;
	}
	else {
		return [ @sections ];
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
	my @sections = sort { $a->number <=> $b->number } $self->sections;
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
	foreach my $s ( sort { $a->number <=> $b->number } $self->sections ) {
		$text .= "\n$s\n";
		$text .= "-" x 50 . "\n";

		# blocks
		foreach my $b (
			sort {
				     $a->day_number <=> $b->day_number
				  || $a->start_number <=> $b->start_number
			} $s->blocks
		  )
		{
			$text .=
			  $b->day . " " . $b->start . ", " . $b->duration . " hours\n";
			$text .= "\tlabs: " . join( ", ", map { "$_" } $b->labs ) . "\n";
			$text .= "\tteachers: ";
			$text .= join( ", ", map { "$_" } $b->teachers );
			$text .= "\n";
		}
	}

	return $text;

}

# =================================================================
# print_description2
# =================================================================

=head2 print_description2

Number: Name

=cut

sub print_description2 {
	my $self = shift;

	return $self->number . ": " . $self->name;

}

# =================================================================
# teachers
# =================================================================

=head2 teachers ( )

returns an list of teachers assigned to all sections in this course

=cut

sub teachers {
	my $self = shift;
	my %teachers;

	foreach my $section ( $self->sections ) {
		foreach my $teacher ( $section->teachers ) {
			$teachers{$teacher} = $teacher;
		}
	}

	if (wantarray) {
		return values %teachers;
	}
	else {
		return [ values %teachers ];
	}
}

# =================================================================
# has teacher
# =================================================================

=head2 has_teacher ( $teacher )

returns true if teacher assigned to this course

=cut

sub has_teacher {
	my $self    = shift;
	my $teacher = shift;
	return unless $teacher;

	foreach my $t ( $self->teachers ) {
		return 1 if $t->id == $teacher->id;
	}
	return 0;
}

# =================================================================
# streams
# =================================================================

=head2 streams ( )

returns an list of streams assigned to all sections in this course

=cut

sub streams {
	my $self = shift;
	my %streams;

	foreach my $section ( $self->sections ) {
		foreach my $stream ( $section->streams ) {
			$streams{$stream} = $stream;
		}
	}

	if (wantarray) {
		return values %streams;
	}
	else {
		return [ values %streams ];
	}
}

# =================================================================
# has_stream
# =================================================================

=head2 has_stream (stream )

returns true if this course has stream

=cut

sub has_stream {
	my $self   = shift;
	my $stream = shift;
	return unless $stream;

	foreach my $s ( $self->streams ) {
		return 1 if $s->id == $stream->id;
	}

}

# =================================================================
# assign_teacher
# =================================================================

=head2 assign_teacher ( teacher object )

Assign a teacher to all sectionss in this course

Returns course object

=cut

sub assign_teacher {
	my $self = shift;

	if (@_) {
		my $teacher = shift;
		foreach my $section ( $self->sections ) {
			$section->assign_teacher($teacher);
		}
	}

	return $self;
}

# =================================================================
# assign_lab
# =================================================================

=head2 assign_lab ( lab object )

Assign a lab to all sectionss in this course

Returns course object

=cut

sub assign_lab {
	my $self = shift;

	if (@_) {
		my $lab = shift;
		foreach my $section ( $self->sections ) {
			$section->assign_lab($lab);
		}
	}

	return $self;
}

# =================================================================
# assign_stream
# =================================================================

=head2 assign_teacher ( teacher object )

Assign a steam to all sections in this course

Returns course object

=cut

sub assign_stream {
	my $self = shift;

	if (@_) {
		my $stream = shift;
		foreach my $section ( $self->sections ) {
			$section->assign_stream($stream);
		}
	}

	return $self;
}

# =================================================================
# remove_teacher
# =================================================================

=head2 remove_teacher ( teacher object )

removes teacher from all blocks in this course

Returns Course object

=cut

sub remove_teacher {
	my $self    = shift;
	my $teacher = shift;

	foreach my $section ( $self->sections ) {
		$section->remove_teacher($teacher);
	}

	return $self;

}

# =================================================================
# remove_all_teachers
# =================================================================

=head2 remove_all_teachers

removes all teachers from all blocks in this course

Returns Course object

=cut

sub remove_all_teachers {
	my $self = shift;
	foreach my $teacher ( $self->teachers ) {
		$self->remove_teacher($teacher);
	}

	return $self;

}

# =================================================================
# remove_stream
# =================================================================

=head2 remove_stream ( stream  )

removes stream from this course

Returns Course object

=cut

sub remove_stream {
	my $self   = shift;
	my $stream = shift;

	foreach my $section ( $self->sections ) {
		$section->remove_stream($stream);
	}

	return $self;

}

# =================================================================
# remove_all_streams
# =================================================================

=head2 remove_all_streams

removes all streams from all blocks in this course

Returns Course object

=cut

sub remove_all_streams {
	my $self = shift;
	foreach my $stream ( $self->streams ) {
		$self->remove_stream($stream);
	}

	return $self;

}

#=======================================
# Get unused section number (Alex Code)
#=======================================

=head2 get_new_number

returns the first unused section number

=cut

sub get_new_number {
	my $self   = shift;
	my $number = 1;
	while ( $self->get_section($number) ) {
		$number++;
	}
	return $number;
}

=head2 more stuff about conflicts to come


=cut

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

1;

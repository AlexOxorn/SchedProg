#!/usr/bin/perl
use strict;
use warnings;

package Section;

use FindBin;
use lib ("$FindBin::Bin/..");
use Schedule::Block;
use Carp;

use overload  
	fallback=> 1,
	'""' => \&print_description;

# CHANGE LOG ... changes made so that we can use this for allocation
# 1) Added property "num_students"
# 2) Can add a teacher directly to the section, even if this section
#    does not have any blocks (consider 'stage')


=head1 NAME

Section - describes a distinct course/section 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Course;
    use Schedule::Section;
    
    my $block = Block->new (-day=>"Wed",-start=>"9:30",-duration=>1.5);
    my $section = Section->new(-number=>1, -hours=>6);

    my $course = Course->new(-name=>"Basket Weaving");
    $course->add_section($section);
    $section->add_block($block);
    
    print "Section consists of the following blocks: ";
    foreach my $block ($section->blocks) {
        # print info about $block
    }
    
    $section->assign_teacher($teacher);
    $section->remove_teacher($teacher);
    $section->teachers();
    
    $section->add_lab("P327");
    $section->remove_lab("P325");
    $section->labs();
    

=head1 DESCRIPTION

Describes a section (part of a course)

=head1 METHODS

=cut

# =================================================================
# class variables
# =================================================================
our $Max_id = 0;

# =================================================================
# new
# =================================================================

=head2 new ()

creates and returns a section object

B<Parameters>

-number => section number

-hours => how many hours per week

B<Returns>

Section object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;
    confess "Bad inputs\n" if (@_ % 2 && @_ % 3);
    my %inputs = @_;

    my $number = $inputs{-number} || "";
    my $hours  = $inputs{-hours}  || 1.5;
    my $name   = $inputs{-name}   || "";

    my $self = {};
    bless $self, $class;
    $self->{-id} = ++$Max_id;
    $self->number($number);
    $self->hours($hours);
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
# hours
# =================================================================

=head2 hours ( [hours] )

How many hours per week is the section?

=cut

sub hours {
    my $self = shift;
    if (@_) {
        my $hours = shift;

        confess "<$hours>: hours must be a number and > 0"
          unless $hours =~ /^[0-9]/ && $hours > 0;

        $self->{-hours} = $hours;
    }
    
    # most often this number is not entered correctly, so
    # lets use the number of hours in the blocks,
    # assuming it has blocks
    my @bs = $self->blocks;
    
    if (@bs) {
        $self->{-hours} = 0;
        foreach my $b (@bs) {
            $self->{-hours} += $b->duration;
        }
    }
         
    return $self->{-hours};
}

# =================================================================
# add_hours
# =================================================================

=head2 add_hours ( [hours] )

Add x hours to the hours variable

=cut

sub add_hours {
    my $self = shift;
    if (@_) {
        my $hours = shift;

        confess "<$hours>: hours must be a number and > 0"
          unless $hours =~ /^[0-9]/ && $hours > 0;

        $self->{-hours} += $hours;
    }
    return $self->{-hours};
}

# =================================================================
# name
# =================================================================

=head2 name ( [name] )

Section name

=cut

sub name {
    my $self = shift;
    $self->{-name} = shift if @_;
    return $self->{-name};
}

# =================================================================
# title
# =================================================================

=head2 title (  )

Section title 

Returns name if defined, else "Section num" 

=cut

sub title {
    my $self = shift;
    my $title = $self->{-name} || "Section ".$self->number;
    return $title;
}

# =================================================================
# number
# =================================================================

=head2 number ( [section number] )

Gets and sets the course section number

=cut

sub number {
    my $self = shift;
    if (@_) {
        my $number = shift;

        confess "<$number>: section number cannot be a null string"
          if $number eq "";

        $self->{-number} = $number;
    }
    return $self->{-number};
}

# =================================================================
# course
# =================================================================

=head2 course ( [course] )

Gets and sets the course object which contains this section

=cut

sub course {
    my $self = shift;
    if (@_) {
        my $course = shift;
        confess "<"
          . ref($course)
          . ">: invalid course - must be a Course object"
          unless ref($course) && $course->isa("Course");

        $self->{-course} = $course;
    }
    return $self->{-course};
}

# =================================================================
# num_students
# =================================================================

=head2 num_students ( [number of students] )

Gets and sets the number of students for this section

=cut

sub num_students {
    my $self = shift;
    $self->{-num_students} = shift if @_;
    $self->{-num_students} = 30 unless $self->{-num_students};    
    return $self->{-num_students};
}

# =================================================================
# get_bloc_by_id
# =================================================================

=head2 get_block_by_id ( block id )

gets block from this section that has block id

Returns Block object

=cut

sub get_block_by_id {
    my $self    = shift;
    my $id 		= shift;

    my @blocks = $self->blocks;
    foreach my $i (@blocks){
    		return $i if $i->id == $id;
    }

    return;
}

# =================================================================
# get_block
# =================================================================

=head2 get_block ( block number )

gets block from this section that has block number

Returns Block object

=cut

sub get_block {
	
    my $self    = shift;
    my $number	= shift;

    my @blocks = $self->blocks;
    foreach my $i (@blocks){
    		$i->number(0) unless $i->number;
    		if ($i->number == $number) { return $i}  
    }
	
    return;
}


# =================================================================
# assign_lab
# =================================================================

=head2 assign_lab ( lab # )

Assign a lab to all blocks in this section

Returns section object

=cut

sub assign_lab {
    my $self = shift;

    if (@_) {
        my $lab = shift;
        foreach my $block ( $self->blocks ) {
            $block->assign_lab($lab);
        }
    }

    return $self;
}

# =================================================================
# remove_lab
# =================================================================

=head2 remove_lab ( lab # )

removes lab from all blocks in this section

Returns Section object

=cut

sub remove_lab {
    my $self = shift;
    my $lab  = shift;

    foreach my $block ( $self->blocks ) {
        $block->remove_lab($lab);
    }

    return $self;

}

# =================================================================
# labs
# =================================================================

=head2 labs ( )

returns an list of labs assigned to all blocks in this section

=cut

sub labs {
    my $self = shift;
    my %labs;

    foreach my $block ( $self->blocks ) {
        foreach my $lab ( $block->labs ) {
            $labs{ $lab->id } = $lab;
        }
    }

    if (wantarray) {
        return values %labs;
    }
    else {
        my @array = values %labs;
        return \@array;
    }
}

# =================================================================
# assign_teacher
# =================================================================

=head2 assign_teacher ( teacher object )

Assign a teacher to all blocks in this section

Update: even if the section does not have blocks, we still need
to assign a teacher (example... stage is not scheduled, but
we still need to assign a teacher for allocation purposes)

Returns section object

=cut

sub assign_teacher {
    my $self = shift;
    $self->{-teachers} = {} unless $self->{-teachers};

    if (@_) {
        my $teacher = shift;
        foreach my $block ( $self->blocks ) {
            $block->assign_teacher($teacher);
        }
        $self->{-teachers}->{$teacher->id} = $teacher;
        $self->{-allocation}->{$teacher->id} = $self->hours;
    }

    return $self;
}

# =================================================================
# set teacher_allocation 
# =================================================================

=head2 set_teacher_allocation ( teacher object, hours )

Assign number of hours to teacher for this section

Returns section object

=cut

sub set_teacher_allocation {
    my $self = shift;
    my $teacher = shift;
    my $hours = shift;
    
    # add allocation
    if ($hours) {
        if (!$self->has_teacher($teacher)) {
            $self->assign_teacher($teacher);
        }
        $self->{-allocation}{$teacher->id} = $hours;
    }
    
    # if no hours, remove teacher from section
    else {
        $self->remove_teacher($teacher);
    }

    return $self;
}

# =================================================================
# get teacher_allocation 
# =================================================================

=head2 get_teacher_allocation ( teacher object)

Returns number of hours assigned to this teacher for this section

=cut

sub get_teacher_allocation {
    my $self = shift;
    my $teacher = shift;
    
    # teacher is not teaching this section
    return 0 unless $self->has_teacher($teacher);
        
    # allocation has been defined
    if (exists $self->{-allocation}{$teacher->id}) {
        return  $self->{-allocation}{$teacher->id} ;
    }
    
    # hours have not been defined, assume total number of section hours
    else {
        return $self->hours;
    }
}

# =================================================================
# allocated_hours
# =================================================================

=head2 allocated_hours

Returns number of hours that have been allocated to teacheres

=cut

sub allocated_hours {
    my $self = shift;
    my $hours = 0;
    
    foreach my $teacher ($self->teachers) {
        $hours += $self->get_teacher_allocation ($teacher);
    }
    return $hours;
        
    my $teacher = shift;
}



# =================================================================
# remove_teacher
# =================================================================

=head2 remove_teacher ( teacher object )

removes teacher from all blocks in this section

Returns Section object

=cut

sub remove_teacher {
    my $self    = shift;
    my $teacher = shift;

    foreach my $block ( $self->blocks ) {
        $block->remove_teacher($teacher);
    }
    
    $self->{-teachers} = {} unless $self->{-teachers};
    if ( exists $self->{-teachers}{ $teacher->id } ) {
        delete $self->{-teachers}{ $teacher->id };
    }
    if (exists $self->{-allocation}{ $teacher->id }) {
        delete $self->{-allocation}{$teacher->id};
    }
    
    return $self;

}

# =================================================================
# remove_all_teachers
# =================================================================

=head2 remove_all_teachers ( )

removes all teacher from all blocks in this section

Returns Section object

=cut

sub remove_all_teachers {
    my $self    = shift;
    foreach my $teacher ($self->teachers) {
        $self->remove_teacher($teacher);
    }

    return $self;

}

# =================================================================
# teachers
# =================================================================

=head2 teachers ( )

returns an list of teachers assigned to all blocks in this section

=cut

sub teachers {
    my $self = shift;
    my %teachers;

    foreach my $block ( $self->blocks ) {
        foreach my $teacher ( $block->teachers ) {
            $teachers{$teacher} = $teacher;
        }
    }
    
    foreach my $teacher (values %{$self->{-teachers}}) {
        $teachers{$teacher} = $teacher;
    }

    if (wantarray) {
        return values %teachers;
    }
    else {
        return [ values %teachers ];
    }
}

# =================================================================
# has_teacher
# =================================================================

=head2 has_teacher ( teacher )

returns true if section has teacher

=cut

sub has_teacher {
    my $self = shift;
    my $teacher = shift;
    return unless $teacher;
    
    foreach my $t ($self->teachers) {
        return 1 if $t->id == $teacher->id;
    }
    return;
}

# =================================================================
# assign_stream
# =================================================================

=head2 assign_stream ( stream # )

Assign a stream to this section

Returns a Section object

=cut

sub assign_stream {
    my $self = shift;

    $self->{-streams} = $self->{-streams} || {};

    while ( my $stream = shift ) {
        confess "<"
          . ref($stream)
          . ">: invalid stream - must be a Stream object"
          unless ref($stream) && $stream->isa("Stream");

        $self->{-streams}{ $stream->id } = $stream;
    }

    return $self;
}

# =================================================================
# remove_stream
# =================================================================

=head2 remove_stream ( stream # )

removes stream from this section

Returns Section object

=cut

sub remove_stream {
    my $self   = shift;
    my $stream = shift;

    $self->{-streams} = $self->{-streams} || {};

    confess "<" . ref($stream) . ">: invalid stream - must be a Stream object"
      unless ref($stream) && $stream->isa("Stream");

    if ( exists $self->{-streams}{ $stream->id } ) {
        delete $self->{-streams}{ $stream->id };
    }

    return $self;

}

# =================================================================
# streams
# =================================================================

=head2 streams ( )

returns an list of streams assigned to this section

=cut

sub streams {
    my $self = shift;

    if (wantarray) {
        return values %{$self->{-streams}};
    }
    else {
        return [ values %{$self->{-streams}} ];
    }
}

# =================================================================
# has_stream
# =================================================================

=head2 has_stream ( stream )

returns true if this section has specified stream

=cut

sub has_stream {
    my $self = shift;
    my $stream = shift;
    return unless $stream;
    
    foreach my $s ($self->streams) {
        return 1 if $s->id == $stream->id;
    }
    return;
}

# =================================================================
# remove_all_streams
# =================================================================

=head2 remove_all_streams ( )

removes all streams from this section

Returns Section object

=cut

sub remove_all_streams {
    my $self    = shift;
    foreach my $stream ($self->streams) {
        $self->remove_stream($stream);
    }

    return $self;

}


# =================================================================
# add_block
# =================================================================

=head2 add_block ( block object )

Assign a block to this section

returns Section object

=cut

sub add_block {
    my $self = shift;
    $self->{-blocks} = $self->{-blocks} || {};

    while ( my $block = shift ) {
        confess "<" . ref($block) . ">: invalid block - must be a Block object"
          unless ref($block) && $block->isa("Block");

        $self->{-blocks}{ $block->id } = $block;
        $block->section($self);
    }

    return $self;
}

# =================================================================
# remove_block
# =================================================================

=head2 remove_block ( block object )

removes block from this section

Returns Section object

=cut

sub remove_block {
    my $self  = shift;
    my $block = shift;

    confess "<" . ref($block) . ">: invalid block - must be a Block object"
      unless ref($block) && $block->isa("Block");

    delete $self->{-blocks}{ $block->id }
      if exists $self->{-blocks}{ $block->id };

    $block->delete();

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

    foreach my $block ( $self->blocks ) {
        $self->remove_block($block);
    }
    undef $self;

    return;
}

# =================================================================
# blocks
# =================================================================

=head2 blocks ( )

returns an list of blocks assigned to this section

=cut

sub blocks {
    my $self = shift;
    if (wantarray) {
        return values %{ $self->{-blocks} };
    }
    else {
        return [ values %{ $self->{-blocks} } ];
    }
}

=head2 block ( block_id )

returns block corresponding to block_id

=cut

sub block {
    my $self     = shift;
    my $block_id = shift;
    return $self->{-blocks}->{$block_id};
}

# ================================================================
# print description
# ================================================================

sub print_description{
	
	
	my $self = shift;
	$self->name("") unless $self->name;
	#foreach my $i ($self->blocks){
	#	unless($i->number){
	#		$i->number($self->get_new_number)	
	#	}
	#}
	
	if($self->name ne "" && $self->name !~ /^Section\s*\d*$/){
		return "Section " . $self->number . ": " . $self->name;
	}else{
		return "Section " . $self->number;
	}
}

# =================================================================
# is_conflicted
# =================================================================

=head2 is_conflicted ( )

returns true if there is a conflict with this block, false otherwise

=cut

sub is_conflicted {
    my $self       = shift;
    my $conflicted = 0;
    foreach my $block ( $self->blocks ) {
        $conflicted += $block->is_conflicted;
    }
    return $conflicted;
}

=head2 conflicts ( )

returns a list of conflicts related to this block

=cut

# =================================================================
# conflicts
# =================================================================

sub conflicts {
    my $self = shift;
    my @conflicts;
    foreach my $block ( $self->blocks ) {
        push @conflicts, $block->conflicts;
    }
    return @conflicts;
}

=head2 more stuff about conflicts to come

=cut

#=======================================
# Get unused block number (Alex Code)
#=======================================

=head2 get_new_number

returns the first unused block number

=cut

sub get_new_number{
	my $self = shift;
	my $number = 1;
	while($self->get_block($number)){
		$number++;
	}
	return $number;
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

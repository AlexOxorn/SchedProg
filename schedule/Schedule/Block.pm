#!/usr/bin/perl
use strict;
use warnings;

package Block;
use FindBin;
use Carp;
use lib "$FindBin::Bin/..";
use Schedule::Time_slot;
use Schedule::Conflict;

our @ISA = qw(Time_slot);
use overload 
	fallback=> 1,
	'""' => \&print_description;

=head1 NAME

Block - describes a distinct contiguous course/section/class 

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Schedule::Course;
    use Schedule::Section;
    use Schedule::Block;
    
    my $block = Block->new (-day=>"Wed",-start=>"9:30",-duration=>1.5);

    my $course = Course->new(-name=>"Basket Weaving");
    my $section = $course->create_section(-section_number=>1);
    $section->add_block($block);
    
    print "block belongs to section ",$block->section;
    
    $block->assign_teacher($teacher);
    $block->remove_teacher($teacher);
    $block->teachers();
    
    $block->add_lab("P327");
    $block->remove_lab("P325");
    $block->labs();
    

=head1 DESCRIPTION

Base Clase:: C<Time_slot>

Describes a block which is a specific time slot for teaching
part of a section of a course.

=head1 METHODS

=cut

# =================================================================
# Class Variables
# =================================================================
our $Max_id = 0;
our $Default_day = 'mon';

# =================================================================
# new
# =================================================================

=head2 new ()

creates and returns a block object

B<Parameters>

-day => 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'

-start => start time using 24 h clock (i.e 1pm is "13:00")

-duration => how long does this class last, in hours

B<Returns>

Block object

=cut

# -------------------------------------------------------------------
# new
#--------------------------------------------------------------------
sub new {
    my $class = shift;

    # create the object
    my @time_slot_arg;
    my %inputs = @_;
    
    my $day      = $inputs{-day};
    my $start    = $inputs{-start};
    my $duration = $inputs{-duration};
    my $number	 = $inputs{-number};
    
    my $self = $class->SUPER::new(-day=>$day,-start=>$start,-duration=>$duration);
    
    
    $self->number($number);
	$self->{-id} = ++$Max_id;
	
    return $self;
}

# =================================================================
# number
# =================================================================

=head2 number ( [block number] )

Gets and sets the block number

=cut

sub number {
	
    my $self = shift;
    if (@_) {
        my $number = shift;

        confess "<$number>: section number cannot be a null string"
          if $number eq "";
		
		
        $self->{-number} = $number;
    }
    
    $self->{-number} = 0 unless $self->{-number};
    
    return $self->{-number};
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
    
    undef $self;

    return;
}

# =================================================================
# start
# =================================================================

=head2 start ( [time] )

Get/set start time of block, in 24hr clock

=cut

sub start {
    my $self = shift;

    if (@_) {
        my $start = shift;
        $self->SUPER::start($start);

        # if there are synced blocks, change them too
        # (NB: have to careful about infinite loop!)
        foreach my $other ( $self->synced() ) {
            my $old = $other->SUPER::start;
            if ( $old ne $self->SUPER::start ) {
                $other->start( $self->SUPER::start );
            }
        }
    }

    return $self->SUPER::start;
}

# =================================================================
# day
# =================================================================

=head2 start ( [time] )

Get/set start time of block, in 24hr clock

=cut

sub day {
    my $self = shift;

    if (@_) {
        my $day = shift;
        $self->SUPER::day($day);

        # if there are synced blocks, change them too
        # (NB: have to careful about infinite loop!)
        foreach my $other ( $self->synced() ) {
            my $old = $other->SUPER::day;
            if ( $old ne $self->SUPER::day ) {
                $other->day( $self->SUPER::day );
            }
        }
    }

    return $self->SUPER::day;
}

#==================================================================
# id //ALEX CODE
#==================================================================

=head2 id

Gets and returns the block id

=cut

sub id{
    my $self = shift;
    return $self->{-id};
}

# =================================================================
# section
# =================================================================

=head2 section ( [section id] )

Gets and sets the course section object which contains this block

=cut

sub section {
    my $self = shift;
    if (@_) {
        my $section = shift;

        confess "<"
          . ref($section)
          . ">: invalid section - must be a Section object"
          unless ref($section) && $section->isa("Section");

        $self->{-section} = $section;
    }
    return $self->{-section};
}

# =================================================================
# assign_lab
# =================================================================

=head2 assign_lab ( lab # )

Assign a lab to this block

=cut

sub assign_lab {
    my $self = shift;

    $self->{-labs} = $self->{-labs} || {};

    while ( my $lab = shift ) {
        confess "<" . ref($lab) . ">: invalid lab - must be a Lab object"
          unless ref($lab) && $lab->isa("Lab");

        $self->{-labs}{ $lab->id } = $lab;
    }

    return $self;
}

# =================================================================
# remove_lab
# =================================================================

=head2 remove_lab ( lab # )

removes lab from this block

Returns Block object

=cut

sub remove_lab {
    my $self = shift;
    my $lab  = shift;

    $self->{-labs} = $self->{-labs} || {};

    confess "<" . ref($lab) . ">: invalid lab - must be a Lab object"
      unless ref($lab) && $lab->isa("Lab");

    if ( exists $self->{-labs}{ $lab->id } ) {
        delete $self->{-labs}{ $lab->id };
    }

    return $self;

}

# =================================================================
# remove_all_labs
# =================================================================

=head2 remove_all_labs ( )

removes all labs from this block

Returns Block object

=cut

sub remove_all_labs {
    my $self = shift;
    foreach my $lab ($self->labs) {
        $self->remove_lab($lab);
    }
    return $self;

}

# =================================================================
# labs
# =================================================================

=head2 labs ( )

returns an list of labs assigned to this block

=cut

sub labs {
    my $self = shift;
    $self->{-labs} = {} unless $self->{-labs};

    if (wantarray) {
        return values %{ $self->{-labs} };
    }
    else {
        return [ values %{ $self->{-labs} } ];
    }
}

# =================================================================
# has_lab
# =================================================================

=head2 has_lab ( lab )

returns true if block has lab

=cut

sub has_lab  {
    my $self = shift;
    my $lab = shift;
    return unless $lab;
    
    foreach my $l ($self->labs) {
        return 1 if $l->id == $lab->id;
    }    
}

# =================================================================
# assign_teacher
# =================================================================

=head2 assign_teacher ( teacher object )

assigns a new teacher to this block

Returns Block object

=cut

sub assign_teacher {
    my $self = shift;
    $self->{-teachers} = $self->{-teachers} || {};

    while ( my $teacher = shift ) {
        confess "<"
          . ref($teacher)
          . ">: invalid teacher - must be a Teacher object"
          unless ref($teacher) && $teacher->isa("Teacher");
        $self->{-teachers}{ $teacher->id } = $teacher;
    }

    return $self;
}

# =================================================================
# remove_teacher
# =================================================================

=head2 remove_teacher ( teacher object )

removes teacher from this block

Returns Block object

=cut

sub remove_teacher {
    my $self    = shift;
    my $teacher = shift;

    confess "<"
      . ref($teacher)
      . ">: invalid teacher - must be a Teacher object"
      unless ref($teacher) && $teacher->isa("Teacher");

    if ( exists $self->{-teachers}{ $teacher->id } ) {
        delete $self->{-teachers}{ $teacher->id };
    }

    return $self;

}

# =================================================================
# remove_all_teachers
# =================================================================

=head2 remove_all_teachers (  )

removes all teachers from this block

Returns Block object

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

returns a list of teachers assigned to this block

=cut

sub teachers {
    my $self = shift;

    if (wantarray) {
        return values %{ $self->{-teachers} };
    }
    else {
        return [ values %{ $self->{-teachers} } ];
    }

}

# =================================================================
# has_teacher
# =================================================================

=head2 has_teacher ( teacher )

returns true if block has teacher

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
# teachersObj
# =================================================================

=head2 teachersObj ( )

returns a list of teacher objects to this block

=cut

sub teachersObj {
    my $self = shift;
    return $self->{-teachers};
}

# =================================================================
# sync_block
# =================================================================

=head2 sync_block ( block object )

the new block object will be synced with this one 
(i.e. change the start time of this block, 
and the synced block will also be changed) 

Returns Block object

=cut

sub sync_block {
    my $self  = shift;
    my $block = shift;

    confess "<" . ref($block) . ">: invalid block - must be a Block object"
      unless ref($block) && $block->isa("Block");

    $self->{-sync} = $self->{-sync} || [];
    push @{ $self->{-sync} }, $block;

    return $self;

}

# =================================================================
# unsync_block
# =================================================================

=head2 unsync_block ( block object )

removes syncing of block from this block

Returns Block object

=cut

sub unsync_block {
    my $self  = shift;
    my $block = shift;

    # ... some code

    return $self;

}

# =================================================================
# synced
# =================================================================

=head2 synced ( )

returns an array ref of blocks which are synced to this block

=cut

sub synced {
    my $self = shift;
    $self->{-sync} = $self->{-sync} || [];
    if (wantarray) {
        return @{ $self->{-sync} };
    }
    else {
        return $self->{-sync};
    }
}

# =================================================================
# reset_conflicted
# =================================================================

=head2 reset_conflicted ( )

Resets conflicted field

=cut

sub reset_conflicted {
    my $self = shift;
    $self->{-conflicted} = 0;
}

# =================================================================
# conflicted
# =================================================================

=head2 conflicted ( [boolean] )

Gets and sets conflicted field

=cut

sub conflicted {
    my $self = shift;
    my $new = shift || 0;
    $self->{-conflicted} = $self->{-conflicted} || 0;
    $self->{-conflicted} = $self->{-conflicted} | $new;
    return $self->{-conflicted};
}

# =================================================================
# is_conflicted
# =================================================================

=head2 is_conflicted ( )

returns true if there is a conflict with this block, false otherwise

=cut

sub is_conflicted {
    my $self = shift;
    return $self->{-conflicted};
}


# =================================================================
# print_description
# =================================================================

=head2 print_description

Returns a text string that describes the block

=cut

sub print_description {
	
    my $self = shift;
    my $text = "";
    my $i;
	
	$self->refresh_number;

    if ( $self->section ) {
        if ( $self->section->course ) {
            $text .= $self->section->course->name . " ";
        }
        $text .= $self->section->number . " ";
    }
    $text .=
        $self->day . " "
      . $self->start . " for "
      . $self->duration
      . " hours, in "
      . join( ", ", map { "$_" } $self->labs );

	
    return $text;

}


#=================
#Alex COde
#Date: Time Hours
#=================
sub print_description2 {
	
    my $self = shift;
    my $text = "";
    my $i;
    
    $self->refresh_number;

    $text .=
    		$self->number . " : "
      . $self->day . ", "
      . $self->start . "  "
      . $self->duration . " hour(s)";

    return $text;

}

# =================================================================
# conflicts
# =================================================================

=head2 conflicts ( )

returns a list of conflicts related to this block

=cut

sub conflicts {
    my $self = shift;
    $self->{-conflicts} = [] unless $self->{-conflicts};

    if (wantarray) {
        return @{ $self->{-conflicts} };
    }
    else {
        return $self->{-conflicts};
    }
}
=head2 more stuff about conflicts to come

=cut

#===================================
# Refresh Number
#===================================

=head2 refresh_number ( )

Assigns a number to a block that doesn't have one

=cut

sub refresh_number{
	my $self = shift;
	my $number = $self->number;
	my $section = $self->section;
	
	if($number == 0){
		$self->number($section->get_new_number);
	}
	
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

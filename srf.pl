#!/usr/bin/perl


#    SRF is a fractal drawing program created by David Buckingham
#    Copyright (C) 2013 David Buckingham
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


use strict;
use warnings;
use GD::Image;


# -----------------------------------------------------------------
# |                 Sash Rocks Fractals v1.2                      |
# |                           by db                               |
# -----------------------------------------------------------------

use constant DEG_2_RAD => 3.141592653589793 / 180;


# -----------------------------------------------------------------
# |               PARSE USER PARAMS AND CONFIG FILE               |
# -----------------------------------------------------------------

# VARIABLES
my @lineColor = (30, 80, 200);
my @bgColor = (0, 0, 0);
my $lineWidth = 1;
my $width = 1024;
my $height = 768;
my $angle = 90;
my $maxDepth = 0;
my $expansion = 'F+F+F+F';
my %rules;
my $inFile = 'koch_island.fractal';
my $outFile = 'fractal_image.png';

if (@ARGV) {
    $inFile = $ARGV[0];
}

open (FILEHANDLE, '<', $inFile) || die "can't find/open file: \"$inFile\"\n";
while (<FILEHANDLE>) {
    next if /^#/;
    next if /^\s*$/;

    my $line = $_;
    chomp($line);
    my ($name, $val) = split(' ', $line);
    $name = lc($name);

    if ($name eq 'angle' and $val =~ m/^[0-9]+$/) {
	$angle = $val;
    }
    elsif ($name eq 'depth' and $val =~ m/^[0-9]+$/) {
	$maxDepth = $val;
    }
    elsif ($name eq 'axiom') {
	$expansion = $val;
    }
    elsif ($name eq 'rule' and $val =~ m/[a-zA-Z]=.*/) {
	my ($lhs, $rhs) = split("=", $val);
	$rules{$lhs} = $rhs;
    }
    elsif ($name eq 'filename' and $val) {
        $outFile = $val;
    }
    elsif ($name eq 'width' and $val =~ m/^[0-9]+$/) {
	$width = $val;
    }
    elsif ($name eq 'height' and $val =~ m/^[0-9]+$/) {
	$height = $val;
    }
    elsif ($name eq 'linewidth' and $val =~ m/^[0-9]+$/) {
	$lineWidth = $val;
    }
    elsif ($name eq 'bgcolor' and $val =~ m/^[0-9]+,[0-9]+,[0-9]+$/) {
	@bgColor = split(',', $val);
    }
    elsif ($name eq 'linecolor' and $val =~ m/^[0-9]+,[0-9]+,[0-9]+$/) {
	@lineColor = split(',', $val);
    }
    else {
	warn "Warning: invalid paramater '${line}'\n";
    }
}
close (FILEHANDLE); 


# -----------------------------------------------------------------
# |                 EXPAND AXIOM INTO FULL EXPRESSION             |
# -----------------------------------------------------------------

while ($maxDepth-- > 0) {
    my $search = join('|', keys(%rules));
    if ($search) {
	$expansion =~ s/($search)/$rules{$1}/g;
    }
}


# -----------------------------------------------------------------
# |              PARSE EXPRESSION, MAKE FRACTAL LINES             |
# -----------------------------------------------------------------

# VARIABLES
my @lines;
my @count = $expansion =~ /F/g;
$#lines = @count - 1;
my ($minX, $maxX, $minY, $maxY) = (0, 0, 0, 0);
my $index = 0;
my $multiplier = 0;
my %turtle = ('x' => 0, 'y' => 0, 'd' => 0);
my @stack;

# SUBROUTINE: MOVE THE TURTLE
sub move {
    $turtle{x} += sin($turtle{d} * DEG_2_RAD);
    $turtle{y} -= cos($turtle{d} * DEG_2_RAD);
    ($turtle{x} < $minX and $minX = $turtle{x}) or ($turtle{x} > $maxX and $maxX = $turtle{x});
    ($turtle{y} < $minY and $minY = $turtle{y}) or ($turtle{y} > $maxY and $maxY = $turtle{y});
}

# TURTLE GRAPHICS: READ EXPANDED EXPRESSION AND SAVE LINES TO DRAW
foreach my $op (split("", $expansion)) {
    if ($op eq 'G') {
	move();
    }
    elsif ($op eq 'F') {
	my %old = %turtle;
	move();
	$lines[$index++] = [$old{x}, $old{y}, $turtle{x}, $turtle{y}];
    }
    elsif ($op eq '+' || $op eq '-') {
	$turtle{d} += "${op}$angle" * ($multiplier ? $multiplier : 1);
    }
    elsif ($op eq '[') {
	my %new = %turtle;
	push (@stack, \%new);
    }
    elsif ($op eq ']') {
	%turtle = %{pop(@stack)};
    }
    elsif ($op =~ m/\d/) {
	$multiplier = ($multiplier * 10) + $op;
    }

    if ($op !~ m/\d/) {
	$multiplier = 0;
    }
}

# SCALE AND TRANSLATE LINES TO FIT CANVAS
my $rangeX = $maxX - $minX;
my $rangeY = $maxY - $minY;
#my $scale = $rangeX * $width < $rangeY * $height ? ($width * 0.9) / $rangeX : ($height * 0.9) / $rangeY;
my $scale;
if ($rangeX / $width > $rangeY / $height) {
    $scale = $rangeX ? ($width * 0.9) / $rangeX : 1;
}
else {
    $scale = $rangeY ? ($height * 0.9) / $rangeY : 1;
}
my $shiftX = ($width - (($maxX + $minX) * $scale)) / 2;
my $shiftY = ($height - (($maxY + $minY) * $scale)) / 2;
for (@lines) {for (@$_) {$_ *= $scale}};
for (@lines) {$$_[0] += $shiftX; $$_[1] += $shiftY; $$_[2] += $shiftX; $$_[3] += $shiftY};


# -----------------------------------------------------------------
# |                        DRAW THE IMAGE                         |
# -----------------------------------------------------------------

# VARIABLES
my $im = new GD::Image($width, $height);
$im->interlaced('false');
my $imLineColor =  $im->colorAllocate(@lineColor);
my $imBackColor =  $im->colorAllocate(@bgColor);       

# DRAW BACKGROUND AND LINES ONTO CANVAS
$im->fill(0, 0, $imBackColor);
$im->setThickness($lineWidth);
foreach my $line (@lines) {
    GD::Image::line($im, $$line[0], $$line[1], $$line[2], $$line[3], $imLineColor);
}

# CONVERT IMAGE TO PNG AND PRINT TO FILE
open (FILEHANDLE, '>' . $outFile) || die "failed to create/open file: \"$outFile\"\n";
binmode FILEHANDLE; #for windows
print FILEHANDLE $im->png;
close (FILEHANDLE); 

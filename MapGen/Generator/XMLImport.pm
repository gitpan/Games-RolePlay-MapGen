# vi:tw=0 syntax=perl:

package Games::RolePlay::MapGen::Generator::XMLImport;

use strict;
use Carp;
use base qw(Games::RolePlay::MapGen::Generator);
use Games::RolePlay::MapGen::Tools qw( _group _tile _door );
use XML::XPath;

1;

sub genmap {
    my $this = shift;
    my $opts = shift;

    croak "you must supply a filename with xml_input_file => \"something.xml\"" unless exists $opts->{xml_input_file};
    open my $input, $opts->{xml_input_file} or croak "unable to open $opts->{xml_input_file}: $!";
    my $xp = XML::XPath->new( ioref => $input );

    my $Mo = $xp->find('/MapGen/option');
    for my $op ($Mo->get_nodelist) {
        my $name = $xp->findvalue( '@name'  => $op )->value;
        my $val  = $xp->findvalue( '@value' => $op )->value;


        if( $val =~ m/:.*;/ ) {
            my $h = {};

            $h->{$1} = $2 while $val =~ m/([\w\d]+):\s*([\.\w\d]+);/g;
            $val = $h;

        } else {
            $val = "$val";
        }

        $opts->{$name} = $val;
    }

    my @dirs = (qw(n s e w));

    my $map    = [];
    my $groups = [];

    my $maprows = $xp->find('/MapGen/map/row');
    for my $row ($maprows->get_nodelist) {
        my $a = []; push @$map, $a;
        my $y_pos = $xp->findvalue( '@ypos' => $row )->value;

        my $mapcols = $xp->find( tile => $row);
        for my $tile ($mapcols->get_nodelist) {
            my $x_pos = $xp->findvalue( '@xpos' => $tile )->value;
            my $type  = $xp->findvalue( '@type' => $tile )->value;

            my $t = &_tile( x=>$x_pos, y=>$y_pos );

            if( $type eq "wall" ) {
                # type is undef for wall tiles
                $t->{od} = { map {($_=>0)} @dirs };

            } else {
                $t->{type} = $type;
                $t->{od} = { map {($_=>1)} @dirs };
            }

            push @$a, $t;

            my $mapclose = $xp->find( closure => $tile );
            for my $closure ($mapclose->get_nodelist) {
                my $type = $xp->findvalue( '@type' => $closure )->value;
                my $dir  = $xp->findvalue( '@dir'  => $closure )->value;
                   $dir =~ s/^(\w)\w+/$1/;

                if( $type eq "wall" ) {
                    $t->{od}{$dir} = 0;

                } elsif( $type eq "door" ) {
                    if( $dir eq "n" or $dir eq "w" ) {
                        my $o_x      = $x_pos - ($dir eq "w" ? 1:0);
                        my $o_y      = $y_pos - ($dir eq "n" ? 1:0);
                        my $opposite = $map->[$o_y][$o_x];
                        my $opp      = $Games::RolePlay::MapGen::opp{$dir};

                        # <closure dir="east" type="door" locked="no"
                        #   stuck="no" secret="yes" major_open_dir="east"
                        #   minor_open_dir="south" />

                        my $d_locked = ($xp->findvalue( '@locked' => $closure ) eq "yes" ? 1:0);
                        my $d_stuck  = ($xp->findvalue( '@stuck'  => $closure ) eq "yes" ? 1:0);
                        my $d_secret = ($xp->findvalue( '@secret' => $closure ) eq "yes" ? 1:0);
                        my $d_majod  = substr $xp->findvalue( '@major_open_dir' => $closure ), 0, 1;
                        my $d_minod  = substr $xp->findvalue( '@minor_open_dir' => $closure ), 0, 1;

                        $opposite->{od}{$opp} = $t->{od}{$dir} = &_door(
                            locked => $d_locked,
                            stuck  => $d_stuck,
                            secret => $d_secret,
                            open_dir => {
                                major => $d_majod,
                                minor => $d_minod,
                            },
                        );
                    }

                } else {
                    die "hrm: closure type=$type";
                }
            }
        }
    }

    my $tilegroups = $xp->find('/MapGen/tile_group');
    for my $tile_group ($tilegroups->get_nodelist) {
        my $t_name = $xp->findvalue( '@name' => $tile_group )->value;
        my $t_type = $xp->findvalue( '@type' => $tile_group )->value;

        my @t_loc  = split /,/, $xp->findvalue( '@loc' => $tile_group );
        my @t_size = split /x/, $xp->findvalue( '@size' => $tile_group );

        my $group = &_group;
           $group->{name}     = $t_name;
           $group->{loc_size} = "$t_size[0]x$t_size[1] ($t_loc[0], $t_loc[1])";
           $group->{type}     = $t_type;
           $group->{size}     = \@t_size;
           $group->{loc}      = \@t_loc;

        my $xmin = $t_loc[0];
        my $ymin = $t_loc[1];
        my $xmax = $xmin + $t_size[0]-1;
        my $ymax = $ymin + $t_size[1]-1;

        for my $x ( $xmin .. $xmax ) {
        for my $y ( $ymin .. $ymax ) {
            my $tile = $map->[$y][$x];
               $tile->{group} = $group;
        }}

        push @$groups, $group;
    }

    $map = new Games::RolePlay::MapGen::_interconnected_map( $map );

    close $input;

    return ($map, $groups);
}

__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Games::RolePlay::MapGen::Generator::XMLImport - Slurp up XML map data into MapGen memory form

=head1 SYNOPSIS

    use Games::RolePlay::MapGen;

    my $map = new Games::RolePlay::MapGen;
    
    $map->set_generator( "XMLImport" );
    $map->generate( xml_input_file => "map.xml" );

    generate $map;

=head1 SEE ALSO

Games::RolePlay::MapGen

=cut
